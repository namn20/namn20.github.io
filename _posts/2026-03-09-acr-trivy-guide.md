---
layout: post
title: "[보안 가이드] AKS 환경 리스크 최소화: ACR과 Trivy를 활용한 컨테이너 취약점 진단 실무"
date: 2026-03-06
categories: [DevOps, Security, Kubernetes]
tags: [kubernetes, aks, security, trivy, acr, devsecops]
---
최근 클라우드 네이티브 환경(Cloud Native)이 표준으로 자리 잡으면서 Kubernetes(K8s) 보안의 중요성이 그 어느 때보다 강조되고 있습니다. 그중에서도 **컨테이너 이미지에 존재하는 취약점(CVE)**은 공격자가 클러스터 내부에 침투하기 위한 가장 쉬운 진입점(Entry Point)이 됩니다.

본 포스팅에서는 **Azure Kubernetes Service(AKS)** 환경을 운영 중인 조직을 대상으로, 별도의 인프라 관리 비용이 발생하는 Harbor 대신 완전 관리형 서비스인 **ACR(Azure Container Registry)**과 강력한 오픈소스 보안 스캐너인 **Trivy**를 결합하여 효율적이고 비용 최적화된 취약점 진단 체계를 구축하는 방법을 보안 전문가 관점에서 상세히 가이드합니다.

---

## 1. 아키텍처 설계 고민: 왜 Harbor 대신 ACR + Trivy 인가?

초기 컨테이너 레지스트리 도입 시 많은 조직이 오픈소스인 **Harbor**를 검토합니다. Harbor는 내장된 스캐너, 이미지 서명, 세밀한 RBAC 등 훌륭한 엔터프라이즈 기능을 제공하지만, 이를 운영하기 위한 **가상 머신(VM) 인프라 비용과 전담 엔지니어의 관리 포인트(백업, HA 구성, 패치 등)가 숨은 비용(Hidden Cost)**으로 발생합니다. 

> **Tip (보안 전문가의 제언)**
> 클라우드 보안의 핵심은 '책임 공유 모델'을 현명하게 활용하는 것입니다. 인프라 운영 부담을 CSP(Cloud Service Provider)에게 넘기고, 보안 조직은 '정책 수립'과 '취약점 조치'에 집중하는 것이 효율적입니다. 따라서 유지보수가 필요 없는 **ACR(Azure Container Registry)**을 이미지 저장소로 활용하고, 가볍고 빠르며 CI/CD 파이프라인 통합이 유연한 **Trivy**를 결합하는 결정을 강력히 권장합니다.

---

## 2. 보안 진단 워크플로우 (DevSecOps)

안전한 컨테이너 배포를 위한 흐름은 다음과 같습니다.

1. **Build & Local Scan:** 개발자가 코드를 빌드하고 컨테이너 이미지를 생성합니다. (Trivy로 로컬 1차 스캔)
2. **Push to ACR:** CI 환경에서 ACR로 이미지를 푸시합니다.
3. **Pipeline Scan (Gatekeeper):** CI/CD 파이프라인 과정에서 Trivy가 ACR에 접근하여 다시 스캔을 수행합니다. `CRITICAL` 수준의 취약점이 발견되면 파이프라인을 중단(Fail)시켜 AKS로의 배포를 원천 차단합니다.
4. **Deploy to AKS:** 안전이 검증된 이미지만 AKS 클러스터에 배포됩니다.
5. **Runtime K8s Scan:** (선택) Trivy K8s 기능을 통해 이미 실행 중인 AKS 클러스터 워크로드의 설정 오류(Misconfiguration) 및 런타임 취약점을 주기적으로 진단합니다.

---

## 3. 실무 구축 가이드: CLI 기반 Trivy 진단 환경 구성

### 3.1 사전 준비
진단을 수행할 로컬 환경 또는 CI Agent에 Trivy와 Azure CLI가 설치되어 있어야 합니다.

```bash
# Trivy 설치 (macOS 예시, OS별 설치 공식 문서 참조)
brew install aquasecurity/trivy/trivy

# Azure CLI 설치
brew install azure-cli
```

### 3.2 ACR 인증 (Authentication)
Trivy가 ACR에 저장된 이미지를 스캔하려면 Private Registry에 대한 인증 권한이 필요합니다. 

```bash
# Azure 로그인
az login

# ACR 로그인 (Trivy가 스캔 시 이 Docker 자격 구성을 사용하여 ACR에서 이미지를 Pull 함)
az acr login --name <YourRegistryName>
```

> **Important**: CI/CD 파이프라인 환경에서는 `az login` 대신 **서비스 주체(Service Principal)** 또는 **Azure Workload Identity**를 생성하여 `AcrPull` 권한만 부여한 최소 권한의 원칙(Least Privilege)을 준수해야 합니다.

### 3.3 Trivy 스캔 수행 및 결과 분석

ACR에 올라가 있는 특정 이미지 인덱스에 대해 스캔을 수행합니다.

```bash
# 기본 스캔 (테이블 형태로 콘솔 출력, 심각도가 HIGH, CRITICAL 인 것만 필터링)
trivy image --severity HIGH,CRITICAL <YourRegistryName>.azurecr.io/my-app:v1.0.0
```

#### ✅ 보안 실무 팁 1: 배포 차단(Fail-Build) 설정
CI/CD 파이프라인에서는 자물쇠 역할을 할 수 있도록 `--exit-code` 옵션을 활용합니다.

```bash
trivy image \
  --severity CRITICAL \
  --exit-code 1 \
  --format table \
  <YourRegistryName>.azurecr.io/my-app:v1.0.0
```
*해석:* `CRITICAL` 취약점이 1개라도 발견되면 종료 코드 `1`을 반환하여 파이프라인 빌드를 실패시킵니다. (허용 가능한 위험으로 판단된 HIGH 이하는 탐지만 수행)

#### ✅ 보안 실무 팁 2: 파일로 결과 저장 (보고 및 모니터링 연동)
스캔 결과를 GitHub Security 탭이나 SonarQube, DefectDojo 등 타 보안 관리 시스템에 연동하기 위해 JSON 또는 SARIF 포맷으로 출력합니다.

```bash
trivy image \
  --format sarif \
  --output trivy-results.sarif \
  <YourRegistryName>.azurecr.io/my-app:v1.0.0
```

---

## 4. 취약점 정오탐 판별 및 예외 처리 가이드 (`.trivyignore`)

보안 업무를 하다 보면 수많은 취약점 중 오탐(False Positive)이거나, "우리 환경에서는 악용될 수 없어 수용 가능한 위험(Accepted Risk)"으로 판단되는 취약점들이 존재합니다. 무분별하게 모든 취약점을 조치하려 하면 알람 피로도(Alert Fatigue)만 높아지고 핵심 위협을 놓칠 수 있습니다. 이를 방지하기 위한 **정오탐 판별 프로세스**와 예외 처리 방법을 알아봅니다.

### 4.1 정오탐 판별을 위한 5단계 검증 프로세스

Trivy 등 스캐너에서 `CRITICAL` / `HIGH` 취약점이 탐지될 경우, 다음 5가지 기준으로 실질적 위협도를 평가합니다.

1. **취약점 발생 조건 및 벤더 권고안 확인:** 
   * Trivy 결과의 `PrimaryURL` 및 `References`를 통해 특정 OS 버전이나 옵션에서만 발현되는지 확인합니다.
   * Alpine, Ubuntu 등 베이스 이미지 벤더사의 공식 권고문에서 해당 CVE가 자사 OS에 미치는 영향을 교차 검증합니다 (예: `Will not fix`, `Not affected`).
2. **환경적 맥락(Context) 분석 (가장 중요):**
   * **실행 권한:** 취약점이 `root` 권한을 요구하지만 컨테이너가 `non-root`로 실행된다면 위험도는 낮아집니다.
   * **네트워크 노출 여부:** 외부 인터넷과 단절된 Private 망에서 구동되는 경우, 원격 코드 실행(RCE) 취약점이라도 긴급 통제 수준이 낮아질 수 있습니다.
   * **실제 사용 여부:** 베이스 이미지에 탑재된 `curl`, `wget` 등의 유틸리티에 취약점이 있으나 앱 로직이 이를 전혀 호출하지 않는 경우 실질적 위협은 적습니다.
3. **익스플로잇(Exploit) 존재 여부:**
   * CISA KEV (알려진 악용 취약점 카탈로그)에 등재되었거나 Exploit-DB 등에 공격 코드가 공개되어 있는지 점검합니다.해당 경우 무조건적인 최우선 조치 대상입니다.
4. **패치 가능 여부(Fixability) 확인:**
   * Trivy의 `FixedVersion`을 확인하여 안전한 버전으로 즉시 업데이트 가능한지 판단합니다. 패치가 없는 제로데이(Zero-day)거나 벤더사 대응이 끝난 경우라면 WAF나 네트워크 통제 등 대안 조치(Mitigation)가 필요합니다.
5. **예외 처리 및 지속 모니터링:** 
   * 위 검증을 통해 "악용 불가" 혹은 "위협 수용 가능"으로 판명되면 `.trivyignore`를 통해 CI/CD 파이프라인에서 예외로 등록하여 빌드 통과를 허용합니다.

### 4.2 실무 예외 처리 적용 (`.trivyignore`)

프로젝트 루트 디렉토리에 `.trivyignore` 파일을 생성하여 예외 처리를 체계화하세요. **반드시 왜 예외 처리했는지 주석으로 상세한 이력을 남기는 것**이 보안 감사에 필수적입니다.

```text
# .trivyignore 파일 예시
# 사유: CVE-2023-XXXXX는 컨테이너가 Root로 실행될 때만 발현 가능한 취약점임. 현재 K8s SecurityContext에서 Non-root를 강제 적용 중이므로 수용 가능 위험으로 판단함. (검토결재: 2026-03-10 / 보안팀 홍길동)
CVE-2023-XXXXX

# 사유: 애플리케이션 로직에서 호출하지 않는 베이스 이미지 내부의 curl 패키지 관련 취약점. 클러스터 네트워크 정책으로 인터넷 아웃바운드가 차단되어 실위협 없음.
CVE-2024-YYYYY
```

> **Caution**: `.trivyignore` 파일은 개발자가 임의로 추가하거나 우회하지 못하도록, 해당 파일의 변경 건에 대해서는 반드시 **보안팀의 Pull Request 코드 리뷰 및 승인(Approval)을 필수로 거치도록 보호(Branch Protection)**해야 합니다.

---

## 5. (Bonus) Trivy를 활용한 AKS 런타임 보안 진단

이미지는 배포 전 스캔하지만, 취약점 데이터베이스(DB)는 매일 업데이트됩니다. 즉, 배포 시점에 안전했던 이미지가 한 달 뒤에는 위험해질 수 있습니다. Trivy는 K8s 클러스터 자체를 진단하는 기능도 제공합니다.

```bash
# AKS 클러스터 자격 증명 가져오기
az aks get-credentials --resource-group <ResourceGroup> --name <AKSClusterName>

# 현재 AKS 클러스터 내 구동 중인 모든 워크로드를 스캔하여 요약 리포트 제공
trivy k8s --report summary cluster
```
이를 통해 런타임 환경에서 새롭게 발견된 CVE나 위험한 권한 매핑(예: `Privileged: true` 파드)을 주기적으로 모니터링할 수 있습니다.

---

## 마치며

**ACR**이라는 안정적인 관리형 레지스트리와 **Trivy**라는 범용적이고 이식성 뛰어난 스캐너의 조합은, 인프라 관리 비용(TCO)을 최소화하면서도 완벽에 가까운 "Shift-Left" 보안 체계를 제공합니다.

보안은 한 번의 솔루션 도입으로 끝나는 것이 아니라 프로세스와 지속적인 모니터링이 핵심입니다. 위 가이드를 참고하여 CI/CD 파이프라인에 보안 게이트(Security Gate)를 성공적으로 안착시키시기 바랍니다!
