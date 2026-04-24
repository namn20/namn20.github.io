---
title: "NeuroSploit: AI 기반 자율 모의해킹 프레임워크 구축 및 실행 가이드"
date: 2026-04-24 13:50:00 +0900
categories: [Security, Penetration Testing]
tags: [neurosploit, ai, penetration-testing, security, llm, vulnerability-scanner]
---

AI 기술이 발전함에 따라 보안 분야에서도 LLM(Large Language Model)을 활용한 자동화 도구들이 등장하고 있습니다. 

이번 글에서는 AI 기반 자율 모의해킹 프레임워크인 **NeuroSploit**에 대해 알아보고, 설치부터 실제 실행 방법까지 다루겠습니다.

---

## 1. NeuroSploit이란? 소개 및 특징

NeuroSploit은 LLM을 활용하여 모의해킹 작업을 자동화하고 증강시키는 AI 기반 프레임워크입니다. 다음과 같은 주요 특징을 가지고 있습니다.

- **100가지 취약점 유형 지원**: 10개 카테고리에 걸친 100가지 취약점 스캔을 지원합니다.
- **자율 에이전트(Autonomous Agent)**: Recon, Junior Test, Tool Runner의 3-Stream 병렬 테스트를 수행합니다.
- **Kali 컨테이너 격리**: 각 스캔은 독립된 Kali Linux Docker 컨테이너에서 실행되어 서로 간섭이 없습니다.
- **환각(Hallucination) 방지 파이프라인**: 오탐(False-positive)을 줄이기 위한 강력한 검증 시스템이 내장되어 있습니다.

---

## 2. NeuroSploit 설치 방법

NeuroSploit을 설치하는 방법에는 Docker를 사용하는 방법과 수동 설정 방법이 있습니다. 여기서는 권장되는 **Docker 환경 기반 설치 방법**을 안내합니다.

### 2.1. 전제 조건

```bash
# 필수 요구사항
- Docker 및 Docker Compose
- API Key (OpenAI, Anthropic, Gemini 등)
```

### 2.2. 저장소 클론 및 환경 설정

먼저 깃허브 저장소를 클론하고 환경 변수 파일을 설정합니다.

```bash
# 저장소 클론
git clone https://github.com/JoasASantos/NeuroSploit.git
cd NeuroSploit

# 환경 변수 파일 복사 및 편집
cp .env.example .env
nano .env 
# ANTHROPIC_API_KEY, OPENAI_API_KEY 또는 GEMINI_API_KEY 등을 입력합니다.
```

### 2.3. Kali 샌드박스 이미지 빌드

NeuroSploit은 각 스캔마다 독립된 Kali Linux를 사용하므로 첫 실행 전에 샌드박스 이미지를 빌드해야 합니다. (약 5분 소요)

```bash
# Kali 샌드박스 이미지 빌드 (최초 1회)
./scripts/build-kali.sh
```

---

## 3. 실제 실행 및 대시보드 확인

설치가 완료되면 백엔드 및 프론트엔드 서비스를 실행하여 웹 인터페이스에 접속할 수 있습니다.

### 3.1. 서비스 실행

아래 명령어를 통해 백엔드 서버를 구동합니다.

```bash
# 백엔드 실행
uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

*참고: 프론트엔드를 수동으로 실행하려면 새로운 터미널에서 `cd frontend && npm install && npm run dev`를 입력합니다.*

### 3.2. 웹 인터페이스 접속

서비스가 정상적으로 실행되었다면, 브라우저를 열고 `http://localhost:8000` (운영 환경) 또는 `http://localhost:5173` (개발 환경)으로 접속합니다. 
![NeuroSploit Architecture](/assets/img/posts/2026-04-24-neurosploit/1.png)
![NeuroSploit Dashboard](/assets/img/posts/2026-04-24-neurosploit/2.png)

웹 대시보드에서는 다음과 같은 기능들을 사용할 수 있습니다.

- **스캔 실시간 모니터링**: 3-stream 자동 모의해킹 진행 상황 및 결과 실시간 확인
- **Sandbox Dashboard**: 스캔마다 생성된 Kali 컨테이너의 상태, 설치된 도구 등 모니터링
- **AI 터미널 에이전트**: 터미널 환경에서 AI와 상호작용하며 수동 분석 수행
- **취약점 검증(Validation)**: AI가 발견한 취약점의 오탐 여부를 확인하고 증적 확인

이처럼 NeuroSploit을 활용하면 AI 에이전트가 주도하는 강력한 모의해킹 환경을 손쉽게 구축할 수 있습니다.
