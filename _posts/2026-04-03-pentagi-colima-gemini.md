---
layout: post
title: "[보안 자동화] PentAGI + Colima + Gemini API: macOS에서 AI 침투테스트 에이전트 구축하기"
date: 2026-04-03
categories: [Security, PenTest]
tags: [pentagi, colima, gemini, ai, pentest, docker, autonomous, security]
image:
  path: /assets/img/posts/2026-04-03-pentagi/overview.png
  alt: PentAGI - AI 기반 자율 침투테스트 플랫폼
---

AI가 스스로 침투테스트를 수행한다면 어떨까요? **PentAGI**는 GPT/Claude/Gemini 같은 LLM을 활용해 nmap, metasploit, sqlmap 등 20개 이상의 보안 도구를 자율적으로 조합하고 실행하는 AI 기반 자동화 침투테스트 에이전트입니다. macOS 환경에서 Docker Desktop 대신 가벼운 **Colima**를 사용하고, **Google Gemini API**로 구동하는 방법을 소개합니다.

---

## PentAGI란?

[PentAGI](https://github.com/vxcontrol/pentagi)는 "Penetration testing Artificial General Intelligence"의 약자로, 보안 전문가와 연구자를 위한 완전 자율화 침투테스트 플랫폼입니다. GitHub Stars 14,000+를 기록하며 빠르게 성장하고 있는 오픈소스 프로젝트입니다.

![PentAGI 개요](/assets/img/posts/2026-04-03-pentagi/overview.png)
_PentAGI 웹 UI — AI 에이전트가 실시간으로 침투테스트를 수행하는 화면_

### 핵심 특징

| 항목 | 내용 |
|---|---|
| **자율 실행** | AI 에이전트가 공격 단계를 스스로 결정하고 실행 |
| **샌드박스 격리** | 모든 작업이 Docker 컨테이너 내에서 격리 수행 |
| **통합 보안 도구** | nmap, metasploit, sqlmap, gobuster 등 20+ 도구 내장 |
| **장기 메모리** | Neo4j 지식 그래프로 연구 결과 및 성공 전략 축적 |
| **다중 LLM 지원** | OpenAI, Anthropic, Gemini, Ollama, DeepSeek 등 10+ 공급자 |
| **자동 보고서** | 취약점 상세 보고서 및 공격 가이드 자동 생성 |
| **완전 자체 호스팅** | 데이터 외부 유출 없이 온프레미스 운영 |

### 아키텍처

```
┌─────────────────────────────────────────────────────┐
│                    PentAGI Stack                    │
├─────────────┬────────────────┬──────────────────────┤
│  Frontend   │    Backend     │    Supporting        │
│  React+TS   │  Go+GraphQL   │   PostgreSQL+pgvec   │
│  Web UI     │  REST API      │   Neo4j (그래프DB)   │
└─────────────┴────────────────┴──────────────────────┘
         ↓ LLM 요청
┌─────────────────────────────────────────────────────┐
│            Gemini / OpenAI / Claude ...             │
└─────────────────────────────────────────────────────┘
         ↓ 도구 실행
┌─────────────────────────────────────────────────────┐
│     격리된 Docker 샌드박스 (보안 도구 컨테이너)       │
│     nmap / metasploit / sqlmap / gobuster / ...     │
└─────────────────────────────────────────────────────┘
```

---

## 사전 준비: Colima 설치 및 설정

macOS에서 Docker Desktop 없이 컨테이너를 실행하려면 **Colima**가 좋은 대안입니다. 가볍고 무료이며 Docker CLI와 완전히 호환됩니다.

### Colima 설치

```bash
# Homebrew로 설치
brew install colima docker docker-compose

# Colima 시작 (PentAGI는 리소스를 꽤 사용하므로 넉넉하게 설정)
colima start --cpu 4 --memory 8 --disk 40

# 상태 확인
colima status
docker info
```

> **Tip**: 매번 수동으로 시작하는 대신 macOS 부팅 시 자동 시작을 설정할 수 있습니다.
> ```bash
> # 로그인 시 자동 시작
> brew services start colima
> ```

### Docker Compose 플러그인 확인

```bash
docker compose version
# Docker Compose version v2.x.x 이상이어야 합니다
```

---

## Gemini API 키 발급

PentAGI를 Gemini로 구동하려면 Google AI Studio에서 API 키를 발급받아야 합니다.

1. [Google AI Studio](https://aistudio.google.com/app/apikey) 접속
2. **"Create API key"** 클릭
3. 프로젝트 선택 또는 새 프로젝트 생성
4. 발급된 키 복사 (`AIza...` 형태)

> 무료 티어에서도 Gemini 1.5 Flash/Pro 사용 가능하며, 침투테스트 에이전트 실습 수준에는 충분합니다.

---

## PentAGI 설치

### 1. 작업 디렉토리 생성 및 환경 파일 다운로드

```bash
mkdir pentagi && cd pentagi

# 환경변수 템플릿 다운로드
curl -o .env https://raw.githubusercontent.com/vxcontrol/pentagi/master/.env.example

# docker-compose 파일 다운로드
curl -O https://raw.githubusercontent.com/vxcontrol/pentagi/master/docker-compose.yml
```

### 2. .env 파일 설정

`.env` 파일을 열어 Gemini API 키와 필수 설정을 입력합니다.

```bash
# macOS에서 편집
nano .env
# 또는
code .env
```

**필수 변경 항목:**

```bash
# ─── LLM 공급자: Gemini 설정 ───────────────────────────────
GEMINI_API_KEY=AIzaSy...your_gemini_api_key_here...

# 기본 모델을 Gemini로 지정 (선택)
# MAIN_MODEL_PROVIDER=gemini
# MAIN_MODEL=gemini-1.5-pro

# ─── 보안 설정 (반드시 변경 권장) ────────────────────────────
COOKIE_SIGNING_SALT=여기에_랜덤_문자열_입력

# ─── PostgreSQL 패스워드 ──────────────────────────────────────
PENTAGI_POSTGRES_PASSWORD=강력한_패스워드_입력

# ─── Neo4j 패스워드 ───────────────────────────────────────────
NEO4J_PASSWORD=강력한_패스워드_입력

# ─── 서버 주소 (로컬 사용 시 기본값 유지 가능) ───────────────
PUBLIC_URL=https://localhost:8443
```

**선택: 검색 엔진 통합 (AI 에이전트 정보 수집 강화)**

```bash
# DuckDuckGo는 키 없이 사용 가능
DUCKDUCKGO_ENABLED=true

# Tavily (선택, 더 정확한 보안 정보 검색)
# TAVILY_API_KEY=tvly-...

# Perplexity (선택)
# PERPLEXITY_API_KEY=pplx-...
```

### 3. Colima에서 Docker 소켓 경로 확인

Colima는 기본 Docker 소켓 경로가 다를 수 있습니다. `.env`에서 Docker 소켓 설정을 확인합니다.

```bash
# Colima의 Docker 소켓 위치 확인
ls -la ~/.colima/default/docker.sock

# 환경변수로 설정 (필요한 경우)
export DOCKER_HOST=unix://${HOME}/.colima/default/docker.sock
```

`.env` 파일에 Docker 호스트 설정이 있다면 Colima 소켓 경로로 변경합니다.

```bash
# .env 내 Docker 설정
DOCKER_HOST=unix:///Users/your_username/.colima/default/docker.sock
```

또는 셸 프로파일에 영구 등록합니다.

```bash
# ~/.zshrc 또는 ~/.bashrc에 추가
echo 'export DOCKER_HOST=unix://${HOME}/.colima/default/docker.sock' >> ~/.zshrc
source ~/.zshrc
```

---

## 실행

```bash
# 컨테이너 시작 (백그라운드)
docker compose up -d

# 로그 확인
docker compose logs -f

# 서비스 상태 확인
docker compose ps
```

모든 서비스가 `running` 상태가 되면 브라우저에서 접속합니다.

```
https://localhost:8443
```

> 자체 서명 인증서를 사용하므로 브라우저에서 **"고급 → 안전하지 않음으로 이동"** 클릭이 필요합니다.

**기본 로그인 정보:**

| 항목 | 값 |
|---|---|
| 이메일 | `admin@pentagi.com` |
| 패스워드 | `admin` |

> 최초 로그인 후 반드시 패스워드를 변경하세요.

---

## 첫 번째 침투테스트 플로우 실행

### 웹 UI에서 플로우 생성

1. 로그인 후 **"New Flow"** 클릭
2. 타겟 정보 입력 (예: `Scan 192.168.1.0/24 for open ports and identify services`)
3. LLM 공급자로 **Gemini** 선택
4. **"Start"** 클릭

AI 에이전트가 자동으로:
- 정보 수집 단계 계획 수립
- nmap 스캔 실행
- 발견된 서비스에 대한 취약점 분석
- 추가 공격 벡터 탐색
- 최종 보고서 생성

### API 토큰으로 자동화

웹 UI **Settings → API Tokens**에서 토큰 생성 후 GraphQL API 활용:

```bash
# 실행 중인 플로우 목록 조회
curl -X POST https://localhost:8443/api/v1/graphql \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -H "Content-Type: application/json" \
  -k \
  -d '{"query": "{ flows { id title status } }"}'
```

---

## 운영 팁

### 리소스 모니터링

PentAGI는 여러 컨테이너를 동시에 운영하므로 Colima 리소스를 모니터링합니다.

```bash
# Colima 내 리소스 사용량
docker stats

# 필요 시 Colima 리소스 조정 (재시작 필요)
colima stop
colima start --cpu 6 --memory 12 --disk 60
```

### 컨테이너 관리

```bash
# 서비스 중지
docker compose down

# 설정 변경 후 재시작
docker compose down
docker compose up -d --force-recreate

# 볼륨 포함 완전 초기화 (데이터 삭제 주의)
docker compose down -v
```

### Gemini 모델 선택 가이드

| 모델 | 추천 용도 | 비고 |
|---|---|---|
| `gemini-1.5-flash` | 빠른 정보 수집, 간단한 분석 | 저비용, 높은 처리량 |
| `gemini-1.5-pro` | 복잡한 공격 체인 계획 | 더 깊은 추론 능력 |
| `gemini-2.0-flash` | 최신 모델, 빠른 응답 | 2026년 기준 권장 |

---

## 주의 사항

> **이 도구는 반드시 허가된 환경에서만 사용해야 합니다.**

- 본인 소유 또는 명시적 허가를 받은 시스템에만 사용
- 실제 프로덕션 환경 대상 무단 스캔 및 공격은 불법
- CTF, 취약점 랩(HackTheBox, TryHackMe), 내부 테스트 환경에 적합
- 모든 활동 로그가 PostgreSQL에 저장되므로 감사 추적 가능

---

## 마무리

PentAGI는 침투테스트의 반복적이고 시간 소모적인 정보 수집 및 기초 분석 작업을 AI로 자동화하여 보안 전문가가 더 복잡한 분석에 집중할 수 있게 해줍니다. macOS에서 Docker Desktop 없이 Colima로 가볍게 구동하고, Gemini API로 비용 효율적으로 운영할 수 있다는 점이 큰 장점입니다.

보안 자동화에 관심 있는 분들께 좋은 출발점이 될 것입니다.

---

**참고 링크**
- [PentAGI GitHub](https://github.com/vxcontrol/pentagi)
- [Colima GitHub](https://github.com/abiosoft/colima)
- [Google AI Studio (Gemini API 키 발급)](https://aistudio.google.com/app/apikey)
