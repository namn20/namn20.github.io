---
layout: post
title: "Azure 환경에서 CSPM 구축하기 — Prowler로 시작하는 클라우드 보안 자세 관리"
date: 2026-04-21
categories: [Security, Cloud Security]
categories: [Security, Cloud Security]
tags: [azure, cspm, prowler, cloud-security, iam, compliance, misconfiguration]
---

Microsoft Azure 환경을 운영하는 조직이라면 한 번쯤은 이런 질문을 받거나 스스로 떠올린 적이 있을 겁니다.

> **"우리 Azure 환경, 지금 안전한가요?"**

보안팀의 인력과 시간이 충분하지 않은 상황에서, Azure 리소스 전체를 수동으로 점검하는 것은 사실상 불가능합니다. 이때 필요한 것이 바로 **CSPM(Cloud Security Posture Management)** 입니다.

오늘은 오픈소스 기반의 클라우드 보안 도구인 **Prowler**를 활용해 Azure 환경에서 CSPM을 구현하는 방법을 실무 중심으로 정리해보겠습니다.

---

## 🔍 CSPM이란 무엇인가?

**CSPM(Cloud Security Posture Management)** 은 클라우드 인프라의 보안 설정 오류(Misconfiguration), IAM 권한 과다 부여, 규정 준수 미비 등을 **지속적으로 자동 탐지·평가·개선**하는 프로세스 및 도구군을 뜻합니다.

클라우드 보안 사고의 상당수가 취약점 익스플로잇이 아닌 **잘못된 설정(Misconfiguration)** 에서 비롯된다는 점을 생각하면, CSPM은 사실상 클라우드 보안의 첫 번째 방어선이라고 볼 수 있습니다.

### CSPM이 다루는 주요 영역

| 영역 | 설명 | Azure 예시 |
|---|---|---|
| **Misconfiguration** | 잘못된 리소스 설정 탐지 | Blob Storage 퍼블릭 접근 허용, 방화벽 규칙 없는 DB |
| **IAM Risk** | 과다 권한, 미사용 계정 탐지 | Owner 권한 남발, MFA 미설정 계정 |
| **Network Exposure** | 외부 노출된 포트·서비스 탐지 | NSG에서 0.0.0.0/0 인바운드 허용 |
| **Data Security** | 민감 데이터 저장소 보호 수준 평가 | 저장 암호화·전송 암호화 미적용 |
| **Compliance** | 규정 프레임워크 준수 여부 평가 | CIS Azure Benchmark, ISO 27001, NIST |

---

## 🚀 왜 Prowler인가?

[Prowler](https://prowler.com/microsoft-azure)는 **Microsoft 공식 파트너로 인정받은 오픈소스 클라우드 보안 도구**로, AWS·GCP·Azure·Kubernetes 등 멀티클라우드 환경을 단일 플랫폼에서 점검할 수 있다는 것이 가장 큰 강점입니다.

### Prowler의 핵심 장점

- ✅ **에이전트리스(Agentless)**: VM이나 별도 에이전트 설치 없이 Azure API만으로 동작
- ✅ **160개 이상의 Azure 전용 보안 체크**: Compute, Blob Storage, AKS, ACR, Microsoft Defender 등 주요 서비스 전반 커버
- ✅ **오픈소스**: 벤더 종속 없이 직접 커스터마이징 및 자동화 파이프라인 연동 가능
- ✅ **컴플라이언스 자동화**: CIS Azure Benchmark, ISO 27001, SOC2, GDPR, NIST 800-53 등 주요 프레임워크 매핑
- ✅ **신호 상관관계 분석**: 단순 체크리스트를 넘어 IAM 리스크 + 설정 오류 + 워크로드 인사이트를 조합해 우선순위 리스크 도출

---

## 🛠️ Prowler Azure 설정 및 실행 방법

### 1단계: 사전 준비

Prowler가 Azure 구독을 스캔하려면 적절한 **서비스 주체(Service Principal) 또는 관리 ID(Managed Identity)** 권한이 필요합니다.

```bash
# Prowler 설치 (Python 기반)
pip install prowler

# Azure CLI 로그인
az login

# Prowler에 필요한 최소 권한 역할 할당 (Reader + Security Reader)
az role assignment create \
  --assignee "<YOUR_SERVICE_PRINCIPAL_APP_ID>" \
  --role "Reader" \
  --scope "/subscriptions/<YOUR_SUBSCRIPTION_ID>"

az role assignment create \
  --assignee "<YOUR_SERVICE_PRINCIPAL_APP_ID>" \
  --role "Security Reader" \
  --scope "/subscriptions/<YOUR_SUBSCRIPTION_ID>"
```

> **최소 권한 원칙(PoLP)**: Prowler는 읽기(Reader) 권한만으로 동작합니다. Owner나 Contributor 권한을 부여하지 마세요.

### 2단계: Azure 전체 보안 스캔 실행

```bash
# Azure 구독 전체 스캔
prowler azure --subscription-ids <YOUR_SUBSCRIPTION_ID>

# 특정 서비스만 빠르게 점검 (예: Blob Storage + IAM)
prowler azure --subscription-ids <YOUR_SUBSCRIPTION_ID> \
  --services storage iam

# CIS Azure Benchmark 기준 컴플라이언스 점검
prowler azure --subscription-ids <YOUR_SUBSCRIPTION_ID> \
  --compliance cis_azure_3.0.0

# HTML 리포트 출력
prowler azure --subscription-ids <YOUR_SUBSCRIPTION_ID> \
  --output-formats html json csv
```

### 3단계: 결과 분석 및 우선순위화

스캔이 완료되면 각 체크 결과는 **PASS / FAIL / MANUAL** 로 분류됩니다. 결과를 볼 때는 아래 기준으로 우선순위를 부여하세요.

```
CRITICAL → HIGH → MEDIUM → LOW → INFORMATIONAL
```

FAIL 항목 중 CRITICAL/HIGH 등급부터 먼저 처리하는 것이 핵심입니다.

---

## 🎯 Azure 환경에서 자주 발견되는 CSPM 주요 이슈

실무에서 Prowler를 통해 Azure 환경을 점검할 때 가장 빈번하게 발견되는 미설정(Misconfiguration) 유형을 정리했습니다.

### 🔴 Critical / High 등급

#### 1. Blob Storage 퍼블릭 액세스 허용
```
Check ID: azure_storage_blob_public_access_disabled
```
스토리지 계정 또는 컨테이너 수준에서 **익명 공개 접근이 허용**된 경우입니다. 내부 데이터가 아무 인증 없이 외부에 노출될 수 있어 가장 위험한 설정 중 하나입니다.

**즉시 조치**: 스토리지 계정 → 구성 → "Blob 공개 액세스" 비활성화

#### 2. MFA 미설정 계정 (특히 관리자 계정)
```
Check ID: azure_iam_user_mfa_enabled_console
```
Azure AD(Entra ID) 사용자 중 **MFA가 활성화되지 않은 계정**, 특히 Global Administrator 역할을 가진 계정은 계정 탈취 시 전체 테넌트가 위협받을 수 있습니다.

**즉시 조치**: Entra ID → 조건부 액세스(Conditional Access) 정책으로 전 사용자 MFA 강제화

#### 3. Key Vault 소프트 삭제 및 제거 보호 비활성화
```
Check ID: azure_keyvault_soft_delete_enabled
```
Key Vault의 소프트 삭제 기능이 꺼진 경우, 키·비밀·인증서가 삭제되면 **즉시 영구 제거**되어 복구 불가능한 상황이 발생합니다.

### 🟠 Medium 등급

#### 4. NSG(네트워크 보안 그룹)에서 0.0.0.0/0 인바운드 허용
```
Check ID: azure_network_security_group_restrict_ingress_ssh_port_22
```
SSH(22번), RDP(3389번) 포트가 전체 인터넷에 열려 있는 경우 무차별 대입 공격(Brute Force)의 표적이 됩니다.

**즉시 조치**: Just-In-Time(JIT) VM Access 활성화 또는 Azure Bastion으로 전환

#### 5. Microsoft Defender for Cloud 비활성화
```
Check ID: azure_defender_for_cloud_enabled
```
Microsoft Defender for Cloud가 주요 서비스(서버, SQL, 컨테이너, App Service 등)에 대해 **활성화되지 않은** 경우입니다. 위협 탐지의 기본 레이어가 없는 것과 같습니다.

#### 6. 진단 로그(Diagnostic Logs) 미설정
```
Check ID: azure_monitor_diagnostic_setting_enabled
```
Activity Log, 리소스별 진단 로그가 Log Analytics Workspace나 Storage Account로 전송되지 않으면, 침해 후 **포렌식 및 감사 추적이 불가능**합니다.

---

## 📊 CSPM 운영 자동화 — CI/CD 파이프라인 통합

CSPM은 한 번 점검으로 끝나는 것이 아니라 **지속적인 자세 관리(Continuous Posture Management)** 가 핵심입니다. GitHub Actions를 활용한 자동화 예시를 소개합니다.

```yaml
# .github/workflows/azure-cspm.yml
name: Azure CSPM Scan (Prowler)

on:
  schedule:
    - cron: '0 1 * * *'   # 매일 새벽 1시 자동 실행
  workflow_dispatch:

jobs:
  prowler-azure-scan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install Prowler
        run: pip install prowler

      - name: Run Prowler Azure Scan
        env:
          AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
        run: |
          prowler azure \
            --subscription-ids $AZURE_SUBSCRIPTION_ID \
            --compliance cis_azure_3.0.0 \
            --output-formats json html \
            --output-filename prowler-azure-report

      - name: Upload Report Artifact
        uses: actions/upload-artifact@v4
        with:
          name: prowler-azure-report
          path: output/
          retention-days: 30
```

이렇게 구성하면 매일 새벽 자동으로 전체 Azure 구독 보안 상태가 점검되고, 리포트가 GitHub Actions Artifact로 보관됩니다. **Slack Webhook이나 이메일 알림**을 추가하면 FAIL 항목 발생 시 즉각 알림을 받을 수 있습니다.

---

## 📋 Azure CSPM 거버넌스 체계 구축 로드맵

기술 도입에 그치지 않고, **조직 차원의 CSPM 거버넌스**를 구축하기 위한 단계별 로드맵을 제안합니다.

### Phase 1: 가시성 확보 (1~2주)
- [ ] Prowler 설치 및 전체 Azure 구독 초기 스캔 실행
- [ ] FAIL 항목 목록화 및 심각도별 분류
- [ ] 현재 보안 점수(Security Score) 기준선(Baseline) 설정

### Phase 2: Critical 이슈 즉시 조치 (2~4주)
- [ ] CRITICAL/HIGH FAIL 항목 전수 조치
- [ ] MFA 전사 강제화, 퍼블릭 스토리지 차단
- [ ] Microsoft Defender for Cloud 전면 활성화

### Phase 3: 자동화 및 지속 모니터링 (1~2개월)
- [ ] CI/CD 파이프라인에 Prowler 스캔 통합
- [ ] 주간 보안 현황 리포트 자동 발송 체계 구축
- [ ] Azure Policy를 통한 예방적 가드레일(Guardrail) 설정

### Phase 4: 컴플라이언스 정렬 (분기별)
- [ ] CIS Azure Benchmark 3.0 전 항목 점검 및 예외 관리
- [ ] ISO 27001, NIST, GDPR 등 해당 규제 프레임워크 매핑
- [ ] 연 1회 이상 외부 감사(External Audit) 대비 리포트 준비

---

## 💡 마무리: CSPM은 "한 번"이 아닌 "지속"이다

Azure 환경은 매일 변화합니다. 새로운 리소스가 만들어지고, 설정이 바뀌고, 새로운 취약점이 발견됩니다. 이런 동적인 환경에서 **CSPM은 관리·모니터링·개선의 지속적인 사이클**이어야 합니다.

Prowler는 그 사이클의 출발점이 될 수 있는 훌륭한 오픈소스 도구입니다. 초기 비용 없이 시작해 전체 Azure 환경의 보안 가시성을 확보하고, 점진적으로 자동화와 거버넌스 체계를 붙여나가는 것을 권장합니다.

> 보안은 완벽한 상태를 향해 달리는 마라톤이 아니라, 매일 조금씩 위험을 줄여나가는 꾸준한 실천입니다.

---

### 🔗 참고 자료

- [Prowler for Microsoft Azure](https://prowler.com/microsoft-azure)
- [Prowler 공식 문서](https://docs.prowler.com/)
- [CIS Microsoft Azure Foundations Benchmark](https://www.cisecurity.org/benchmark/azure)
- [Microsoft Defender for Cloud 공식 문서](https://learn.microsoft.com/azure/defender-for-cloud/)
- [Azure Security Benchmark](https://learn.microsoft.com/security/benchmark/azure/)
