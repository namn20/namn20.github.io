---
title: AI를 활용한 보안 정책 관리 자동화 PoC 가이드
date: 2026-01-06 12:00:00 +0900
categories: [Mgmt-Security, Policy]
tags: [security, ai, gitlab, pipeline]
---

## 개요

수시로 변경되는 보안 정책과 가이드라인을 모든 개발자가 숙지하고 코드에 반영하기란 쉽지 않습니다. 이로 인해 발생하는 보안 취약점을 사전에 예방하고, 정책 관리의 효율성을 높이기 위해 AI를 활용한 자동화 프로세스 구축을 제안합니다.

본 문서는 **AI를 이용해 코드 변경 사항을 자동으로 검토하고 보안 정책 위반 여부를 분석**하는 프로세스의 개념 검증(PoC) 가이드를 제공합니다. GitLab의 CI/CD 파이프라인과 대규모 언어 모델(LLM)을 연동하여 Merge Request(MR) 단계에서 자동화된 보안 피드백을 받는 것을 목표로 합니다.

---


## 1단계: 계획 및 설계 (Planning & Design)

본격적인 구현에 앞서, PoC의 목표와 범위를 명확히 하고 전체적인 프로세스를 설계합니다.

### 1.1. 목표 정의 (Goal)

- 개발자가 Merge Request를 생성하면, AI가 코드 변경 사항을 분석하여 사전에 정의된 보안 정책과 비교한다.
- 분석 결과, 보안 정책에 위배될 가능성이 있는 코드가 발견되면 해당 MR에 자동으로 코멘트를 남겨 개발자에게 피드백을 제공한다.
- 이를 통해 수동 코드 리뷰에 드는 시간을 절약하고, 개발 초기 단계에서부터 보안성을 강화(Shift-Left Security)한다.

### 1.2. 범위 설정 (Scope)

- **In-Scope (범위 내):**
    - 1~2개의 간단한 보안 정책(e.g., API Key 하드코딩 금지, 특정 위험 함수 사용 금지)을 대상으로 테스트합니다.
    - 정책 문서는 사람이 읽을 수 있는 Markdown(`.md`) 파일로 관리합니다.
    - GitLab CI/CD 파이프라인을 통해 프로세스를 자동화합니다.
    - AI 분석 결과는 MR의 코멘트로 한정합니다. (파이프라인을 실패시키지 않음)

- **Out-of-Scope (범위 외):**
    - 복잡한 로직을 가진 모든 보안 정책의 검증.
    - AI 모델의 자체적인 미세 조정(Fine-tuning).
    - 분석 결과에 따른 파이프라인 차단 또는 강제 수정.

### 1.3. 기술 스택 (Tech Stack)

- **CI/CD:** GitLab CI/CD
- **AI Model:** Gemini, GPT 등 상용 LLM API
- **Scripting:** Python (API 연동 및 스크립팅에 용이)
- **정책 저장소:** 프로젝트 내 Git Repository

### 1.4. 프로세스 설계 (Process Flow)

1.  **개발자:** 코드 수정 후 GitLab에 Push 하고 Merge Request를 생성합니다.
2.  **GitLab CI/CD:** MR 생성을 트리거로, 'security-review' 파이프라인이 실행됩니다.
3.  **Python 스크립트:** 
    a. MR의 코드 변경 사항(`git diff`)을 가져옵니다.
    b. Git Repository에 저장된 보안 정책(`security-policy.md`) 파일을 읽어옵니다.
    c. 코드 변경 사항과 보안 정책을 조합하여 LLM에게 보낼 프롬프트(Prompt)를 생성합니다.
    d. LLM API (e.g., Gemini)로 프롬프트를 전송하고 분석 결과를 요청합니다.
4.  **LLM (AI):** 프롬프트를 기반으로 코드의 보안 정책 위반 여부를 분석하고, 결과를 JSON 형식 등으로 반환합니다.
5.  **Python 스크립트:** LLM의 응답을 파싱하여 MR에 코멘트를 남길 내용을 정리한 후, GitLab API를 통해 코멘트를 등록합니다.
6.  **개발자:** MR에 달린 AI의 피드백을 확인하고 코드를 수정합니다.

---


## 2단계: 구현 (Implementation)

설계한 내용을 바탕으로 실제 구현을 진행합니다.

### 2.1. 보안 정책 문서화

프로젝트 루트에 `security-policy.md` 파일을 생성하고 간단한 정책을 텍스트로 작성합니다.

```markdown
# 우리 회사의 보안 코딩 가이드라인

1.  **API 키 또는 비밀번호를 소스 코드에 절대 하드코딩하지 마십시오.**
    - 환경 변수나 GitLab의 CI/CD 변수를 사용해야 합니다.
    - 예시: `API_KEY = "sk-..."` 와 같은 코드는 금지됩니다.

2.  **안전하지 않은 HTTP 프로토콜 사용을 금지합니다.**
    - 모든 외부 API 요청에는 반드시 HTTPS를 사용해야 합니다.
    - 예시: `http://api.example.com` 대신 `https://api.example.com` 을 사용해야 합니다.
```

### 2.2. AI 분석 스크립트 작성 (Python)

LLM API와 연동하여 코드 변경분을 분석할 Python 스크립트(`review_bot.py`)를 작성합니다.

```python
import os
import requests
import sys

# GitLab/LLM API 정보 (CI/CD 변수로 설정 권장)
GITLAB_API_URL = os.getenv("CI_API_V4_URL")
GITLAB_PROJECT_ID = os.getenv("CI_PROJECT_ID")
GITLAB_MR_IID = os.getenv("CI_MERGE_REQUEST_IID")
GITLAB_TOKEN = os.getenv("GITLAB_API_TOKEN") # 프로젝트 Access Token
LLM_API_KEY = os.getenv("LLM_API_KEY")
LLM_ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent" # 예시: Gemini

# 1. 코드 변경 사항 및 보안 정책 읽기
try:
    with open('diff.txt', 'r') as f:
        code_diff = f.read()
    with open('security-policy.md', 'r') as f:
        security_policy = f.read()
except FileNotFoundError as e:
    print(f"Error: {e}. Make sure 'diff.txt' and 'security-policy.md' exist.")
    sys.exit(1)

# 2. LLM에 보낼 프롬프트 생성
prompt = f"""
You are an automated security code reviewer.
Your task is to analyze the following code changes and determine if they violate any of our security policies.
If a violation is found, please specify which policy is violated and which part of the code is problematic.
Your response must be in Korean and formatted as a concise markdown comment.

---
[Security Policies]
{security_policy}
---
[Code Changes (diff format)]
{code_diff}
---

Please start your review now.
"""

# 3. LLM API 호출
headers = {"Content-Type": "application/json"}
data = {"contents": [{"parts": [{"text": prompt}]}]}
params = {"key": LLM_API_KEY}

try:
    response = requests.post(LLM_ENDPOINT, headers=headers, json=data, params=params)
    response.raise_for_status()
    result = response.json()
    review_comment = result['candidates'][0]['content']['parts'][0]['text']
except (requests.exceptions.RequestException, KeyError, IndexError) as e:
    print(f"Failed to get review from LLM: {e}")
    review_comment = "AI 리뷰를 생성하는 데 실패했습니다."

# 4. GitLab MR에 코멘트 등록
if review_comment:
    comment_url = f"{GITLAB_API_URL}/projects/{GITLAB_PROJECT_ID}/merge_requests/{GITLAB_MR_IID}/notes"
    headers = {"PRIVATE-TOKEN": GITLAB_TOKEN}
    data = {"body": "🤖 **AI 보안 자동 리뷰 결과:**\n\n" + review_comment}
    
    try:
        r = requests.post(comment_url, headers=headers, json=data)
        r.raise_for_status()
        print("Successfully posted a comment to the MR.")
    except requests.exceptions.RequestException as e:
        print(f"Failed to post a comment: {e}")
        sys.exit(1)

```

### 2.3. CI/CD 파이프라인 연동 (`.gitlab-ci.yml`)

MR이 생성될 때 위 스크립트를 실행하도록 GitLab CI/CD 파이프라인을 설정합니다.

```yaml
stages:
  - security-review

ai_security_review:
  stage: security-review
  image: python:3.9-slim
  script:
    # 1. 스크립트 실행에 필요한 라이브러리 설치
    - pip install requests

    # 2. MR의 소스 브랜치와 타겟 브랜치 간의 diff를 파일로 저장
    - git fetch origin $CI_MERGE_REQUEST_TARGET_BRANCH_NAME
    - git diff "origin/$CI_MERGE_REQUEST_TARGET_BRANCH_NAME...$CI_COMMIT_SHA" -- > diff.txt
    
    # 3. 환경변수로 전달된 토큰을 사용하여 Python 스크립트 실행
    # GITLAB_API_TOKEN, LLM_API_KEY는 GitLab Project > Settings > CI/CD > Variables 에 설정 필요
    - python review_bot.py

  rules:
    # 4. 이 작업은 Merge Request가 생성/업데이트 될 때만 실행
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

**사전 설정:**
- GitLab 프로젝트의 **Settings > CI/CD > Variables**에서 아래 변수들을 추가해야 합니다.
  - `LLM_API_KEY`: 사용하는 LLM의 API 키
  - `GITLAB_API_TOKEN`: GitLab MR에 코멘트를 작성할 권한(`api` 스코프)을 가진 프로젝트 Access Token

---


## 3단계: 테스트 및 고도화

이제 모든 준비가 끝났습니다. 의도적으로 보안 정책을 위반하는 코드를 작성하여 테스트를 진행합니다.

### 3.1. 테스트 시나리오

1.  새로운 브랜치를 생성합니다.
2.  소스 코드에 `API_KEY = "dummy-key-for-testing"` 과 같은 라인을 추가합니다.
3.  변경 사항을 commit하고 push한 뒤, Merge Request를 생성합니다.
4.  `ai_security_review` 파이프라인이 실행되는 것을 확인합니다.
5.  잠시 후, 생성된 MR에 AI 봇이 남긴 보안 리뷰 코멘트가 등록되는지 확인합니다.

### 3.2. 고도화 방안

PoC가 성공적으로 완료되었다면, 아래와 같은 방향으로 기능을 확장하고 고도화할 수 있습니다.

- **프롬프트 엔지니어링:** 더 정확하고 일관된 분석 결과를 얻기 위해 LLM에 보내는 프롬프트를 지속적으로 개선합니다.
- **정책의 구조화:** `.md` 파일 대신 `YAML`이나 `JSON` 형식으로 정책을 구조화하여 기계가 더 쉽게 파싱하고 처리하도록 개선합니다.
- **심각도에 따른 제어:** AI가 분석한 결과에 'Critical', 'Major', 'Minor'와 같은 심각도를 부여하고, 'Critical' 이슈가 발견되면 파이프라인을 실패 처리하여 머지를 차단하는 기능을 추가합니다.
- **양방향 소통:** 개발자가 AI 리뷰에 대해 질문하면, AI가 답변해주는 Q&A 기능을 추가합니다.

## 결론

AI를 CI/CD 파이프라인에 통합함으로써, 우리는 보안 정책 준수 여부를 개발 초기 단계에서 자동으로 검증할 수 있습니다. 이는 개발자의 보안 인식을 높이고, 잠재적인 보안 사고를 예방하며, 전체 개발 프로세스의 효율성을 크게 향상시킬 수 있는 강력한 방법입니다. 본 PoC를 시작으로 조직의 특성에 맞는 자동화된 DevSecOps 체계를 구축해 나가시길 바랍니다.