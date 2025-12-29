---
title: 폐쇄망 GitLab 환경에서 TruffleHog 바이너리로 시크릿 스캐닝 구축하기
author: admin
date: 2025-12-29 11:00:00 +0900
categories: [Tech, Security]
tags: [gitlab, trufflehog, air-gapped, security, binary, devsecops]
pin: false
math: false
mermaid: true
---

많은 폐쇄망 환경에서 Docker 사용이 제한되거나, Shell Executor 기반의 GitLab Runner를 사용하는 경우가 많습니다. 이럴 때는 Docker 이미지 대신 **TruffleHog 바이너리**를 직접 GitLab Runner 서버에 배치하여 시크릿 스캐닝을 수행할 수 있습니다.

## 1. 외부망 작업 (Preparation)

TruffleHog는 Go 언어로 빌드되어 의존성 없는 단일 실행 파일(Binary)로 제공되나, 룰셋 수정(소스 코드 수정) 시 재빌드가 필요합니다. 폐쇄망 내부에는 `go get`을 위한 인터넷 연결이 없으므로, 외부에서 모든 라이브러리를 하나로 묶는 **벤더링(Vendoring)** 작업을 수행합니다.

### 1) 소스코드 다운로드
```bash
git clone [https://github.com/trufflesecurity/trufflehog.git](https://github.com/trufflesecurity/trufflehog.git)
cd trufflehog

```
### 2) 의존성 패키지 다운로드 (Vendor 처리)
```bash
o mod vendor

```

### 3) 파일 반입
`trufflehog` 전체 폴더(특히 `vendor/`, `pkg/`, `go.mod`, `go.sum` 포함)를 압축하여 폐쇄망 내부 서버로 반입합니다.

---

## 2. 폐쇄망 작업 (Customizing & Build)
### 4) 룰셋 (Detector) 수정 필요시 
TruffleHog의 탐지 룰은 주로 `pkg/detectors/` 경로에 위치합니다. 보안 정책에 맞춰 로직을 커스텀합니다.
* **기존 룰 수정**: `pkg/detectors/[서비스명]/[서비스명].go` 파일을 열어 정규식(Regex)이나 키워드를 수정합니다.
* **커스텀 룰 추가**: `pkg/detectors/` 하위에 새 폴더를 만들고 기존 구조를 복사하여 새로운 탐지 로직을 작성합니다.

### 5) 폐쇄망 내 빌드 및 설치
반입한 소스 코드를 바탕으로 로컬에서 빌드합니다. 이때 `-mod=vendor` 플래그를 사용하여 인터넷 연결 없이 내부 `vendor` 폴더를 참조하도록 강제해야 합니다.
```bash
# 소스 루트 디렉토리에서 실행
go build -mod=vendor -o trufflehog main.go

```

---

## 3. 폐쇄망 작업 (GitLab)
