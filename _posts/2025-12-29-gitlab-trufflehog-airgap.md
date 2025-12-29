---
title: 폐쇄망 GitLab 환경에서 TruffleHog로 시크릿 스캐닝 구축하기
author: Pedro
date: 2025-12-29 70:00:00 +0900
categories: [Tech-Security]
tags: [gitlab, trufflehog, air-gapped, security-scanning]
render_with_liquid: false
---
 
폐쇄망(Air-gapped) 환경은 보안상 안전하지만, 최신 보안 도구를 도입하기에는 제약이 많습니다. 특히 소스코드 내에 실수로 포함된 API Key, 패스워드 등을 찾아내는 **TruffleHog**를 GitLab CI/CD에 통합하는 방법을 정리합니다.

## 1. 사전 준비 (외부망 작업)

폐쇄망 내부로 들여갈 리소스를 먼저 준비해야 합니다.

### TruffleHog 바이너리 및 이미지 확보
TruffleHog는 Go로 작성되어 단일 바이너리로 실행 가능하므로, Docker 이미지나 바이너리 파일을 직접 다운로드합니다.

1. **Docker 이미지 (권장)**:
   ```bash
   # 외부망에서 수행
   docker pull trufflesecurity/trufflehog:latest
   docker save trufflesecurity/trufflehog:latest > trufflehog_image.tar

```

2. **바이너리 파일**:
[TruffleHog Releases](https://github.com/trufflesecurity/trufflehog/releases)에서 OS에 맞는 파일을 다운로드합니다.

## 2. 폐쇄망 환경 설정

### 이미지 레지스트리 등록

반입된 `trufflehog_image.tar`를 내부 폐쇄망의 Container Registry(GitLab 내장 레지스트리 등)에 업로드합니다.

```bash
docker load < trufflehog_image.tar
docker tag trufflesecurity/trufflehog:latest [internal-registry.example.com/security/trufflehog:latest](https://internal-registry.example.com/security/trufflehog:latest)
docker push [internal-registry.example.com/security/trufflehog:latest](https://internal-registry.example.com/security/trufflehog:latest)

```

## 3. GitLab CI/CD 파이프라인 구성

`.gitlab-ci.yml` 파일에 TruffleHog 스캔 단계를 추가합니다. 폐쇄망이므로 외부 DB 확인 기능을 끄고 로컬 스캔 위주로 설정해야 합니다.

```yaml
stages:
  - security-scan

trufflehog_scan:
  stage: security-scan
  image:
    name: [internal-registry.example.com/security/trufflehog:latest](https://internal-registry.example.com/security/trufflehog:latest)
    entrypoint: [""]
  variables:
    # 폐쇄망이므로 검증 서버 통신을 차단
    TRUFFLEHOG_NO_VERIFICATION: "true"
  script:
    - trufflehog filesystem . --fail --json > trufflehog-results.json
  artifacts:
    paths:
      - trufflehog-results.json
    when: always
    expire_in: 1 week
  allow_failure: false

```

### 주요 옵션 설명

* `filesystem .`: 현재 프로젝트 디렉토리 전체를 스캔합니다.
* `--fail`: 시크릿이 발견될 경우 파이프라인을 실패 처리하여 배포를 방지합니다.
* `--no-verification`: 외부 검증 서버(Truffle Security API 등)에 연결을 시도하지 않도록 설정합니다. (폐쇄망 필수)

## 4. 트러블슈팅 및 팁

### False Positive 관리

폐쇄망 내부에서 사용하는 특정 패턴이 오탐(False Positive)을 일으킨다면, `.trufflehog-ignore` 파일을 생성하여 관리할 수 있습니다.

### GitLab Runner 설정

GitLab Runner가 내부 레지스트리에 접근할 수 있도록 `config.toml`에서 `allowed_images` 또는 `pull_policy`를 확인하세요.

```toml
[runners.docker]
  pull_policy = "if-not-present" # 이미 로드된 이미지를 우선 사용

```

> **Note:** 폐쇄망 환경에서는 시크릿 데이터의 유출 경로가 제한적이지만, 내부자에 의한 사고나 향후 망 혼용 시 발생할 수 있는 리스크를 줄이기 위해 CI/CD 단계의 자동 스캔은 필수적입니다.

---

**참고 문서:**

* [TruffleHog Official Docs](https://docs.trufflesecurity.com/)
* [GitLab Offline Deployments](https://docs.gitlab.com/ee/topics/offline/)

```

---
