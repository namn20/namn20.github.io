---
layout: post
title: "tfsec을 활용한 Terraform IaC 보안 검사 및 CI/CD 파이프라인 연동 가이드"
date: 2026-08-08 21:30:00 +0900
categories: [Security, DevSecOps]
tags: [terraform, iac, tfsec, trivy, devsecops, github-actions, gitlab-ci]
---

# tfsec을 활용한 Terraform IaC 보안 검사 및 CI/CD 파이프라인 연동 가이드

`tfsec`은 Terraform 코드를 정적 분석하여 배포 전에 보안 취약점을 탐지해 주는 가장 대표적인 IaC(Infrastructure as Code) 보안 스캐너입니다. 현재는 Aqua Security의 `Trivy` 프로젝트에 통합되고 있으나, 여전히 기존 프로젝트나 단독 실행 환경에서 `tfsec` 바이너리가 널리 쓰이고 있습니다.

이 글에서는 실제 취약한 샘플 코드를 검사해 보고, 위반 사항을 수정하거나 예외 처리하는 방법, 그리고 GitHub Actions 및 GitLab CI 파이프라인 연동 예시까지 총정리합니다.

---

## 1. tfsec 설치 및 기본 실행

개발 환경에 맞게 `tfsec`을 설치합니다.

```bash
# macOS (Homebrew)
brew install tfsec

# Windows (Chocolatey)
choco install tfsec

# Docker 활용
docker run --rm -v "$(pwd):/src" aquasec/tfsec /src
```

설치 완료 후, Terraform 프로젝트의 루트 경로에서 아래 명령어로 검사를 수행합니다.
```bash
tfsec .
```

---

## 2. 보안 결함이 포함된 샘플 코드 스캔 실습

### ① 취약한 Terraform 샘플 코드 작성
보안상 결함이 존재하는 S3 버킷 및 보안 그룹(Security Group) 설정을 생성해 봅니다.

```hcl
# main.tf
terraform {
  required_version = ">= 1.0.0"
}

# 1. 암호화 및 퍼블릭 액세스 차단이 없는 취약한 S3 버킷
resource "aws_s3_bucket" "insecure_bucket" {
  bucket = "my-highly-insecure-data-bucket-example"
  # ACL이 public-read로 되어 있어 외부 노출 위험
  acl    = "public-read" 
}

# 2. SSH(22번 포트)가 전 세계(0.0.0.0/0)에 열려있는 취약한 보안 그룹
resource "aws_security_group" "insecure_sg" {
  name        = "insecure-ssh-sg"
  description = "Allow SSH from anywhere"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 전 세계 오픈 (위험)
  }
}
```

### ② tfsec 스캔 실행 및 결과 해석
해당 디렉토리에서 `tfsec .`을 실행하면 다음과 같은 결과가 출력됩니다.

```
$ tfsec .

  Result 1
  [aws-s3-no-public-access-with-acl] [HIGH] Resource 'aws_s3_bucket.insecure_bucket' defines a public ACL.
  /src/main.tf:9-12

      9 | resource "aws_s3_bucket" "insecure_bucket" {
     10 |   bucket = "my-highly-insecure-data-bucket-example"
     11 |   acl    = "public-read" 
     12 | }

  Impact:     Public access to the bucket could lead to data leakage
  Resolution: Do not use public ACLs on S3 buckets.

  Result 2
  [aws-vpc-no-public-ingress-sgr] [CRITICAL] Resource 'aws_security_group.insecure_sg' defines a fully open ingress security group rule on port 22.
  /src/main.tf:15-26

     18 |   ingress {
     19 |     from_port   = 22
     20 |     to_port     = 22
     21 |     protocol    = "tcp"
     22 |     cidr_blocks = ["0.0.0.0/0"]
     23 |   }

  Impact:     Anyone can connect to the port 22 over the internet
  Resolution: Limit the ingress to specific IP range

  ✔ 2 potential problems detected.
```

---

## 3. 취약점 조치 및 예외 처리(Ignore) 방법

### ① 코드 수정을 통한 조치
위반 사항인 퍼블릭 ACL을 비활성화하고, SSH 접근 대상을 사내 망 IP(`10.0.0.0/8` 등)로 제한하여 수정합니다.

```hcl
# main_fixed.tf
resource "aws_s3_bucket" "secure_bucket" {
  bucket = "my-secure-data-bucket-example"
  # acl을 명시하지 않거나 private으로 설정
  acl    = "private" 
}

resource "aws_security_group" "secure_sg" {
  name        = "secure-ssh-sg"
  description = "Allow SSH from internal network only"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"] # 사내 사설 IP 대역으로 제한
  }
}
```

### ② 주석을 이용한 보안 규칙 예외 처리 (Suppression)
비즈니스 요구사항상 어쩔 수 없이 규칙을 우회해야 하는 경우, 코드 내 주석으로 예외 등록을 할 수 있습니다.

> [!WARNING]
> 무분별한 예외 처리는 보안 경계를 무너뜨립니다. 반드시 승인된 사유를 주석에 명시하고 관리해야 합니다.

```hcl
resource "aws_security_group" "public_web_sg" {
  name        = "public-web-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    # tfsec:ignore:aws-vpc-no-public-ingress-sgr 퍼블릭 웹 서버이므로 80 포트 전체 개방 필요
    cidr_blocks = ["0.0.0.0/0"] 
  }
}
```

---

## 4. CI/CD 파이프라인 연동 예제

PR(Pull Request)이 생성되거나 Main 브랜치로 빌드가 돌아갈 때 `tfsec` 스캔을 자동으로 실행하여 위반 사항이 있을 시 빌드를 실패(Block) 처리하도록 구성합니다.

### ① GitHub Actions 연동 예시 (`.github/workflows/tfsec.yml`)
공식 GitHub Action인 `aquasecurity/tfsec-pr-commenter-action` 또는 단순 `tfsec-action`을 사용하여 위반 항목을 PR 코멘트로 남기거나 빌드를 중단시킵니다.

```yaml
name: IaC Security Scan (tfsec)

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  tfsec:
    name: tfsec scanner
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Source Code
        uses: actions/checkout@v3

      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.0
        with:
          # 위반 사항 발견 시 빌드 실패 처리 여부
          fail_on_decisions: true 
          # 추가 인자 설정 (예: soft fail 옵션 등)
          additional_args: --soft-fail
```

### ② GitLab CI 연동 예시 (`.gitlab-ci.yml`)
GitLab 환경에서는 Docker 이미지를 사용하여 스크립트 실행으로 제어합니다.

```yaml
stages:
  - test

tfsec-scan:
  stage: test
  image: 
    name: aquasecurity/tfsec:v1.28
    entrypoint: [""]
  script:
    # JUnit XML 포맷 보고서 생성 및 콘솔 출력
    - tfsec . --format junit --out tfsec-report.xml
  artifacts:
    reports:
      junit: tfsec-report.xml
    paths:
      - tfsec-report.xml
    expire_in: 1 week
  only:
    - merge_requests
    - main
```

---

## 💡 요약 및 권장 사항

* **Shift-Left 실천:** 개발 단계에서 매번 `tfsec`을 수동 실행하기보다 로컬 `pre-commit` 및 CI 파이프라인에 이식하여 자동 검증을 강제하세요.
* **보고서 활용:** Jenkins나 GitLab CI 연동 시 JUnit, SARIF 포맷 등으로 결과를 아티팩트로 추출하면 추후 보안 진단 감사 로그로 훌륭히 활용할 수 있습니다.
