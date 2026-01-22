---
layout: post
title: "GitLab CI에 Nexus IQ Server 연동 및 Threat Level 10 차단 정책 설정하기"
date: 2026-01-18
categories: [Security, AppSec]
tags: [gitlab, ci/cd, nexus, sonatype, security, pipeline]
---

DevSecOps를 구축하다 보면 빌드 파이프라인에서 보안 취약점을 자동으로 점검하고, 심각한 위협이 발견되면 배포를 막아야 하는 상황이 옵니다.

이번 포스트에서는 **GitLab CI** 파이프라인에 **Sonatype Nexus IQ Server** 스캔을 연동하고, 심각도(Threat Level)가 **10점(Critical)**인 취약점이 발견될 때만 빌드를 실패 처리(Fail)하는 방법을 상세히 알아보겠습니다.

---

## 1. 아키텍처 및 요구사항

### 목표
- GitLab CI 파이프라인 실행 시 애플리케이션 빌드 아티팩트를 Nexus IQ Server로 스캔합니다.
- **Threat Level 10** 미만의 취약점은 경고(Warn)만 남기고 넘어가지만, **10점**인 경우에는 파이프라인을 **중단(Fail)**시킵니다.

### 준비물
- GitLab 프로젝트
- 실행 가능한 Nexus IQ Server
- Nexus IQ Server 계정 (정책 관리 권한 필요)

---

## 2. Nexus IQ Server 정책 설정 (가장 중요)

파이프라인이 멈추느냐 마느냐는 CI 스크립트(`gitlab-ci.yml`)가 아니라, **Nexus IQ Server의 정책(Policy)**에 의해 결정됩니다. CLI 툴은 서버가 "Fail" 응답을 주면 에러 코드를 반환하기 때문입니다.

### 2.1 정책 생성

1. Nexus IQ Server 관리자 콘솔에 로그인합니다.
2. 왼쪽 메뉴의 **Orgs & Policies**로 이동합니다.
3. 적용하려는 Organization(또는 Root)을 선택하고 **Policies** 영역에서 **Add a Policy**를 클릭합니다.
    - **Name**: `Block Critical Threat 10` (식별하기 쉬운 이름)
    - **Threat Level**: 10 (이 정책 위반 자체의 심각도를 나타냅니다)

### 2.2 제약 조건(Constraints) 설정

어떤 경우에 이 정책이 위반되는지 조건을 겁니다.

1. **Constraints** 탭으로 이동합니다.
2. 새 조건을 추가합니다.
    - **Condition**: `Security Vulnerability Severity`
    - **Operator**: `>=` (이상)
    - **Value**: `10`
    
    > **Tip**: 이렇게 설정하면 CVSS 점수가 아닌, Sonatype에서 책정한 Threat Level 10인 취약점만 잡습니다.

### 2.3 액션(Actions) 설정

정책 위반 시 어떤 동작을 할지 설정합니다. 여기가 핵심입니다.

1. **Actions** 탭으로 이동합니다.
2. **Build** 스테이지(CI에서 실행할 단계)를 찾습니다.
3. Action을 **Fail**로 설정합니다.
    - 참고로 다른 스테이지나, Threat Level 9 이하를 다루는 다른 정책들은 **Warn**이나 **No Action**으로 설정되어 있어야 10점만 차단됩니다.

---

## 3. GitLab CI 변수 설정

`.gitlab-ci.yml` 파일에 비밀번호를 하드코딩하는 것은 보안상 좋지 않습니다. GitLab CI/CD Variables를 사용합시다.

1. GitLab 프로젝트 설정 > **Settings** > **CI/CD** > **Variables**로 이동합니다.
2. 다음 변수들을 추가합니다.
    - `NEXUS_IQ_SERVER_URL`: 예) `http://nexus.example.com:8070`
    - `NEXUS_USER`: Nexus 접근 계정 ID
    - `NEXUS_PASSWORD`: Nexus 접근 계정 비밀번호 (Masked 설정 권장)
    - `NEXUS_IQ_APP_ID`: Nexus IQ에 등록된 Application ID

---

## 4. .gitlab-ci.yml 파이프라인 구성

이제 실제 파이프라인 코드를 작성합니다. `sonatype/nexus-iq-cli` 도커 이미지를 사용하면 간편합니다.

```yaml
stages:
  - build
  - scan

# 1. 애플리케이션 빌드 단계
build_app:
  stage: build
  image: maven:3.8-openjdk-11 # 예시: Java 프로젝트
  script:
    - echo "Building application..."
    - mvn clean package -DskipTests
  artifacts:
    paths:
      - "target/*.jar"
    expire_in: 1 hour

# 2. Nexus IQ 스캔 단계
nexus_scan:
  stage: scan
  image: sonatype/nexus-iq-cli:latest
  script:
    - echo "Starting Nexus IQ Scan..."
    # nexus-iq-cli 실행
    # -s: 서버 URL
    # -a: 인증 정보 (User:Pass)
    # -i: App ID
    # -t: Stage (build 단계로 검사)
    # 마지막 인자: 스캔 대상 파일 또는 디렉토리
    - /sonatype/nexus-iq-cli/nexus-iq-cli -s $NEXUS_IQ_SERVER_URL -a $NEXUS_USER:$NEXUS_PASSWORD -i $NEXUS_IQ_APP_ID -t build ./target
  allow_failure: false
```

### 코드 설명
- `artifacts`: 빌드 단계에서 생성된 결과물(`target/*.jar`)을 `scan` 스테이지로 넘겨주기 위해 필수입니다.
- `-t build`: Nexus 정책 설정에서 **Build** 스테이지에 **Fail** 액션을 걸었으므로, 여기서도 `-t build`를 사용해야 매칭되어 차단이 작동합니다.
- `allow_failure: false`: 스캔 툴이 에러 코드(정책 위반)를 반환하면 파이프라인을 즉시 실패시킵니다.

---

## 5. 결과 확인

설정을 마친 후 파이프라인을 실행해 봅니다.

1. **Threat Level 10 미만 발견 시**: 콘솔 로그에 취약점이 출력되지만, Exit Code 0으로 정상 종료되고 파이프라인은 성공합니다.
2. **Threat Level 10 발견 시**:
   - Nexus IQ Server 정책에 의해 차단(Action: Fail)이 발동됩니다.
   - CLI 툴이 에러를 뱉고 종료됩니다.
   - GitLab CI Job이 **Failed** 상태로 바뀝니다.
   - Nexus IQ Server 대시보드 리포트 링크가 로그에 출력되므로, 클릭하여 상세 내용을 확인할 수 있습니다.

---

## 마치며

이렇게 설정하면 개발팀은 평소에는(위협 10점 미만) 파이프라인 중단 없이 개발 속도를 유지하다가, 정말 위험한 **치명적 취약점**이 들어왔을 때만 확실한 브레이크를 걸 수 있습니다.

보안과 생산성의 균형을 맞추는 데 도움이 되기를 바랍니다!
