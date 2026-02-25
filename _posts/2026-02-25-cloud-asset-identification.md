---
title: "ISMS/ISO 27001 기술영역 취약점 진단: Azure·AWS·GCP 자산 식별 완전 가이드"
date: 2026-02-25 07:00:00 +0900
categories: [Security, Cloud]
tags: [isms, iso27001, azure, aws, gcp, vulnerability-assessment, asset-inventory, cloud-security]
---

ISMS-P 및 ISO 27001 인증심사의 **기술영역 취약점 진단**에서 가장 먼저 해야 할 일은 **"진단 대상 자산 목록 확정"**입니다. 클라우드 환경은 자산이 수시로 생성·삭제되므로, 수동 목록 관리는 한계가 있습니다.

이 글에서는 **Azure · AWS · GCP** 각 클라우드에서 자산을 자동으로 식별하고, 취약점 진단 대상 목록을 구성하는 방법을 기술적으로 정리합니다.

---

## 1. 왜 자산 식별이 핵심인가

### 1.1. ISMS와 ISO 27001의 요구사항

| 기준 | 조항 | 요구 내용 |
| :--- | :--- | :--- |
| **ISMS-P** | 2.1.1 정보자산 식별 | 서비스·운영에 관련된 자산을 식별하고 목록 관리 |
| **ISMS-P** | 2.11.2 취약점 점검 | 정기적 취약점 점검 및 조치 |
| **ISO 27001:2022** | A.8.8 | 취약점을 주기적으로 식별하고 관리 |
| **ISO 27001:2022** | A.5.9 | 정보자산 인벤토리 유지 |

> 심사관은 **"어떤 자산을 어떻게 식별했는가"**를 먼저 묻습니다. 자산 목록이 없으면 진단 자체가 무효 처리될 수 있습니다.

### 1.2. 클라우드 자산 식별의 어려움

```
[문제점]
  ① 자산 수량이 많고 수시 변동 → 수동 관리 불가
  ② 멀티 구독/계정/프로젝트 분산 → 단일 조회 어려움
  ③ IaaS · PaaS · SaaS 혼합 → 진단 방식이 다름
  ④ 태그/레이블 미적용 시 분류 불가

[해결책]
  → 각 CSP의 네이티브 API/CLI로 자동화된 자산 수집
```

### 1.3. 자산 유형별 진단 접근 방식

| 자산 유형 | 예시 | 진단 방식 |
| :--- | :--- | :--- |
| **IaaS VM** | Azure VM, EC2, GCE | SSH/RDP + 에이전트 스크립트 |
| **PaaS DB** | Azure SQL, RDS, Cloud SQL | CLI/API 기반 설정 점검 |
| **컨테이너** | AKS, EKS, GKE | Trivy, kubectl 기반 |
| **네트워킹** | NSG, Security Group, VPC | 방화벽 규칙 수집 |
| **스토리지** | Blob, S3, GCS | 공개 접근 여부 점검 |
| **IAM** | Entra ID, IAM, Cloud IAM | 권한·MFA 설정 점검 |

---

## 2. Azure 자산 식별

### 2.1. 사전 준비

```bash
# Azure CLI 설치 확인
az version

# 로그인 (서비스 주체 사용 권장)
az login --service-principal \
  -u $APP_ID \
  -p $APP_SECRET \
  --tenant $TENANT_ID

# 접근 가능한 구독 목록 확인
az account list --query "[].{Name:name, ID:id, State:state}" -o table
```

#### 필요 권한
- `Reader` 역할 (구독 수준) — 읽기 전용으로도 전체 자산 조회 가능
- `Security Reader` — Microsoft Defender for Cloud 데이터 접근

### 2.2. Azure Resource Graph — 전체 자산 일괄 조회

Azure Resource Graph는 **모든 구독에 걸친 리소스를 KQL로 한 번에 조회**할 수 있는 가장 강력한 도구입니다.

```bash
#!/bin/bash
# azure_asset_inventory.sh - Azure 전체 자산 식별

OUTPUT_DIR="./azure_inventory_$(date '+%Y%m%d')"
mkdir -p "$OUTPUT_DIR"

echo "=== Azure 자산 식별 시작: $(date '+%Y-%m-%d %H:%M:%S') ==="

# ① 가상머신 (IaaS)
echo "[1/6] Virtual Machines 조회..."
az graph query -q "
  Resources
  | where type == 'microsoft.compute/virtualmachines'
  | project Name=name, ResourceGroup=resourceGroup,
            Location=location, OS=properties.storageProfile.osDisk.osType,
            Size=properties.hardwareProfile.vmSize,
            State=properties.extended.instanceView.powerState.displayStatus,
            SubscriptionId=subscriptionId
  | order by Name asc
" --first 1000 -o json > "$OUTPUT_DIR/vm_inventory.json"

az graph query -q "
  Resources
  | where type == 'microsoft.compute/virtualmachines'
  | summarize Count=count() by Location
" --first 100 -o table

# ② PaaS 데이터베이스
echo "[2/6] PaaS Database 조회..."
az graph query -q "
  Resources
  | where type in ('microsoft.dbforpostgresql/flexibleservers',
                   'microsoft.dbformysql/flexibleservers',
                   'microsoft.cache/redis',
                   'microsoft.sql/servers/databases')
  | project Name=name, Type=type, ResourceGroup=resourceGroup,
            Location=location, SubscriptionId=subscriptionId
" --first 1000 -o json > "$OUTPUT_DIR/paas_db_inventory.json"

# ③ 컨테이너 (AKS)
echo "[3/6] AKS Clusters 조회..."
az graph query -q "
  Resources
  | where type == 'microsoft.containerservice/managedclusters'
  | project Name=name, ResourceGroup=resourceGroup,
            Location=location, K8sVersion=properties.kubernetesVersion,
            NodeCount=properties.agentPoolProfiles[0].count,
            SubscriptionId=subscriptionId
" --first 1000 -o json > "$OUTPUT_DIR/aks_inventory.json"

# ④ 스토리지
echo "[4/6] Storage Accounts 조회..."
az graph query -q "
  Resources
  | where type == 'microsoft.storage/storageaccounts'
  | project Name=name, ResourceGroup=resourceGroup,
            Location=location,
            PublicAccess=properties.allowBlobPublicAccess,
            HttpsOnly=properties.supportsHttpsTrafficOnly,
            SubscriptionId=subscriptionId
" --first 1000 -o json > "$OUTPUT_DIR/storage_inventory.json"

# ⑤ 네트워크 보안 그룹
echo "[5/6] Network Security Groups 조회..."
az graph query -q "
  Resources
  | where type == 'microsoft.network/networksecuritygroups'
  | project Name=name, ResourceGroup=resourceGroup,
            Location=location, SubscriptionId=subscriptionId
" --first 1000 -o json > "$OUTPUT_DIR/nsg_inventory.json"

# ⑥ 전체 자산 요약
echo "[6/6] 전체 자산 유형별 통계..."
az graph query -q "
  Resources
  | summarize Count=count() by type
  | order by Count desc
" --first 100 -o table | tee "$OUTPUT_DIR/asset_summary.txt"

VM_COUNT=$(cat "$OUTPUT_DIR/vm_inventory.json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('count',0))" 2>/dev/null || echo "N/A")
echo ""
echo "=== Azure 자산 식별 완료 ==="
echo "  • VM: ${VM_COUNT}대"
echo "  • 결과 저장: $OUTPUT_DIR/"
```

### 2.3. 구독 전체 순회 스크립트

여러 구독에 걸쳐 자산을 수집할 때 사용합니다.

```bash
#!/bin/bash
# azure_multi_subscription_inventory.sh

OUTPUT_DIR="./azure_all_subs_$(date '+%Y%m%d')"
mkdir -p "$OUTPUT_DIR"

# 모든 구독 순회
az account list --query "[?state=='Enabled'].{id:id, name:name}" -o tsv | \
while IFS=$'\t' read -r SUB_ID SUB_NAME; do
  echo "━━━ 구독: $SUB_NAME ($SUB_ID) ━━━"
  az account set --subscription "$SUB_ID"

  # VM 목록
  az vm list \
    --query "[].{Name:name, RG:resourceGroup, Location:location, OS:storageProfile.osDisk.osType}" \
    -o json > "$OUTPUT_DIR/vm_${SUB_ID}.json"

  # 실행 중인 VM만 필터링
  az vm list \
    --show-details \
    --query "[?powerState=='VM running'].{Name:name, RG:resourceGroup, IP:publicIps, PrivateIP:privateIps}" \
    -o table | tee -a "$OUTPUT_DIR/vm_running_${SUB_ID}.txt"
done

echo "=== 멀티 구독 자산 수집 완료 ==="
```

### 2.4. Microsoft Defender for Cloud 활용

Defender for Cloud는 **자산 목록 + 보안 상태 점수**를 함께 제공합니다.

```bash
# 보안 상태가 낮은 리소스 조회 (취약점 진단 우선순위 도출)
az security assessment list \
  --query "[?status.code=='Unhealthy'].{Resource:resourceDetails.id, Issue:displayName, Severity:metadata.severity}" \
  -o table

# 전체 보안 점수 조회
az security secure-score-controls list \
  --query "[].{Control:displayName, Score:score.current, Max:score.max, Unhealthy:unhealthyResourceCount}" \
  -o table
```

---

## 3. AWS 자산 식별

### 3.1. 사전 준비

```bash
# AWS CLI 설치 확인
aws --version

# 자격 증명 설정 (읽기 전용 IAM Role 사용 권장)
aws configure
# 또는 환경 변수
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_DEFAULT_REGION="ap-northeast-2"  # 서울 리전

# 연결 확인
aws sts get-caller-identity
```

#### 필요 권한 (IAM Policy)
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "ec2:Describe*",
      "rds:Describe*",
      "s3:GetBucket*",
      "s3:ListAllMyBuckets",
      "eks:List*",
      "eks:Describe*",
      "iam:List*",
      "iam:Get*",
      "elasticache:Describe*",
      "config:List*",
      "config:Describe*",
      "securityhub:Get*"
    ],
    "Resource": "*"
  }]
}
```

### 3.2. AWS Config — 전체 자산 인벤토리

AWS Config는 **계정 내 모든 리소스를 지속적으로 기록**하는 서비스입니다.

```bash
#!/bin/bash
# aws_asset_inventory.sh - AWS 전체 자산 식별

OUTPUT_DIR="./aws_inventory_$(date '+%Y%m%d')"
mkdir -p "$OUTPUT_DIR"
REGION="${AWS_DEFAULT_REGION:-ap-northeast-2}"

echo "=== AWS 자산 식별 시작: $(date '+%Y-%m-%d %H:%M:%S') ==="
echo "리전: $REGION"

# ① EC2 인스턴스 (IaaS VM)
echo "[1/7] EC2 Instances 조회..."
aws ec2 describe-instances \
  --region "$REGION" \
  --query "Reservations[].Instances[].{
    InstanceId:InstanceId,
    Name:Tags[?Key=='Name']|[0].Value,
    State:State.Name,
    Type:InstanceType,
    OS:Platform,
    PrivateIP:PrivateIpAddress,
    PublicIP:PublicIpAddress,
    VPC:VpcId,
    Subnet:SubnetId,
    KeyName:KeyName,
    LaunchTime:LaunchTime
  }" \
  -o json > "$OUTPUT_DIR/ec2_inventory.json"

EC2_COUNT=$(aws ec2 describe-instances --region "$REGION" \
  --query "length(Reservations[].Instances[])" --output text)
echo "  → EC2: ${EC2_COUNT}대"

# 실행 중인 EC2만 추출
aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].{
    Name:Tags[?Key=='Name']|[0].Value,
    ID:InstanceId,
    Type:InstanceType,
    PrivateIP:PrivateIpAddress,
    PublicIP:PublicIpAddress
  }" \
  -o table | tee "$OUTPUT_DIR/ec2_running.txt"

# ② RDS (PaaS DB)
echo "[2/7] RDS Instances 조회..."
aws rds describe-db-instances \
  --region "$REGION" \
  --query "DBInstances[].{
    Identifier:DBInstanceIdentifier,
    Engine:Engine,
    EngineVersion:EngineVersion,
    Class:DBInstanceClass,
    Status:DBInstanceStatus,
    MultiAZ:MultiAZ,
    PublicAccess:PubliclyAccessible,
    Encrypted:StorageEncrypted,
    BackupRetention:BackupRetentionPeriod,
    Endpoint:Endpoint.Address
  }" \
  -o json > "$OUTPUT_DIR/rds_inventory.json"

aws rds describe-db-instances \
  --region "$REGION" \
  --query "DBInstances[].{ID:DBInstanceIdentifier, Engine:Engine, Public:PubliclyAccessible, Encrypted:StorageEncrypted}" \
  -o table | tee "$OUTPUT_DIR/rds_summary.txt"

# ③ S3 버킷
echo "[3/7] S3 Buckets 조회..."
aws s3api list-buckets \
  --query "Buckets[].{Name:Name, Created:CreationDate}" \
  -o json > "$OUTPUT_DIR/s3_inventory.json"

# 버킷별 공개 접근 설정 확인
while IFS= read -r BUCKET; do
  PUBLIC=$(aws s3api get-public-access-block --bucket "$BUCKET" \
    --query "PublicAccessBlockConfiguration.BlockPublicAcls" \
    --output text 2>/dev/null || echo "N/A")
  echo "$BUCKET,$PUBLIC"
done < <(aws s3api list-buckets --query "Buckets[].Name" --output text | tr '\t' '\n') \
  | tee "$OUTPUT_DIR/s3_public_access.csv"

# ④ EKS 클러스터
echo "[4/7] EKS Clusters 조회..."
aws eks list-clusters --region "$REGION" \
  --query "clusters" -o json > "$OUTPUT_DIR/eks_clusters.json"

EKS_CLUSTERS=$(aws eks list-clusters --region "$REGION" --query "clusters[]" --output text)
for CLUSTER in $EKS_CLUSTERS; do
  aws eks describe-cluster --region "$REGION" --name "$CLUSTER" \
    --query "cluster.{Name:name, Version:version, Status:status, K8sVersion:version, Endpoint:endpoint}" \
    -o json >> "$OUTPUT_DIR/eks_details.json"
done

# ⑤ ElastiCache
echo "[5/7] ElastiCache 조회..."
aws elasticache describe-cache-clusters \
  --region "$REGION" \
  --query "CacheClusters[].{
    ID:CacheClusterId,
    Engine:Engine,
    EngineVersion:EngineVersionId,
    Status:CacheClusterStatus,
    NodeType:CacheNodeType,
    AuthEnabled:AuthTokenEnabled,
    TransitEncryption:TransitEncryptionEnabled,
    AtRestEncryption:AtRestEncryptionEnabled
  }" \
  -o json > "$OUTPUT_DIR/elasticache_inventory.json"

# ⑥ Security Groups — 과도한 허용 규칙 사전 확인
echo "[6/7] Security Groups (0.0.0.0/0 인바운드 허용) 조회..."
aws ec2 describe-security-groups \
  --region "$REGION" \
  --filters "Name=ip-permission.cidr,Values=0.0.0.0/0" \
  --query "SecurityGroups[].{
    ID:GroupId,
    Name:GroupName,
    VPC:VpcId,
    Description:Description
  }" \
  -o table | tee "$OUTPUT_DIR/sg_open_inbound.txt"

# ⑦ IAM Users/Roles
echo "[7/7] IAM Users 조회..."
aws iam list-users \
  --query "Users[].{User:UserName, Created:CreateDate, PasswordLastUsed:PasswordLastUsed}" \
  -o json > "$OUTPUT_DIR/iam_users.json"

echo ""
echo "=== AWS 자산 식별 완료 ==="
echo "결과 저장: $OUTPUT_DIR/"
```

### 3.3. AWS Config 고급 쿼리 (멀티 리전·멀티 계정)

```bash
#!/bin/bash
# aws_config_advanced_query.sh

# AWS Config Advanced Query로 전체 리소스 조회
# (Config Aggregator 설정이 필요)

AGGREGATOR_NAME="SecurityAuditAggregator"

# 전체 EC2 인스턴스 (모든 계정·리전)
aws configservice select-aggregate-resource-config \
  --configuration-aggregator-name "$AGGREGATOR_NAME" \
  --expression "
    SELECT resourceId, resourceName, resourceType, awsRegion, accountId,
           configuration.instanceType,
           configuration.state.name,
           configuration.privateIpAddress,
           configuration.publicIpAddress
    WHERE resourceType = 'AWS::EC2::Instance'
    AND configuration.state.name = 'running'
  " \
  --output json | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = data.get('Results', [])
for r in results:
    obj = json.loads(r)
    print(f\"{obj.get('accountId')},{obj.get('awsRegion')},{obj.get('resourceName')},{obj.get('configuration',{}).get('instanceType')},{obj.get('configuration',{}).get('state',{}).get('name')}\")
" > aws_all_ec2.csv

echo "전체 계정 EC2 목록: aws_all_ec2.csv"

# 공개 접근 가능한 RDS 식별
aws configservice select-aggregate-resource-config \
  --configuration-aggregator-name "$AGGREGATOR_NAME" \
  --expression "
    SELECT resourceId, resourceName, awsRegion, accountId,
           configuration.dBInstanceClass,
           configuration.engine,
           configuration.publiclyAccessible,
           configuration.storageEncrypted
    WHERE resourceType = 'AWS::RDS::DBInstance'
    AND configuration.publiclyAccessible = true
  " \
  --output json
```

### 3.4. AWS Security Hub 활용

```bash
# Security Hub에서 보안 발견사항 기반 자산 목록 생성
aws securityhub get-findings \
  --region "$REGION" \
  --filters '{
    "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}],
    "WorkflowStatus": [{"Value": "NEW", "Comparison": "EQUALS"}],
    "SeverityLabel": [
      {"Value": "CRITICAL", "Comparison": "EQUALS"},
      {"Value": "HIGH", "Comparison": "EQUALS"}
    ]
  }' \
  --query "Findings[].{
    Resource:Resources[0].Id,
    Type:Resources[0].Type,
    Title:Title,
    Severity:Severity.Label
  }" \
  -o table
```

---

## 4. GCP 자산 식별

### 4.1. 사전 준비

```bash
# gcloud CLI 설치 확인
gcloud version

# 서비스 계정으로 인증 (권장)
gcloud auth activate-service-account \
  --key-file="/path/to/service-account-key.json"

# 또는 사용자 계정으로 인증
gcloud auth login

# 프로젝트 목록 확인
gcloud projects list

# 기본 프로젝트 설정
gcloud config set project YOUR_PROJECT_ID
```

#### 필요 IAM 역할
- `roles/viewer` — 기본 읽기 권한
- `roles/cloudasset.viewer` — Cloud Asset Inventory 접근
- `roles/securitycenter.findingsViewer` — Security Command Center 접근

### 4.2. Cloud Asset Inventory — 전체 자산 수집

GCP의 Cloud Asset Inventory는 **조직·폴더·프로젝트 전체의 자산을 일괄 조회**하는 핵심 도구입니다.

```bash
#!/bin/bash
# gcp_asset_inventory.sh - GCP 전체 자산 식별

OUTPUT_DIR="./gcp_inventory_$(date '+%Y%m%d')"
mkdir -p "$OUTPUT_DIR"

# 조직 ID 또는 프로젝트 ID 설정
ORG_ID="your-org-id"          # 조직 수준 조회 시
PROJECT_ID="your-project-id"  # 프로젝트 수준 조회 시

echo "=== GCP 자산 식별 시작: $(date '+%Y-%m-%d %H:%M:%S') ==="

# ① Compute Engine VM 인스턴스
echo "[1/6] Compute Engine Instances 조회..."
gcloud asset search-all-resources \
  --scope="organizations/$ORG_ID" \
  --asset-types="compute.googleapis.com/Instance" \
  --format="json" > "$OUTPUT_DIR/gce_inventory.json"

# 프로젝트별 VM 목록 (gcloud 직접 조회)
gcloud compute instances list \
  --format="table(name, zone, machineType, status, networkInterfaces[0].accessConfigs[0].natIP, networkInterfaces[0].networkIP)" \
  | tee "$OUTPUT_DIR/gce_instances.txt"

GCE_COUNT=$(gcloud compute instances list --format="value(name)" | wc -l | tr -d ' ')
echo "  → GCE VM: ${GCE_COUNT}대"

# ② Cloud SQL (PaaS DB)
echo "[2/6] Cloud SQL Instances 조회..."
gcloud sql instances list \
  --format="json" > "$OUTPUT_DIR/cloudsql_inventory.json"

gcloud sql instances list \
  --format="table(name, database_version, region, state, settings.tier, settings.ipConfiguration.requireSsl, settings.backupConfiguration.enabled)" \
  | tee "$OUTPUT_DIR/cloudsql_summary.txt"

# ③ GKE 클러스터
echo "[3/6] GKE Clusters 조회..."
gcloud container clusters list \
  --format="json" > "$OUTPUT_DIR/gke_inventory.json"

gcloud container clusters list \
  --format="table(name, location, currentMasterVersion, status, currentNodeCount)" \
  | tee "$OUTPUT_DIR/gke_summary.txt"

# ④ Cloud Storage 버킷
echo "[4/6] Cloud Storage Buckets 조회..."
gcloud storage buckets list \
  --format="json" > "$OUTPUT_DIR/gcs_inventory.json"

# 공개 버킷 확인
gcloud storage buckets list \
  --format="value(name)" | while read -r BUCKET; do
  ACCESS=$(gcloud storage buckets describe "gs://$BUCKET" \
    --format="value(iamConfiguration.publicAccessPrevention)" 2>/dev/null)
  echo "$BUCKET,$ACCESS"
done | tee "$OUTPUT_DIR/gcs_public_access.csv"

# ⑤ Memorystore (Redis)
echo "[5/6] Memorystore Redis 조회..."
gcloud redis instances list \
  --regions=asia-northeast3 \
  --format="table(name, region, memorySizeGb, state, redisVersion, authEnabled, transitEncryptionMode)" \
  | tee "$OUTPUT_DIR/redis_inventory.txt"

# ⑥ Cloud Asset Inventory — 전체 자산 유형 요약
echo "[6/6] 전체 자산 유형별 통계..."
gcloud asset search-all-resources \
  --scope="organizations/$ORG_ID" \
  --format="value(assetType)" \
  | sort | uniq -c | sort -rn \
  | tee "$OUTPUT_DIR/asset_type_summary.txt"

echo ""
echo "=== GCP 자산 식별 완료 ==="
echo "결과 저장: $OUTPUT_DIR/"
```

### 4.3. 조직 전체 자산 일괄 내보내기 (BigQuery 연동)

대규모 조직에서는 BigQuery로 내보내 SQL로 분석하는 방법이 효율적입니다.

```bash
# Cloud Asset Inventory를 BigQuery로 내보내기
gcloud asset export \
  --organization="$ORG_ID" \
  --bigquery-table="projects/$PROJECT_ID/datasets/asset_inventory/tables/snapshot" \
  --asset-types="compute.googleapis.com/Instance,sqladmin.googleapis.com/Instance,container.googleapis.com/Cluster" \
  --output-bigquery-force

# BigQuery에서 분석 (bq 커맨드 또는 콘솔)
bq query --use_legacy_sql=false "
  SELECT
    asset_type,
    name,
    location,
    project
  FROM \`$PROJECT_ID.asset_inventory.snapshot\`
  WHERE asset_type = 'compute.googleapis.com/Instance'
  ORDER BY project, name
"
```

### 4.4. Security Command Center 활용

```bash
# Security Command Center에서 취약점 발견사항 기반 자산 조회
gcloud scc findings list "organizations/$ORG_ID" \
  --filter="state='ACTIVE' AND severity='CRITICAL' OR severity='HIGH'" \
  --format="table(finding.resourceName, finding.category, finding.severity, finding.createTime)" \
  | head -50

# 공개 노출된 VM 발견사항
gcloud scc findings list "organizations/$ORG_ID" \
  --filter="category='PUBLIC_IP_ADDRESS' AND state='ACTIVE'" \
  --format="table(finding.resourceName, finding.category)"
```

---

## 5. 멀티 클라우드 통합 자산 목록 생성

### 5.1. 통합 실행 스크립트

```bash
#!/bin/bash
# multicloud_asset_inventory.sh - Azure/AWS/GCP 통합 자산 식별

AUDIT_DATE=$(date '+%Y%m%d')
OUTPUT_DIR="./multicloud_inventory_${AUDIT_DATE}"
FINAL_CSV="$OUTPUT_DIR/all_assets.csv"

mkdir -p "$OUTPUT_DIR"

echo "CSP,자산유형,자산명,위치,상태,구독/계정/프로젝트,비고" > "$FINAL_CSV"

echo "╔══════════════════════════════════════════════════╗"
echo "║   멀티클라우드 자산 식별 도구                       ║"
echo "║   대상: Azure / AWS / GCP                        ║"
echo "║   기준: ISMS-P / ISO 27001                       ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# === Azure ===
echo "━━━ [1/3] Azure 자산 수집 ━━━"
if az account show > /dev/null 2>&1; then
  AZURE_SUB=$(az account show --query "name" -o tsv)

  az vm list --show-details \
    --query "[].{name:name, rg:resourceGroup, location:location, state:powerState}" \
    -o tsv 2>/dev/null | while IFS=$'\t' read -r NAME RG LOC STATE; do
    echo "Azure,VM,$NAME,$LOC,$STATE,$AZURE_SUB,$RG" >> "$FINAL_CSV"
  done

  AZ_VM=$(az vm list --query "length([])" -o tsv 2>/dev/null || echo 0)
  echo "  ✅ Azure VM: ${AZ_VM}대"
else
  echo "  ⚠️ Azure: 로그인 필요 (az login)"
fi

# === AWS ===
echo ""
echo "━━━ [2/3] AWS 자산 수집 ━━━"
if aws sts get-caller-identity > /dev/null 2>&1; then
  AWS_ACCOUNT=$(aws sts get-caller-identity --query "Account" --output text)
  REGION="${AWS_DEFAULT_REGION:-ap-northeast-2}"

  aws ec2 describe-instances --region "$REGION" \
    --query "Reservations[].Instances[].{name:Tags[?Key=='Name']|[0].Value, id:InstanceId, loc:Placement.AvailabilityZone, state:State.Name}" \
    -o text 2>/dev/null | while read -r NAME ID LOC STATE; do
    echo "AWS,EC2,${NAME:-$ID},$LOC,$STATE,$AWS_ACCOUNT,$REGION" >> "$FINAL_CSV"
  done

  AWS_EC2=$(aws ec2 describe-instances --region "$REGION" \
    --query "length(Reservations[].Instances[])" --output text 2>/dev/null || echo 0)
  echo "  ✅ AWS EC2: ${AWS_EC2}대"
else
  echo "  ⚠️ AWS: 자격증명 필요 (aws configure)"
fi

# === GCP ===
echo ""
echo "━━━ [3/3] GCP 자산 수집 ━━━"
if gcloud auth list --filter="status:ACTIVE" --format="value(account)" 2>/dev/null | grep -q "@"; then
  GCP_PROJECT=$(gcloud config get-value project 2>/dev/null)

  gcloud compute instances list \
    --format="value(name,zone,status)" 2>/dev/null | while read -r NAME ZONE STATUS; do
    echo "GCP,GCE,$NAME,$ZONE,$STATUS,$GCP_PROJECT,-" >> "$FINAL_CSV"
  done

  GCP_GCE=$(gcloud compute instances list --format="value(name)" 2>/dev/null | wc -l | tr -d ' ')
  echo "  ✅ GCP GCE: ${GCP_GCE}대"
else
  echo "  ⚠️ GCP: 로그인 필요 (gcloud auth login)"
fi

# === 결과 요약 ===
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║                  자산 식별 결과                    ║"
echo "╚══════════════════════════════════════════════════╝"
TOTAL=$(tail -n +2 "$FINAL_CSV" | wc -l | tr -d ' ')
echo "  📊 총 자산 수: ${TOTAL}대"
echo "  📁 통합 목록: $FINAL_CSV"
echo "  🕐 완료: $(date '+%Y-%m-%d %H:%M:%S')"
```

### 5.2. 진단 대상 분류 기준

수집된 자산을 진단 대상으로 분류하는 기준입니다.

| 분류 | 기준 | 진단 방식 |
| :--- | :--- | :--- |
| **필수 진단** | 운영 중(Running), 인터넷 노출 | 즉시 진단 |
| **우선 진단** | 운영 중, Private 환경 | 정기 진단 |
| **선택 진단** | 중지 상태, 개발/테스트 | 샘플 진단 |
| **진단 제외** | 폐기 예정, CSP 관리 영역 | 제외 근거 문서화 |

---

## 6. 자산 목록 → Jira/스프레드시트 연동

### 6.1. CSV를 Jira Assets 형식으로 변환

```python
#!/usr/bin/env python3
# convert_to_jira_assets.py - 자산 목록을 Jira Assets JSON으로 변환

import csv
import json
from datetime import datetime

def convert_csv_to_jira_assets(csv_file, output_file):
    assets = []
    with open(csv_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            asset = {
                "CSP": row.get("CSP", ""),
                "AssetType": row.get("자산유형", ""),
                "Name": row.get("자산명", ""),
                "Location": row.get("위치", ""),
                "Status": row.get("상태", ""),
                "Account": row.get("구독/계정/프로젝트", ""),
                "DiagnosisTarget": "Y" if row.get("상태", "").lower() in ["running", "vm running", "runnable"] else "N",
                "LastUpdated": datetime.now().strftime("%Y-%m-%d")
            }
            assets.append(asset)

    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(assets, f, ensure_ascii=False, indent=2)

    print(f"변환 완료: {len(assets)}건 → {output_file}")

if __name__ == "__main__":
    convert_csv_to_jira_assets("all_assets.csv", "jira_assets_import.json")
```

---

## 7. ISMS/ISO 27001 자산 목록 증적 체크리스트

심사 대응을 위해 준비해야 할 자산 식별 관련 증적입니다.

| # | 증적 자료 | 수집 방법 | ISMS 매핑 |
| :--- | :--- | :--- | :--- |
| 1 | **클라우드별 자산 전체 목록** (CSV/JSON) | 위 스크립트 실행 결과 | 2.1.1 |
| 2 | **자산 분류 기준** (문서) | 내부 자산 분류 정책 | 2.1.1 |
| 3 | **진단 대상 선정 근거** | 분류 기준 적용 결과 | 2.11.2 |
| 4 | **진단 제외 자산 목록 및 사유** | 제외 기준 문서화 | 2.11.2 |
| 5 | **자산 목록 생성 일시** (스크립트 실행 로그) | 타임스탬프 포함 결과 | 2.1.1 |

### 심사관이 자주 묻는 질문

> **Q: 클라우드 자산은 어떻게 관리하나요? 수동으로 업데이트하나요?**
>
> A: 각 CSP의 네이티브 API(Azure Resource Graph, AWS Config, GCP Cloud Asset Inventory)를 활용한 **자동화 스크립트를 주기적으로 실행**하여 자산 목록을 갱신합니다. 실행 결과는 Jira Assets 또는 CMDB에 연동하여 관리합니다.

> **Q: 진단 대상에서 제외된 자산은 어떻게 처리하나요?**
>
> A: 중지 상태의 자산, CSP가 책임지는 PaaS 인프라 영역 등은 **제외 사유를 문서화**하고 책임자 승인을 받아 관리합니다. 제외 자산은 분기별로 재검토합니다.

---

> **참고**: 이 가이드는 각 CSP의 최소 읽기 권한(Reader/Viewer)으로 실행 가능하며, 운영 환경에 영향을 주지 않습니다. 스크립트 실행 전 반드시 테스트 계정에서 검증하시기 바랍니다.
{: .prompt-tip }

> **관련 포스트**: [Azure PaaS DB 취약점 진단 체크리스트](/posts/securitycheck-DBMS-PaaS/)
{: .prompt-info }
