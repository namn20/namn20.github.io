---
title: "Prowler로 클라우드 보안 감시하기: AWS/Azure 멀티클라우드 거버넌스"
date: 2026-04-22 10:00:00 +0900
categories: [Security, Cloud Security]
tags: [prowler, aws, azure, gcp, cloud-security, compliance, cis-benchmark]
---

클라우드 환경의 보안을 책임지는 DevSecOps/보안팀이라면 한 번쯤 마주치는 질문이 있습니다.

> "AWS, Azure, GCP를 모두 운영하고 있는데, 각각의 보안 설정을 일일이 점검해야 하나요?"

정답은 **아니오**입니다. **Prowler**는 AWS, Azure, GCP 환경의 보안 정책(Compliance), CIS 벤치마크(CIS Benchmark), 모범 사례(Best Practices) 준수를 자동으로 감시하는 오픈소스 도구입니다.

이 글에서는 Prowler의 설치부터 셀프호스팅, Azure 통합까지 실전 가이드를 제공합니다.

---

## 1. Prowler란? 소개 및 특징

### 1.1. Prowler의 역할

| 구분 | 설명 |
| :--- | :--- |
| **정의** | AWS, Azure, GCP의 클라우드 리소스 보안 감시 및 컴플라이언스 검증 도구 |
| **주요 기능** | 500+ 보안 체크, CIS Benchmark, PCI-DSS, HIPAA, SOC2 등 규정 준수 검증 |
| **사용 주체** | 클라우드 보안팀, DevSecOps, 컴플라이언스 담당자 |
| **라이센스** | 오픈소스 (Apache 2.0) |
| **언어** | Python |

### 1.2. Prowler vs 기타 클라우드 보안 도구

| 특징 | Prowler | CloudTrail | AWS Config | Azure Policy |
| :--- | :--- | :--- | :--- | :--- |
| **멀티클라우드** | ✅ (AWS/Azure/GCP) | AWS만 | AWS만 | Azure만 |
| **오픈소스** | ✅ | ❌ | ❌ | ❌ |
| **500+ 체크** | ✅ | ❌ | ❌ | ❌ |
| **자동화 용이** | ✅ | ❌ | ❌ | ❌ |
| **대시보드** | ✅ (유료: Prowler SaaS) | ✅ | ✅ | ✅ |

### 1.3. 사용 시나리오

**Prowler가 가장 유용한 상황:**

1. **ISMS / SOC2 인증 대비**: 규정 준수 상태를 정기적으로 검증하고 증적 자료를 생성합니다.
2. **멀티클라우드 거버넌스**: 여러 클라우드(AWS + Azure + GCP)를 운영하는 조직에서 **통일된 기준**으로 점검합니다.
3. **지속적인 모니터링**: 배포 후 발생하는 설정 변화(Configuration Drift)를 감지합니다.
4. **자동 보고서 생성**: JSON/HTML 형식의 보고서를 자동으로 생성하여 경영진 보고에 활용합니다.

---

## 2. Prowler 설치 및 빠른 시작

### 2.1. 전제 조건

```bash
# 필수 요구사항
- Python 3.9+
- AWS CLI v2 또는 Azure CLI
- 적절한 IAM 권한 (AWS) / 역할 (Azure)
```

### 2.2. 설치 방법 (로컬)

#### 방법 A: pip를 이용한 설치 (권장)

```bash
# 1. pip 업그레이드
pip install --upgrade pip

# 2. Prowler 설치
pip install prowler-cloud

# 3. 설치 확인
prowler --version
```

#### 방법 B: Docker를 이용한 설치

```bash
# Prowler Docker 이미지 다운로드
docker pull public.ecr.aws/prowler/prowler:latest

# Docker로 AWS 스캔 (로컬 credentials 마운트)
docker run -v ~/.aws:/root/.aws \
  public.ecr.aws/prowler/prowler:latest \
  --provider aws --region us-east-1
```

#### 방법 C: Git 저장소에서 설치

```bash
git clone https://github.com/prowler-cloud/prowler.git
cd prowler
pip install -r requirements.txt
python prowler.py --version
```

### 2.3. AWS 권한 설정

Prowler가 정상적으로 작동하려면 **ReadOnly** 수준의 IAM 권한이 필요합니다.

#### Option 1: 기존 `ReadOnlyAccess` 정책 사용 (간단)

```bash
# AWS CLI로 현재 계정에 대해 바로 실행 (로컬 credentials 필요)
prowler --provider aws --region us-east-1
```

#### Option 2: 전용 IAM 역할 생성 (권장)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "s3:Get*",
        "s3:List*",
        "iam:Get*",
        "iam:List*",
        "rds:Describe*",
        "logs:Describe*",
        "cloudtrail:GetTrail*",
        "cloudtrail:LookupEvents"
      ],
      "Resource": "*"
    }
  ]
}
```

**IAM 역할 생성 명령:**
```bash
# AWS CLI로 역할 생성
aws iam create-role --role-name ProwlerRole \
  --assume-role-policy-document file://trust-policy.json

# 권한 정책 첨부
aws iam attach-role-policy --role-name ProwlerRole \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess
```

### 2.4. 첫 스캔 실행

```bash
# AWS 스캔 (기본)
prowler --provider aws

# 특정 리전만 스캔
prowler --provider aws --region us-east-1,eu-west-1

# CIS Benchmark 검증만 수행
prowler --provider aws --compliance cis_aws_foundations_benchmark_v1_5_0

# 결과를 JSON 형식으로 저장
prowler --provider aws --output json --output-directory ./reports
```

**실행 결과:**
```
Prowler v3.13.0 starting scan...
[INFO] Running scan for AWS Account: 123456789012
[INFO] Executing 256 checks...
[INFO] Check completed in 4m 32s

Results:
- PASSED: 145 checks
- FAILED: 89 checks
- SKIPPED: 22 checks
```

---

## 3. 셀프호스팅: Kubernetes에서 Prowler 운영하기

로컬 머신에서 수동으로 Prowler를 실행하는 것도 가능하지만, **지속적인 모니터링**을 위해서는 Kubernetes 환경에서의 자동화가 필수입니다.

### 3.1. 셀프호스팅의 장점

| 운영 방식 | 로컬 실행 | 셀프호스팅 (K8s) | SaaS (Prowler Pro) |
| :--- | :--- | :--- | :--- |
| **설정 비용** | 낮음 | 중간 | 낮음 |
| **클라우드 비용** | 낮음 | 중간 | 높음 |
| **자동화** | ❌ | ✅ | ✅ |
| **대시보드** | ❌ | ❌ | ✅ |
| **데이터 프라이버시** | ✅ | ✅ | ❌ (외부) |

### 3.2. AKS에서 Prowler Operator 구성

#### 방법 A: Helm 차트로 설치 (가장 간단)

Aqua Security는 Prowler를 위한 공식 Helm 차트를 제공합니다.

```bash
# Helm 리포지토리 추가
helm repo add prowler https://github.com/prowler-cloud/prowler
helm repo update

# Prowler Operator 설치
helm install prowler prowler/prowler \
  --namespace prowler \
  --create-namespace \
  --set provider=aws \
  --set schedule="0 2 * * *"  # 매일 새벽 2시 실행
```

#### 방법 B: CronJob으로 스케줄링 (더 유연함)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prowler-sa
  namespace: prowler
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prowler-role
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prowler-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prowler-role
subjects:
- kind: ServiceAccount
  name: prowler-sa
  namespace: prowler
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: prowler-scan
  namespace: prowler
spec:
  schedule: "0 2 * * *"  # 매일 새벽 2시
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: prowler-sa
          containers:
          - name: prowler
            image: public.ecr.aws/prowler/prowler:latest
            args:
            - "--provider"
            - "aws"
            - "--output"
            - "json"
            - "--output-directory"
            - "/mnt/reports"
            volumeMounts:
            - name: aws-credentials
              mountPath: /root/.aws
              readOnly: true
            - name: reports
              mountPath: /mnt/reports
            env:
            - name: AWS_ROLE_ARN
              value: "arn:aws:iam::ACCOUNT_ID:role/ProwlerRole"
            - name: AWS_WEB_IDENTITY_TOKEN_FILE
              value: "/var/run/secrets/eks.amazonaws.com/serviceaccount/token"
          volumes:
          - name: aws-credentials
            secret:
              secretName: aws-credentials
          - name: reports
            persistentVolumeClaim:
              claimName: prowler-reports-pvc
          restartPolicy: OnFailure
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prowler-reports-pvc
  namespace: prowler
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: default
  resources:
    requests:
      storage: 10Gi
```

**배포:**
```bash
kubectl apply -f prowler-cronjob.yaml

# 수동 테스트
kubectl create job --from=cronjob/prowler-scan prowler-test-$(date +%s) -n prowler

# 로그 확인
kubectl logs -n prowler -l app=prowler-test -f
```

### 3.3. AWS에서 Workload Identity 설정 (EKS)

AWS EKS에서 Prowler가 클라우드 리소스에 접근하려면 **IAM 역할**과 **ServiceAccount** 매핑이 필요합니다.

```bash
# 1. IAM 역할 생성
CLUSTER_NAME="my-cluster"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
OIDC_ID=$(aws eks describe-cluster --name $CLUSTER_NAME --region us-east-1 \
  --query 'cluster.identity.oidc.issuer' --output text | cut -d '/' -f 5)

# Trust policy 생성
cat > trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/$OIDC_ID"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.us-east-1.amazonaws.com/id/$OIDC_ID:sub": "system:serviceaccount:prowler:prowler-sa"
        }
      }
    }
  ]
}
EOF

# IAM 역할 생성
aws iam create-role --role-name EKS-Prowler-Role \
  --assume-role-policy-document file://trust-policy.json

# ReadOnly 권한 첨부
aws iam attach-role-policy --role-name EKS-Prowler-Role \
  --policy-arn arn:aws:iam::aws:policy/ReadOnlyAccess

# 2. ServiceAccount에 역할 연결
kubectl annotate serviceaccount prowler-sa \
  -n prowler \
  eks.amazonaws.com/role-arn=arn:aws:iam::$ACCOUNT_ID:role/EKS-Prowler-Role \
  --overwrite
```

### 3.4. 결과 저장소 설정 (S3)

Prowler 스캔 결과를 S3에 저장하면, 오래된 스캔 데이터도 보관할 수 있고, 나중에 데이터 분석에 활용할 수 있습니다.

```bash
# S3 버킷 생성
aws s3 mb s3://prowler-reports-$(date +%s)

# Prowler 실행 시 결과를 S3로 업로드
prowler --provider aws \
  --output json \
  --output-directory /tmp/prowler-results

# 결과를 S3로 복사
aws s3 cp /tmp/prowler-results s3://prowler-reports/ --recursive
```

**CronJob에서 S3 저장:**
```yaml
containers:
- name: prowler
  image: public.ecr.aws/prowler/prowler:latest
  args:
  - "--provider"
  - "aws"
  - "--output"
  - "json"
  - "--output-directory"
  - "/tmp/results"
  volumeMounts:
  - name: aws-cli
    mountPath: /tmp
  lifecycle:
    postStart:
      exec:
        command:
        - /bin/sh
        - -c
        - |
          aws s3 cp /tmp/results \
            s3://prowler-reports/$(date +%Y-%m-%d)/ \
            --recursive
```

---

## 4. Azure 통합: Azure 구독 스캔하기

Prowler는 Azure 환경도 동일하게 지원합니다. AWS만큼이나 강력한 Azure 보안 체크를 제공합니다.

### 4.1. Azure 권한 설정

#### Option 1: Azure CLI 인증 (개발/테스트용)

```bash
# Azure에 로그인
az login

# 구독 목록 확인
az account list --output table

# Prowler로 Azure 스캔
prowler --provider azure
```

#### Option 2: 서비스 주체(Service Principal) 생성 (운영용)

```bash
# 변수 설정
TENANT_ID="your-tenant-id"
SUBSCRIPTION_ID="your-subscription-id"

# 서비스 주체 생성
az ad sp create-for-rbac \
  --name "ProwlerScannerSP" \
  --role "Reader" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID"

# 출력 결과:
# {
#   "appId": "xxxx-xxxx-xxxx",
#   "displayName": "ProwlerScannerSP",
#   "password": "xxxx-xxxx-xxxx",
#   "tenant": "xxxx-xxxx-xxxx"
# }
```

**서비스 주체 권한 설정:**
```bash
# Reader 역할 할당 (최소 권한)
az role assignment create \
  --assignee "ProwlerScannerSP" \
  --role "Reader" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# 추가 권한이 필요한 경우 (Security Reader 역할)
az role assignment create \
  --assignee "ProwlerScannerSP" \
  --role "Security Reader" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

### 4.2. Azure 스캔 실행

```bash
# Azure 스캔 (기본)
prowler --provider azure

# 특정 테넌트/구독 지정
prowler --provider azure \
  --tenant-id "your-tenant-id" \
  --subscription-id "your-subscription-id"

# Azure CIS Benchmark 검증
prowler --provider azure \
  --compliance cis_azure_foundations_benchmark_v1_5_0

# 결과를 HTML 리포트로 생성
prowler --provider azure \
  --output html \
  --output-directory ./reports
```

### 4.3. AKS에서 Azure 스캔 구성

#### 1단계: Managed Identity 생성

```bash
CLUSTER_NAME="my-aks-cluster"
RESOURCE_GROUP="my-resource-group"
LOCATION="eastus"

# 클러스터의 리소스 그룹에서 Managed Identity 생성
az identity create \
  --resource-group $RESOURCE_GROUP \
  --name prowler-identity

# Identity의 정보 저장
IDENTITY_CLIENT_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name prowler-identity \
  --query clientId -o tsv)

IDENTITY_PRINCIPAL_ID=$(az identity show \
  --resource-group $RESOURCE_GROUP \
  --name prowler-identity \
  --query principalId -o tsv)
```

#### 2단계: Managed Identity 권한 할당

```bash
# 구독 수준에서 Reader 역할 할당
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

az role assignment create \
  --assignee $IDENTITY_PRINCIPAL_ID \
  --role "Reader" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"

# 추가: Security Reader 역할
az role assignment create \
  --assignee $IDENTITY_PRINCIPAL_ID \
  --role "Security Reader" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"
```

#### 3단계: Pod Identity 바인딩 (Workload Identity)

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prowler-sa
  namespace: prowler
  annotations:
    azure.workload.identity/client-id: "YOUR_IDENTITY_CLIENT_ID"
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: prowler-azure-scan
  namespace: prowler
spec:
  schedule: "0 3 * * *"  # 매일 새벽 3시
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            azure.workload.identity/use: "true"
        spec:
          serviceAccountName: prowler-sa
          containers:
          - name: prowler
            image: public.ecr.aws/prowler/prowler:latest
            args:
            - "--provider"
            - "azure"
            - "--output"
            - "json"
            - "--output-directory"
            - "/mnt/reports"
            env:
            - name: AZURE_CLIENT_ID
              value: "YOUR_IDENTITY_CLIENT_ID"
            - name: AZURE_TENANT_ID
              value: "YOUR_TENANT_ID"
            - name: AZURE_SUBSCRIPTION_ID
              value: "YOUR_SUBSCRIPTION_ID"
            volumeMounts:
            - name: reports
              mountPath: /mnt/reports
          volumes:
          - name: reports
            persistentVolumeClaim:
              claimName: prowler-reports-pvc
          restartPolicy: OnFailure
```

**배포:**
```bash
kubectl apply -f prowler-azure-cronjob.yaml
```

### 4.4. 멀티클라우드 스캔 (AWS + Azure)

여러 클라우드를 동시에 스캔해야 한다면, **각 클라우드별 CronJob**을 분리하는 것이 좋습니다.

```yaml
---
# AWS 스캔 (매일 새벽 2시)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: prowler-aws-scan
  namespace: prowler
spec:
  schedule: "0 2 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: prowler
            image: public.ecr.aws/prowler/prowler:latest
            args: ["--provider", "aws", "--output", "json"]
          restartPolicy: OnFailure
---
# Azure 스캔 (매일 새벽 3시)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: prowler-azure-scan
  namespace: prowler
spec:
  schedule: "0 3 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: prowler
            image: public.ecr.aws/prowler/prowler:latest
            args: ["--provider", "azure", "--output", "json"]
          restartPolicy: OnFailure
---
# GCP 스캔 (매일 새벽 4시)
apiVersion: batch/v1
kind: CronJob
metadata:
  name: prowler-gcp-scan
  namespace: prowler
spec:
  schedule: "0 4 * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: prowler
            image: public.ecr.aws/prowler/prowler:latest
            args: ["--provider", "gcp", "--output", "json"]
          restartPolicy: OnFailure
```

### 4.5. Azure 결과 분석 및 보고

```bash
# Azure 스캔 결과 (JSON)
prowler --provider azure --output json --output-directory ./reports

# HTML 리포트 생성 (경영진 보고용)
prowler --provider azure --output html

# 특정 항목만 필터링 (예: FAILED 항목)
jq '.[] | select(.Result.Result == "FAILED")' prowler-azure-scan-report.json
```

**Python 스크립트로 Azure 결과 정리:**
```python
import json
import sys

# Prowler JSON 리포트 로드
with open('prowler-azure-scan-report.json', 'r') as f:
    findings = json.load(f)

# 심각도별 분류
critical = [f for f in findings if f['Result']['Result'] == 'FAILED' and f['Severity'] == 'Critical']
high = [f for f in findings if f['Result']['Result'] == 'FAILED' and f['Severity'] == 'High']
medium = [f for f in findings if f['Result']['Result'] == 'FAILED' and f['Severity'] == 'Medium']

print(f"Critical: {len(critical)}")
print(f"High: {len(high)}")
print(f"Medium: {len(medium)}")

# 리소스별 요약
resource_issues = {}
for f in findings:
    resource = f['Resource']['ARN']  # Azure: ResourceName
    if resource not in resource_issues:
        resource_issues[resource] = []
    resource_issues[resource].append(f['FindingType'])

for resource, issues in resource_issues.items():
    print(f"{resource}: {len(issues)} 이슈")
```

---

## 5. 결과 대시보드화 및 자동 보고

Prowler의 JSON 출력을 활용하여 **대시보드 구축**이나 **자동 보고서 생성**을 할 수 있습니다.

### 5.1. Grafana 대시보드 구성

Prowler JSON 결과를 Prometheus로 변환하고, Grafana로 시각화합니다.

```bash
# 1. Prowler 결과를 JSON으로 저장
prowler --provider aws --output json --output-directory ./results

# 2. Prometheus 메트릭으로 변환 (Python 스크립트)
python3 << 'EOF'
import json
import re

with open('results/prowler-aws-scan-report.json', 'r') as f:
    findings = json.load(f)

# Prometheus 메트릭 생성
metrics = []
for finding in findings:
    check_id = finding['CheckID']
    result = 1 if finding['Result']['Result'] == 'PASSED' else 0
    severity = finding.get('Severity', 'Unknown')

    metric = f'prowler_check{{check_id="{check_id}",severity="{severity}"}} {result}'
    metrics.append(metric)

with open('prowler-metrics.txt', 'w') as f:
    f.write('\n'.join(metrics))
EOF

# 3. Prometheus Node Exporter로 노출
cp prowler-metrics.txt /var/lib/prometheus/node_exporter/textfile_collector/
```

### 5.2. Slack 알림 구성

```python
import json
import requests
import os

SLACK_WEBHOOK = os.getenv('SLACK_WEBHOOK_URL')

with open('prowler-aws-scan-report.json', 'r') as f:
    findings = json.load(f)

# Critical 이슈만 필터링
critical_issues = [f for f in findings if f['Severity'] == 'Critical' and f['Result']['Result'] == 'FAILED']

if critical_issues:
    message = {
        'text': f'🚨 Prowler Critical Issues Found: {len(critical_issues)}',
        'blocks': [
            {
                'type': 'section',
                'text': {
                    'type': 'mrkdwn',
                    'text': f'*Critical Issues*: {len(critical_issues)}\n'
                }
            }
        ]
    }

    for issue in critical_issues[:5]:  # 상위 5개만
        message['blocks'].append({
            'type': 'section',
            'text': {
                'type': 'mrkdwn',
                'text': f"• `{issue['CheckID']}` - {issue['FindingType']}\n    Resource: {issue['Resource']['ARN']}"
            }
        })

    requests.post(SLACK_WEBHOOK, json=message)
```

---

## 6. Prowler 체크리스트 및 운영 가이드

### 6.1. Prowler 설치/운영 체크리스트

| # | 항목 | 상태 |
| :--- | :--- | :--- |
| 1-1 | Prowler 설치 및 버전 확인 | ☐ |
| 1-2 | AWS/Azure/GCP IAM 권한 설정 | ☐ |
| 1-3 | 로컬 스캔 테스트 (모든 클라우드) | ☐ |
| 2-1 | Kubernetes CronJob 배포 | ☐ |
| 2-2 | S3/Azure Storage 결과 저장소 설정 | ☐ |
| 2-3 | 스케줄 자동 실행 확인 | ☐ |
| 3-1 | Slack/Teams 알림 구성 | ☐ |
| 3-2 | 대시보드 (Grafana/Excel) 구성 | ☐ |
| 4-1 | 정기 보고서 자동화 (주 1회) | ☐ |
| 4-2 | Critical 이슈 SLA 정의 (e.g., 24시간 내 해결) | ☐ |

### 6.2. CIS Benchmark 대응 로드맵

Prowler로 CIS Benchmark를 검증할 때 자주 발견되는 이슈와 해결 방법입니다.

| CIS 항목 | 일반적 이슈 | 해결 방법 | 우선순위 |
| :--- | :--- | :--- | :--- |
| 1.1 (Root Account MFA) | 루트 계정에 MFA 미설정 | AWS Console → IAM → 루트 계정 MFA 활성화 | Critical |
| 2.1 (CloudTrail) | CloudTrail 로깅 비활성화 | `aws cloudtrail start-logging` | Critical |
| 4.1 (NACLs) | 과도한 인바운드 규칙 | Security Group 검토, 불필요한 포트 닫기 | High |
| 5.1 (Encryption) | 미암호화 데이터 | S3 기본 암호화 활성화, EBS 암호화 | High |

---

## 7. Q&A: 실전 운영 팁

### Q1. Prowler 스캔에 너무 오래 걸려요. 어떻게 줄일 수 있나요?

**A:** 다음 방법들을 시도해보세요:

```bash
# 1. 특정 리전만 스캔 (전체 리전 대신)
prowler --provider aws --region us-east-1,eu-west-1

# 2. 특정 체크만 수행
prowler --provider aws --checks s3_public_access_block_enabled

# 3. 병렬 처리 (다중 스캔 job)
prowler --provider aws --region us-east-1 &
prowler --provider aws --region eu-west-1 &
wait
```

### Q2. Prowler 결과에서 False Positive가 많아요.

**A:** Prowler는 보안 "정책" 기반으로 동작하기 때문에, 조직의 정책과 맞지 않는 경우가 있습니다. 다음과 같이 대응하세요:

```json
{
  "Checks": {
    "s3_bucket_public_access_block": {
      "Exclude": {
        "Resources": ["arn:aws:s3:::public-website-bucket"]
      }
    }
  }
}
```

### Q3. 멀티테넌트(다중 AWS 계정) 환경에서 Prowler를 어떻게 운영하나요?

**A:** AWS Organizations의 **Member Account**에서 Prowler를 실행하는 방식을 권장합니다:

```bash
# 중앙 계정에서 각 Member 계정의 역할을 Assume
for account_id in 111111111111 222222222222 333333333333; do
  role_arn="arn:aws:iam::$account_id:role/ProwlerRole"

  # STS Assume Role
  credentials=$(aws sts assume-role \
    --role-arn "$role_arn" \
    --role-session-name prowler-scan \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)

  # Prowler 실행
  AWS_ACCESS_KEY_ID=$(echo $credentials | cut -d' ' -f1) \
  AWS_SECRET_ACCESS_KEY=$(echo $credentials | cut -d' ' -f2) \
  AWS_SESSION_TOKEN=$(echo $credentials | cut -d' ' -f3) \
  prowler --provider aws --output json --output-directory ./results/$account_id
done
```

---

## 8. 요약 및 다음 단계

Prowler를 통해 다음을 달성할 수 있습니다:

1. ✅ **자동화된 클라우드 보안 감사** - 500+ 체크로 정책 준수 검증
2. ✅ **멀티클라우드 거버넌스** - AWS, Azure, GCP 통합 관리
3. ✅ **지속적인 모니터링** - Kubernetes CronJob으로 정기 스캔 자동화
4. ✅ **규정 준수 증적** - CIS, PCI-DSS, HIPAA 등 자동 리포트 생성

**다음 단계:**

1. 로컬에서 Prowler 설치 및 첫 스캔 실행
2. 팀의 클라우드 환경에 맞춘 커스텀 체크 작성
3. Kubernetes 환경에 배포하여 자동화 구축
4. 대시보드 및 알림 연동으로 지속적인 모니터링 체계 수립

---

## 참고 자료

- [Prowler 공식 문서](https://docs.prowler.com/)
- [AWS CIS Benchmark](https://d1.awsstatic.com/whitepapers/compliance/AWS_CIS_Foundations_Benchmark.pdf)
- [Azure CIS Benchmark](https://www.cisecurity.org/benchmark/azure)
- [Prowler GitHub](https://github.com/prowler-cloud/prowler)
