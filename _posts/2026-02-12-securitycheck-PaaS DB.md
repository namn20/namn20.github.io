---
title: "Azure PaaS DB 취약점 진단: Redis, PostgreSQL, MySQL 200대 스크립트 기반 체크리스트"
date: 2026-02-12 09:00:00 +0900
categories: [Security, Cloud]
tags: [azure, paas, redis, postgresql, mysql, vulnerability-assessment, isms, iso27001]
---

보안팀에서 **ISMS / ISO 27001 인증 심사**를 준비하며 기술영역 취약점 진단을 수행해야 하는 상황입니다. 대상은 Azure PaaS 형태의 DBMS **200대**(Redis, PostgreSQL, MySQL)이며, 기존 On-Premise 서버 진단과는 완전히 다른 접근이 필요합니다.

> "PaaS DB는 OS에 접근할 수 없는데, 어떻게 취약점 진단을 하죠?"

이 글에서는 **PaaS DB 환경에 특화된 진단 방안, 스크립트 기반 자동화 체크리스트, 위험평가 연계 방법**을 정리합니다.

---

## 1. PaaS DB 진단의 특수성

### IaaS vs PaaS: 진단 접근의 근본적 차이

| 구분 | IaaS (VM 위 DB) | PaaS (Managed DB) |
| :--- | :--- | :--- |
| **OS 접근** | SSH/RDP로 직접 접근 가능 | ❌ 접근 불가 |
| **진단 방식** | 에이전트 설치, 스크립트 실행 | **Azure API/CLI 기반 설정 점검** |
| **책임 범위** | OS + DB + 네트워크 전체 | **설정(Configuration) + 접근제어** |
| **패치 관리** | 직접 수행 | Microsoft 자동 관리 |
| **진단 도구** | KISA 스크립트, Lynis 등 | `az cli`, `az rest`, PowerShell |

### PaaS DB에서 진단 가능한 보안 영역

PaaS에서는 OS 레벨 진단이 불가능하므로, **"설정(Configuration) 보안"**에 집중해야 합니다.

```
┌─────────────────────────────────────────────────────┐
│                 PaaS DB 진단 영역                      │
├─────────────────────────────────────────────────────┤
│  ① 네트워크 보안    │ Private Endpoint, 방화벽 규칙      │
│  ② 인증/인가        │ Azure AD 인증, 패스워드 정책       │
│  ③ 암호화           │ TLS 강제, 미사용 시 암호화(CMK)    │
│  ④ 감사/로깅        │ 진단 로그, 감사 로그 활성화         │
│  ⑤ 백업/복원        │ 백업 보존 기간, 지역 중복           │
│  ⑥ 서버 매개변수    │ DB별 보안 관련 파라미터 설정        │
│  ⑦ 고가용성/DR      │ 영역 중복, 읽기 복제본              │
└─────────────────────────────────────────────────────┘
```

---

## 2. 200대 대규모 환경 진단 전략

### 2.1. 진단 워크플로우

200대를 수동으로 점검하는 것은 비현실적입니다. **Azure CLI 기반 스크립트로 자동화**하는 것이 핵심입니다.

```
[1단계] 자산 식별          Azure Resource Graph로 전체 PaaS DB 목록 추출
         │
         ▼
[2단계] 설정 수집          az cli로 각 리소스의 보안 설정 일괄 수집
         │
         ▼
[3단계] 기준 비교          체크리스트 기준과 현재 설정 비교 (Pass/Fail)
         │
         ▼
[4단계] 결과 분석          위험도 산정 (Critical/High/Medium/Low)
         │
         ▼
[5단계] 보고서 생성        리소스별 진단 결과 + 조치 가이드 출력
         │
         ▼
[6단계] 위험평가 연계      진단 결과 → 위험평가 매트릭스 반영
```

### 2.2. 자산 식별 스크립트

Azure Resource Graph를 사용하면 전체 구독에서 PaaS DB를 **한 번에** 조회할 수 있습니다.

```bash
#!/bin/bash
# paas_db_inventory.sh - Azure PaaS DB 자산 목록 추출

echo "=== Azure PaaS DB 자산 식별 ==="
echo "실행 시각: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Azure 로그인 확인
az account show > /dev/null 2>&1 || { echo "❌ Azure 로그인이 필요합니다: az login"; exit 1; }

OUTPUT_DIR="./paas_db_audit_$(date '+%Y%m%d')"
mkdir -p "$OUTPUT_DIR"

# ① Redis 목록 추출
echo "[1/3] Azure Cache for Redis 조회 중..."
az redis list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location, SKU:sku.name, Version:redisVersion, HostName:hostName}" \
  -o table > "$OUTPUT_DIR/redis_inventory.txt"
az redis list -o json > "$OUTPUT_DIR/redis_inventory.json"
REDIS_COUNT=$(az redis list --query "length([])" -o tsv)
echo "  → Redis: ${REDIS_COUNT}대"

# ② PostgreSQL Flexible Server 목록 추출
echo "[2/3] Azure Database for PostgreSQL 조회 중..."
az postgres flexible-server list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location, SKU:sku.name, Version:version, State:state}" \
  -o table > "$OUTPUT_DIR/postgresql_inventory.txt"
az postgres flexible-server list -o json > "$OUTPUT_DIR/postgresql_inventory.json"
PG_COUNT=$(az postgres flexible-server list --query "length([])" -o tsv)
echo "  → PostgreSQL: ${PG_COUNT}대"

# ③ MySQL Flexible Server 목록 추출
echo "[3/3] Azure Database for MySQL 조회 중..."
az mysql flexible-server list --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location, SKU:sku.name, Version:version, State:state}" \
  -o table > "$OUTPUT_DIR/mysql_inventory.txt"
az mysql flexible-server list -o json > "$OUTPUT_DIR/mysql_inventory.json"
MYSQL_COUNT=$(az mysql flexible-server list --query "length([])" -o tsv)
echo "  → MySQL: ${MYSQL_COUNT}대"

echo ""
echo "=== 총 ${REDIS_COUNT:-0} + ${PG_COUNT:-0} + ${MYSQL_COUNT:-0} 대 식별 완료 ==="
echo "결과 저장: $OUTPUT_DIR/"
```

---

## 3. 공통 보안 체크리스트 (전체 PaaS DB 적용)

모든 PaaS DB에 공통으로 적용되는 보안 점검 항목입니다.

| # | 점검 항목 | 진단 기준 | ISMS 매핑 | ISO 27001 |
| :--- | :--- | :--- | :--- | :--- |
| C-01 | **Public 네트워크 접근 비활성화** | publicNetworkAccess = Disabled | 2.6.2 네트워크 접근 | A.13.1.1 |
| C-02 | **Private Endpoint 구성 여부** | privateEndpointConnections 존재 | 2.6.2 네트워크 접근 | A.13.1.3 |
| C-03 | **TLS 최소 버전 1.2 이상** | minimumTlsVersion >= 1.2 | 2.7.1 암호정책 | A.10.1.1 |
| C-04 | **방화벽 규칙에 0.0.0.0 미포함** | firewallRules에 전체 허용 없음 | 2.6.2 네트워크 접근 | A.13.1.1 |
| C-05 | **Azure AD 인증 활성화** | AAD 인증 설정 여부 | 2.5.1 사용자 인증 | A.9.2.1 |
| C-06 | **진단 로그 활성화** | diagnosticSettings 구성 여부 | 2.11.3 로그 관리 | A.12.4.1 |
| C-07 | **백업 보존 기간 적정 (7일 이상)** | backupRetentionDays >= 7 | 2.9.4 백업 관리 | A.12.3.1 |
| C-08 | **지역 중복 백업 활성화** | geoRedundantBackup = Enabled | 2.9.4 백업 관리 | A.17.1.2 |
| C-09 | **Microsoft Defender for Cloud 활성화** | ATP 설정 활성화 여부 | 2.11.1 사고 대응 | A.16.1.2 |
| C-10 | **리소스 잠금(Lock) 설정** | 삭제 방지 잠금 적용 여부 | 2.9.1 시스템 보안 | A.12.1.2 |

---

## 4. Redis (Azure Cache for Redis) 체크리스트

### 4.1. 진단 항목

| # | 점검 항목 | 진단 기준 | 위험도 | az cli 확인 명령어 |
| :--- | :--- | :--- | :--- | :--- |
| R-01 | **비TLS 포트(6379) 비활성화** | enableNonSslPort = false | 🔴 High | `az redis show --query enableNonSslPort` |
| R-02 | **TLS 최소 버전 1.2** | minimumTlsVersion = 1.2 | 🔴 High | `az redis show --query minimumTlsVersion` |
| R-03 | **인증(Access Key) 사용 여부** | Redis AUTH 활성화 | 🟡 Medium | `az redis list-keys` |
| R-04 | **Azure AD 인증(AAD Auth)** | AAD 인증 활성화 권장 | 🟡 Medium | `az redis show --query redisConfiguration.aad-enabled` |
| R-05 | **VNet 통합 또는 Private Endpoint** | 네트워크 격리 여부 | 🔴 High | `az redis show --query privateEndpointConnections` |
| R-06 | **Public 네트워크 접근 차단** | publicNetworkAccess = Disabled | 🔴 High | `az redis show --query publicNetworkAccess` |
| R-07 | **방화벽 규칙 점검** | 과도한 IP 허용 없음 | 🟡 Medium | `az redis firewall-rules list` |
| R-08 | **데이터 지속성(RDB/AOF) 설정** | 백업 전략 적용 여부 | 🟡 Medium | `az redis show --query redisConfiguration` |
| R-09 | **Patch Schedule 설정** | 유지보수 일정 지정 | 🟢 Low | `az redis patch-schedule show` |
| R-10 | **SKU 적정성 (Basic 미사용)** | Standard 이상 사용 | 🟡 Medium | `az redis show --query sku.name` |

### 4.2. Redis 자동 진단 스크립트

```bash
#!/bin/bash
# redis_security_audit.sh - Azure Cache for Redis 보안 진단

REPORT_FILE="./paas_db_audit_$(date '+%Y%m%d')/redis_audit_report.csv"
echo "항목ID,리소스명,리소스그룹,점검항목,현재값,기준값,결과" > "$REPORT_FILE"

check_result() {
  local id=$1 name=$2 rg=$3 item=$4 current=$5 expected=$6
  if [ "$current" == "$expected" ]; then
    echo "$id,$name,$rg,$item,$current,$expected,✅ Pass" >> "$REPORT_FILE"
  else
    echo "$id,$name,$rg,$item,$current,$expected,❌ Fail" >> "$REPORT_FILE"
  fi
}

echo "=== Azure Cache for Redis 보안 진단 시작 ==="

az redis list --query "[].{name:name, rg:resourceGroup}" -o tsv | while IFS=$'\t' read -r NAME RG; do
  echo "  진단 중: $NAME ($RG)"

  # R-01: 비TLS 포트 비활성화
  NON_SSL=$(az redis show -n "$NAME" -g "$RG" --query "enableNonSslPort" -o tsv 2>/dev/null)
  check_result "R-01" "$NAME" "$RG" "비TLS포트비활성화" "$NON_SSL" "false"

  # R-02: TLS 최소 버전
  TLS_VER=$(az redis show -n "$NAME" -g "$RG" --query "minimumTlsVersion" -o tsv 2>/dev/null)
  check_result "R-02" "$NAME" "$RG" "TLS최소버전1.2" "$TLS_VER" "1.2"

  # R-05: Private Endpoint
  PE_COUNT=$(az redis show -n "$NAME" -g "$RG" --query "length(privateEndpointConnections)" -o tsv 2>/dev/null)
  if [ "$PE_COUNT" -gt 0 ] 2>/dev/null; then
    check_result "R-05" "$NAME" "$RG" "PrivateEndpoint" "구성됨($PE_COUNT)" "구성됨" 
  else
    echo "R-05,$NAME,$RG,PrivateEndpoint,미구성,구성필요,❌ Fail" >> "$REPORT_FILE"
  fi

  # R-06: Public 네트워크 접근
  PUBLIC=$(az redis show -n "$NAME" -g "$RG" --query "publicNetworkAccess" -o tsv 2>/dev/null)
  check_result "R-06" "$NAME" "$RG" "Public접근차단" "$PUBLIC" "Disabled"

  # R-07: 방화벽 규칙 (0.0.0.0 전체 허용 확인)
  FW_ALL=$(az redis firewall-rules list -n "$NAME" -g "$RG" --query "[?startIP=='0.0.0.0']" -o tsv 2>/dev/null)
  if [ -z "$FW_ALL" ]; then
    echo "R-07,$NAME,$RG,방화벽전체허용,없음,없음,✅ Pass" >> "$REPORT_FILE"
  else
    echo "R-07,$NAME,$RG,방화벽전체허용,전체허용존재,없음,❌ Fail" >> "$REPORT_FILE"
  fi

  # R-10: SKU 확인 (Basic 미사용)
  SKU=$(az redis show -n "$NAME" -g "$RG" --query "sku.name" -o tsv 2>/dev/null)
  if [ "$SKU" != "Basic" ]; then
    echo "R-10,$NAME,$RG,SKU적정성,$SKU,Standard이상,✅ Pass" >> "$REPORT_FILE"
  else
    echo "R-10,$NAME,$RG,SKU적정성,$SKU,Standard이상,❌ Fail" >> "$REPORT_FILE"
  fi

done

echo "=== Redis 진단 완료 → $REPORT_FILE ==="
```

---

## 5. PostgreSQL (Azure Database for PostgreSQL Flexible Server) 체크리스트

### 5.1. 진단 항목

| # | 점검 항목 | 진단 기준 | 위험도 | az cli 확인 명령어 |
| :--- | :--- | :--- | :--- | :--- |
| P-01 | **SSL 연결 강제** | require_secure_transport = ON | 🔴 High | `az postgres flexible-server parameter show --name require_secure_transport` |
| P-02 | **TLS 최소 버전 1.2** | ssl_min_protocol_version = TLSv1.2 | 🔴 High | `az postgres flexible-server parameter show --name ssl_min_protocol_version` |
| P-03 | **비밀번호 암호화 방식** | password_encryption = scram-sha-256 | 🟡 Medium | `az postgres flexible-server parameter show --name password_encryption` |
| P-04 | **로그 연결 기록** | log_connections = ON | 🟡 Medium | `az postgres flexible-server parameter show --name log_connections` |
| P-05 | **로그 연결 해제 기록** | log_disconnections = ON | 🟡 Medium | `az postgres flexible-server parameter show --name log_disconnections` |
| P-06 | **감사 로그(pgAudit) 활성화** | pgaudit.log = all 또는 ddl,write | 🔴 High | `az postgres flexible-server parameter show --name pgaudit.log` |
| P-07 | **최대 연결 수 제한** | max_connections 적정값 설정 | 🟢 Low | `az postgres flexible-server parameter show --name max_connections` |
| P-08 | **로그 보존 기간** | logfiles.retention_days >= 7 | 🟡 Medium | `az postgres flexible-server parameter show --name logfiles.retention_days` |
| P-09 | **불필요한 확장 기능 비활성화** | shared_preload_libraries 점검 | 🟡 Medium | `az postgres flexible-server parameter show --name shared_preload_libraries` |
| P-10 | **connection_throttle 활성화** | connection_throttle.enable = ON | 🟡 Medium | `az postgres flexible-server parameter show --name connection_throttle.enable` |
| P-11 | **Public 네트워크 접근 차단** | 네트워크 유형 Private Access | 🔴 High | `az postgres flexible-server show --query network` |
| P-12 | **백업 보존 기간** | backupRetentionDays >= 7 | 🟡 Medium | `az postgres flexible-server show --query backup` |

### 5.2. PostgreSQL 자동 진단 스크립트

```bash
#!/bin/bash
# postgresql_security_audit.sh - Azure Database for PostgreSQL 보안 진단

REPORT_FILE="./paas_db_audit_$(date '+%Y%m%d')/postgresql_audit_report.csv"
echo "항목ID,리소스명,리소스그룹,점검항목,현재값,기준값,결과" > "$REPORT_FILE"

echo "=== Azure Database for PostgreSQL 보안 진단 시작 ==="

get_param() {
  local name=$1 rg=$2 param=$3
  az postgres flexible-server parameter show \
    --server-name "$name" -g "$rg" --name "$param" \
    --query "value" -o tsv 2>/dev/null
}

az postgres flexible-server list --query "[].{name:name, rg:resourceGroup}" -o tsv | while IFS=$'\t' read -r NAME RG; do
  echo "  진단 중: $NAME ($RG)"

  # P-01: SSL 강제
  SSL=$(get_param "$NAME" "$RG" "require_secure_transport")
  if [ "${SSL,,}" == "on" ]; then
    echo "P-01,$NAME,$RG,SSL강제,$SSL,ON,✅ Pass" >> "$REPORT_FILE"
  else
    echo "P-01,$NAME,$RG,SSL강제,$SSL,ON,❌ Fail" >> "$REPORT_FILE"
  fi

  # P-02: TLS 최소 버전
  TLS=$(get_param "$NAME" "$RG" "ssl_min_protocol_version")
  if [ "$TLS" == "TLSv1.2" ] || [ "$TLS" == "TLSv1.3" ]; then
    echo "P-02,$NAME,$RG,TLS최소버전,$TLS,TLSv1.2이상,✅ Pass" >> "$REPORT_FILE"
  else
    echo "P-02,$NAME,$RG,TLS최소버전,$TLS,TLSv1.2이상,❌ Fail" >> "$REPORT_FILE"
  fi

  # P-03: 비밀번호 암호화
  PW_ENC=$(get_param "$NAME" "$RG" "password_encryption")
  if [ "$PW_ENC" == "scram-sha-256" ]; then
    echo "P-03,$NAME,$RG,비밀번호암호화,$PW_ENC,scram-sha-256,✅ Pass" >> "$REPORT_FILE"
  else
    echo "P-03,$NAME,$RG,비밀번호암호화,$PW_ENC,scram-sha-256,❌ Fail" >> "$REPORT_FILE"
  fi

  # P-04: 로그 연결 기록
  LOG_CONN=$(get_param "$NAME" "$RG" "log_connections")
  if [ "${LOG_CONN,,}" == "on" ]; then
    echo "P-04,$NAME,$RG,연결로그,$LOG_CONN,ON,✅ Pass" >> "$REPORT_FILE"
  else
    echo "P-04,$NAME,$RG,연결로그,$LOG_CONN,ON,❌ Fail" >> "$REPORT_FILE"
  fi

  # P-05: 로그 연결 해제 기록
  LOG_DISC=$(get_param "$NAME" "$RG" "log_disconnections")
  if [ "${LOG_DISC,,}" == "on" ]; then
    echo "P-05,$NAME,$RG,연결해제로그,$LOG_DISC,ON,✅ Pass" >> "$REPORT_FILE"
  else
    echo "P-05,$NAME,$RG,연결해제로그,$LOG_DISC,ON,❌ Fail" >> "$REPORT_FILE"
  fi

  # P-06: 감사 로그
  PGAUDIT=$(get_param "$NAME" "$RG" "pgaudit.log")
  if [ -n "$PGAUDIT" ] && [ "$PGAUDIT" != "none" ]; then
    echo "P-06,$NAME,$RG,감사로그,$PGAUDIT,활성화,✅ Pass" >> "$REPORT_FILE"
  else
    echo "P-06,$NAME,$RG,감사로그,${PGAUDIT:-미설정},활성화,❌ Fail" >> "$REPORT_FILE"
  fi

  # P-10: Connection Throttle
  THROTTLE=$(get_param "$NAME" "$RG" "connection_throttle.enable")
  if [ "${THROTTLE,,}" == "on" ]; then
    echo "P-10,$NAME,$RG,ConnectionThrottle,$THROTTLE,ON,✅ Pass" >> "$REPORT_FILE"
  else
    echo "P-10,$NAME,$RG,ConnectionThrottle,$THROTTLE,ON,❌ Fail" >> "$REPORT_FILE"
  fi

  # P-11: 네트워크 접근
  NETWORK=$(az postgres flexible-server show -n "$NAME" -g "$RG" --query "network.publicNetworkAccess" -o tsv 2>/dev/null)
  if [ "${NETWORK,,}" == "disabled" ]; then
    echo "P-11,$NAME,$RG,Public접근차단,$NETWORK,Disabled,✅ Pass" >> "$REPORT_FILE"
  else
    echo "P-11,$NAME,$RG,Public접근차단,$NETWORK,Disabled,❌ Fail" >> "$REPORT_FILE"
  fi

  # P-12: 백업 보존 기간
  BACKUP_DAYS=$(az postgres flexible-server show -n "$NAME" -g "$RG" --query "backup.backupRetentionDays" -o tsv 2>/dev/null)
  if [ "$BACKUP_DAYS" -ge 7 ] 2>/dev/null; then
    echo "P-12,$NAME,$RG,백업보존기간,${BACKUP_DAYS}일,7일이상,✅ Pass" >> "$REPORT_FILE"
  else
    echo "P-12,$NAME,$RG,백업보존기간,${BACKUP_DAYS:-미설정}일,7일이상,❌ Fail" >> "$REPORT_FILE"
  fi

done

echo "=== PostgreSQL 진단 완료 → $REPORT_FILE ==="
```

---

## 6. MySQL (Azure Database for MySQL Flexible Server) 체크리스트

### 6.1. 진단 항목

| # | 점검 항목 | 진단 기준 | 위험도 | az cli 확인 명령어 |
| :--- | :--- | :--- | :--- | :--- |
| M-01 | **SSL 연결 강제** | require_secure_transport = ON | 🔴 High | `az mysql flexible-server parameter show --name require_secure_transport` |
| M-02 | **TLS 최소 버전 1.2** | tls_version에 TLSv1.0/1.1 미포함 | 🔴 High | `az mysql flexible-server parameter show --name tls_version` |
| M-03 | **감사 로그 활성화** | audit_log_enabled = ON | 🔴 High | `az mysql flexible-server parameter show --name audit_log_enabled` |
| M-04 | **감사 로그 이벤트 범위** | audit_log_events에 CONNECTION,DCL,DDL 포함 | 🟡 Medium | `az mysql flexible-server parameter show --name audit_log_events` |
| M-05 | **slow_query_log 활성화** | slow_query_log = ON | 🟡 Medium | `az mysql flexible-server parameter show --name slow_query_log` |
| M-06 | **local_infile 비활성화** | local_infile = OFF | 🟡 Medium | `az mysql flexible-server parameter show --name local_infile` |
| M-07 | **max_connections 적정 설정** | 환경에 맞는 적정값 | 🟢 Low | `az mysql flexible-server parameter show --name max_connections` |
| M-08 | **Public 네트워크 접근 차단** | publicNetworkAccess = Disabled | 🔴 High | `az mysql flexible-server show --query network` |
| M-09 | **백업 보존 기간** | backupRetentionDays >= 7 | 🟡 Medium | `az mysql flexible-server show --query backup` |
| M-10 | **지역 중복 백업** | geoRedundantBackup = Enabled | 🟡 Medium | `az mysql flexible-server show --query backup` |
| M-11 | **방화벽 전체 허용 규칙 없음** | 0.0.0.0-255.255.255.255 미존재 | 🔴 High | `az mysql flexible-server firewall-rule list` |
| M-12 | **init_connect 설정 검토** | 불필요한 자동 실행 SQL 없음 | 🟢 Low | `az mysql flexible-server parameter show --name init_connect` |

### 6.2. MySQL 자동 진단 스크립트

```bash
#!/bin/bash
# mysql_security_audit.sh - Azure Database for MySQL 보안 진단

REPORT_FILE="./paas_db_audit_$(date '+%Y%m%d')/mysql_audit_report.csv"
echo "항목ID,리소스명,리소스그룹,점검항목,현재값,기준값,결과" > "$REPORT_FILE"

echo "=== Azure Database for MySQL 보안 진단 시작 ==="

get_param() {
  local name=$1 rg=$2 param=$3
  az mysql flexible-server parameter show \
    --server-name "$name" -g "$rg" --name "$param" \
    --query "value" -o tsv 2>/dev/null
}

az mysql flexible-server list --query "[].{name:name, rg:resourceGroup}" -o tsv | while IFS=$'\t' read -r NAME RG; do
  echo "  진단 중: $NAME ($RG)"

  # M-01: SSL 강제
  SSL=$(get_param "$NAME" "$RG" "require_secure_transport")
  if [ "${SSL,,}" == "on" ]; then
    echo "M-01,$NAME,$RG,SSL강제,$SSL,ON,✅ Pass" >> "$REPORT_FILE"
  else
    echo "M-01,$NAME,$RG,SSL강제,$SSL,ON,❌ Fail" >> "$REPORT_FILE"
  fi

  # M-02: TLS 버전
  TLS=$(get_param "$NAME" "$RG" "tls_version")
  if echo "$TLS" | grep -qvE "TLSv1$|TLSv1\.1"; then
    echo "M-02,$NAME,$RG,TLS버전,$TLS,TLSv1.2이상만,✅ Pass" >> "$REPORT_FILE"
  else
    echo "M-02,$NAME,$RG,TLS버전,$TLS,TLSv1.2이상만,❌ Fail" >> "$REPORT_FILE"
  fi

  # M-03: 감사 로그
  AUDIT=$(get_param "$NAME" "$RG" "audit_log_enabled")
  if [ "${AUDIT,,}" == "on" ]; then
    echo "M-03,$NAME,$RG,감사로그,$AUDIT,ON,✅ Pass" >> "$REPORT_FILE"
  else
    echo "M-03,$NAME,$RG,감사로그,$AUDIT,ON,❌ Fail" >> "$REPORT_FILE"
  fi

  # M-04: 감사 로그 이벤트 범위
  AUDIT_EVENTS=$(get_param "$NAME" "$RG" "audit_log_events")
  if echo "$AUDIT_EVENTS" | grep -qi "CONNECTION" && echo "$AUDIT_EVENTS" | grep -qi "DDL"; then
    echo "M-04,$NAME,$RG,감사이벤트범위,$AUDIT_EVENTS,CONNECTION+DDL포함,✅ Pass" >> "$REPORT_FILE"
  else
    echo "M-04,$NAME,$RG,감사이벤트범위,$AUDIT_EVENTS,CONNECTION+DDL포함,❌ Fail" >> "$REPORT_FILE"
  fi

  # M-06: local_infile 비활성화
  LOCAL_INFILE=$(get_param "$NAME" "$RG" "local_infile")
  if [ "${LOCAL_INFILE,,}" == "off" ]; then
    echo "M-06,$NAME,$RG,local_infile,$LOCAL_INFILE,OFF,✅ Pass" >> "$REPORT_FILE"
  else
    echo "M-06,$NAME,$RG,local_infile,$LOCAL_INFILE,OFF,❌ Fail" >> "$REPORT_FILE"
  fi

  # M-08: Public 네트워크 접근
  NETWORK=$(az mysql flexible-server show -n "$NAME" -g "$RG" --query "network.publicNetworkAccess" -o tsv 2>/dev/null)
  if [ "${NETWORK,,}" == "disabled" ]; then
    echo "M-08,$NAME,$RG,Public접근차단,$NETWORK,Disabled,✅ Pass" >> "$REPORT_FILE"
  else
    echo "M-08,$NAME,$RG,Public접근차단,$NETWORK,Disabled,❌ Fail" >> "$REPORT_FILE"
  fi

  # M-09: 백업 보존 기간
  BACKUP_DAYS=$(az mysql flexible-server show -n "$NAME" -g "$RG" --query "backup.backupRetentionDays" -o tsv 2>/dev/null)
  if [ "$BACKUP_DAYS" -ge 7 ] 2>/dev/null; then
    echo "M-09,$NAME,$RG,백업보존기간,${BACKUP_DAYS}일,7일이상,✅ Pass" >> "$REPORT_FILE"
  else
    echo "M-09,$NAME,$RG,백업보존기간,${BACKUP_DAYS:-미설정}일,7일이상,❌ Fail" >> "$REPORT_FILE"
  fi

  # M-11: 방화벽 전체 허용
  FW_ALL=$(az mysql flexible-server firewall-rule list -g "$RG" --name "$NAME" \
    --query "[?startIpAddress=='0.0.0.0' && endIpAddress=='255.255.255.255']" -o tsv 2>/dev/null)
  if [ -z "$FW_ALL" ]; then
    echo "M-11,$NAME,$RG,방화벽전체허용,없음,없음,✅ Pass" >> "$REPORT_FILE"
  else
    echo "M-11,$NAME,$RG,방화벽전체허용,전체허용존재,없음,❌ Fail" >> "$REPORT_FILE"
  fi

done

echo "=== MySQL 진단 완료 → $REPORT_FILE ==="
```

---

## 7. 통합 실행 스크립트 (원클릭 진단)

위 개별 스크립트들을 한 번에 실행하는 메인 스크립트입니다.

```bash
#!/bin/bash
# run_paas_db_audit.sh - PaaS DB 전체 보안 진단 실행

set -e

AUDIT_DATE=$(date '+%Y%m%d')
OUTPUT_DIR="./paas_db_audit_${AUDIT_DATE}"
mkdir -p "$OUTPUT_DIR"

echo "╔══════════════════════════════════════════════════╗"
echo "║   Azure PaaS DB 보안 취약점 진단 도구 v1.0       ║"
echo "║   대상: Redis / PostgreSQL / MySQL               ║"
echo "║   기준: ISMS / ISO 27001                         ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "실행 시각: $(date '+%Y-%m-%d %H:%M:%S')"
echo "결과 디렉토리: $OUTPUT_DIR"
echo ""

# Azure 로그인 확인
az account show > /dev/null 2>&1 || { echo "❌ az login을 먼저 실행하세요."; exit 1; }
SUBSCRIPTION=$(az account show --query "name" -o tsv)
echo "구독: $SUBSCRIPTION"
echo ""

# 1단계: 자산 식별
echo "━━━ [1/4] 자산 식별 ━━━"
bash paas_db_inventory.sh

# 2단계: Redis 진단
echo ""
echo "━━━ [2/4] Redis 보안 진단 ━━━"
bash redis_security_audit.sh

# 3단계: PostgreSQL 진단
echo ""
echo "━━━ [3/4] PostgreSQL 보안 진단 ━━━"
bash postgresql_security_audit.sh

# 4단계: MySQL 진단
echo ""
echo "━━━ [4/4] MySQL 보안 진단 ━━━"
bash mysql_security_audit.sh

# 결과 요약
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║                  진단 결과 요약                    ║"
echo "╚══════════════════════════════════════════════════╝"

for REPORT in "$OUTPUT_DIR"/*_audit_report.csv; do
  if [ -f "$REPORT" ]; then
    TOTAL=$(tail -n +2 "$REPORT" | wc -l | tr -d ' ')
    PASS=$(grep -c "✅ Pass" "$REPORT" || true)
    FAIL=$(grep -c "❌ Fail" "$REPORT" || true)
    BASENAME=$(basename "$REPORT" .csv)
    echo "  📊 $BASENAME: 총 ${TOTAL}건 (Pass: ${PASS} / Fail: ${FAIL})"
  fi
done

echo ""
echo "📁 상세 결과: $OUTPUT_DIR/"
echo "🕐 완료 시각: $(date '+%Y-%m-%d %H:%M:%S')"
```

---

## 8. 위험평가 연계

### 8.1. 진단 결과 → 위험평가 매트릭스 변환

취약점 진단 결과를 ISMS/ISO 27001 위험평가에 반영하는 방법입니다.

| 진단 결과 | 위험도 등급 | 영향도 | 발생 가능성 | 위험 수준 | 조치 기한 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 🔴 Fail (High 항목) | **상** | 3 | 3 | **9 (즉시 조치)** | 1주 이내 |
| 🟡 Fail (Medium 항목) | **중** | 2 | 2 | **4 (계획 조치)** | 1달 이내 |
| 🟢 Fail (Low 항목) | **하** | 1 | 1 | **1 (수용 검토)** | 분기 내 |
| ✅ Pass | - | - | - | **위험 없음** | - |

### 8.2. 위험평가 보고서 생성 스크립트

```bash
#!/bin/bash
# generate_risk_report.sh - 진단 결과를 위험평가 매트릭스로 변환

OUTPUT_DIR="./paas_db_audit_$(date '+%Y%m%d')"
RISK_REPORT="$OUTPUT_DIR/risk_assessment_report.csv"

echo "자산명,리소스그룹,점검항목,진단결과,위험도,영향도,발생가능성,위험수준,조치기한,ISMS항목" > "$RISK_REPORT"

# 위험도 매핑 함수
get_risk_level() {
  local item_id=$1
  case "$item_id" in
    R-01|R-02|R-05|R-06|P-01|P-02|P-06|P-11|M-01|M-02|M-03|M-08|M-11|C-01|C-02)
      echo "상,3,3,9,1주이내" ;;
    R-03|R-04|R-07|R-08|R-10|P-03|P-04|P-05|P-08|P-09|P-10|P-12|M-04|M-06|M-09|M-10|C-03|C-04|C-05|C-06|C-07|C-08|C-09|C-10)
      echo "중,2,2,4,1달이내" ;;
    *)
      echo "하,1,1,1,분기내" ;;
  esac
}

# 모든 진단 결과 CSV를 읽어 위험평가로 변환
for REPORT in "$OUTPUT_DIR"/*_audit_report.csv; do
  [ -f "$REPORT" ] || continue
  tail -n +2 "$REPORT" | while IFS=',' read -r ID NAME RG ITEM CURRENT EXPECTED RESULT; do
    if echo "$RESULT" | grep -q "❌"; then
      RISK=$(get_risk_level "$ID")
      echo "$NAME,$RG,$ITEM,$RESULT,$RISK,2.6~2.11" >> "$RISK_REPORT"
    fi
  done
done

echo "=== 위험평가 보고서 생성 완료: $RISK_REPORT ==="

# 요약 통계
echo ""
echo "[ 위험 수준별 통계 ]"
echo "  🔴 상 (즉시 조치): $(grep ',상,' "$RISK_REPORT" | wc -l | tr -d ' ')건"
echo "  🟡 중 (계획 조치): $(grep ',중,' "$RISK_REPORT" | wc -l | tr -d ' ')건"
echo "  🟢 하 (수용 검토): $(grep ',하,' "$RISK_REPORT" | wc -l | tr -d ' ')건"
```

---

## 9. ISMS / ISO 27001 통제항목 매핑

### 9.1. ISMS-P 기술적 보호조치 매핑

| ISMS 항목 | 통제 내용 | PaaS DB 점검 항목 |
| :--- | :--- | :--- |
| **2.5.1** | 사용자 인증 | C-05, R-03, R-04 (인증 방식) |
| **2.5.2** | 사용자 식별 | Azure AD 인증 활성화 |
| **2.6.1** | 접근권한 관리 | 방화벽 규칙, RBAC |
| **2.6.2** | 네트워크 접근 | C-01, C-02, C-04, R-05, R-06, P-11, M-08 |
| **2.7.1** | 암호정책 수립 및 이행 | C-03, R-01, R-02, P-01, P-02, P-03, M-01, M-02 |
| **2.9.1** | 시스템 보안 | 서버 매개변수 보안 설정 |
| **2.9.4** | 백업 및 복구 관리 | C-07, C-08, P-12, M-09, M-10 |
| **2.10.1** | 보안 패치 관리 | PaaS는 MS 자동 관리 (증적 필요) |
| **2.11.1** | 사고 예방 및 대응 | C-09 (Defender for Cloud) |
| **2.11.3** | 로그 관리 | C-06, P-04, P-05, P-06, M-03, M-04, M-05 |

### 9.2. ISO 27001:2022 Annex A 매핑

| ISO 27001 | 통제 내용 | PaaS DB 관련 항목 |
| :--- | :--- | :--- |
| **A.8.9** | Configuration management | 전체 서버 매개변수 점검 |
| **A.8.20** | Network security | C-01, C-02, C-04, Private Endpoint |
| **A.8.24** | Use of cryptography | TLS, 암호화 설정 전체 |
| **A.8.25** | Secure development lifecycle | 초기 배포 시 보안 설정 검증 |
| **A.5.23** | Information security for cloud services | 전체 PaaS DB 보안 설정 |
| **A.8.15** | Logging | 감사 로그, 진단 로그 |
| **A.8.13** | Information backup | 백업 보존, 지역 중복 |

---

## 10. 심사 대응 TIP

### 10.1. 증적자료 목록

ISMS / ISO 27001 인증 심사 시 제출해야 할 증적 자료 체크리스트입니다.

| # | 증적 자료 | 생성 방법 | 비고 |
| :--- | :--- | :--- | :--- |
| 1 | PaaS DB 자산 목록 | `paas_db_inventory.sh` 결과 | 자산 식별 증적 |
| 2 | 보안 설정 진단 결과 | 각 DBMS 진단 스크립트 CSV | 취약점 진단 증적 |
| 3 | 위험평가 보고서 | `generate_risk_report.sh` 결과 | 위험평가 증적 |
| 4 | 조치 이행 계획서 | Fail 항목 별 대응 계획 수립 | 보완조치 계획 증적 |
| 5 | 조치 완료 후 재진단 결과 | 동일 스크립트 재실행 | **조치 검증 증적** |

### 10.2. 심사관이 자주 묻는 질문

> **Q: PaaS DB는 OS 접근이 안 되는데, 취약점 진단을 어떻게 수행했나요?**
>
> A: PaaS 환경에서는 OS 레벨 진단이 불가능하며, 이는 CSP(Microsoft)가 책임지는 영역입니다. 당사는 **공동 책임 모델(Shared Responsibility Model)**에 따라 고객 책임 영역인 **설정(Configuration) 보안**을 Azure CLI/API 기반 자동화 스크립트로 진단하고 있습니다.

> **Q: 200대를 모두 진단했는지 어떻게 확인하나요?**
>
> A: Azure Resource Graph로 전체 PaaS DB 자산을 먼저 추출하고, 추출된 목록과 진단 결과의 리소스 수를 대조하여 **전수 진단 여부를 검증**합니다. (자산목록 대 진단결과 1:1 매칭)

> **Q: 보안 패치는 어떻게 관리하나요?**
>
> A: PaaS DB의 OS/엔진 패치는 Microsoft가 자동으로 관리합니다. Azure Service Health에서 패치 이력을 확인할 수 있으며, **Redis의 경우 Patch Schedule**을 설정하여 유지보수 창을 지정하고 있습니다.

---

> **참고**: 이 체크리스트는 Azure PaaS DB에 특화된 내용입니다. IaaS(VM 위 DB) 환경에서는 KISA 기술적 취약점 분석 가이드의 DBMS 진단 항목을 별도로 적용해야 합니다.
{: .prompt-warning }
