---
title: Paperclip - AI 에이전트 팀을 운영하는 오픈소스 컨트롤 플레인
date: 2026-04-02 09:00:00 +0900
categories: [AI & Automation, AI Tools]
tags: [paperclip, ai-agents, orchestration, open-source, llm, automation, multi-agent]
---

# Paperclip: AI 에이전트 팀을 운영하는 오픈소스 컨트롤 플레인

> "OpenClaw이 _직원_이라면, Paperclip은 _회사_다."

출시 4주 만에 GitHub 스타 45,000개를 돌파한 오픈소스 프로젝트 **Paperclip**. 단순한 AI 도구가 아닌, AI 에이전트들을 조직화하고 거버넌스까지 적용하는 **컨트롤 플레인(Control Plane)**입니다.

---

## Paperclip이 등장한 이유

Claude Code, Cursor, Codex 같은 AI 코딩 도구는 이미 훌륭한 "에이전트 직원"을 제공합니다. 하지만 다음 질문을 생각해보세요.

- 20개의 에이전트를 동시에 어떻게 조율하나요?
- 어떤 에이전트가 어떤 작업을 맡고 있는지 어떻게 추적하나요?
- LLM 비용이 폭발적으로 증가하는 것을 어떻게 막나요?
- 중요한 결정을 에이전트가 자의적으로 내리는 것을 어떻게 방지하나요?

이 모든 조율 문제를 Paperclip이 해결합니다. **개별 에이전트 위에서 동작하는 조직 관리 레이어**입니다.

---

## 주요 기능

### 조직 구조 (Org Chart)

에이전트에게 역할과 보고 체계를 부여합니다. PM, Engineer, Analyst 등 직함을 가진 에이전트 팀을 구성할 수 있으며, 최상단에는 항상 **Board(인간)**가 위치합니다.

![Paperclip 조직도 화면](/assets/img/posts/2026-04-02-paperchip/스크린샷 2026-04-03 오후 3.10.53.png)
_PM(CEO), Engineer(Software Engineer), Analyst(Security Triage Analyst) 역할이 부여된 에이전트 조직도_

### 목표 정렬 (Goal Alignment)

회사 미션 → Initiative → Project → Milestone → Issue 계층으로 작업이 흘러갑니다. 모든 에이전트는 자신이 왜 이 작업을 하는지 알고, 항상 최상위 목표와 연결됩니다.

### 재무 통제 (Budget Control)

에이전트별 월간 토큰/LLM 비용 예산을 설정합니다. 예산 80%에서 소프트 알림, 100% 도달 시 에이전트를 자동으로 일시정지합니다. 비용 폭주를 원천 차단합니다.

### 대시보드

![Paperclip 대시보드](/assets/img/posts/2026-04-02-paperchip/스크린샷 2026-04-03 오후 3.10.36.png)
_에이전트 현황, 진행 중인 작업, 비용 현황을 한눈에 확인하는 대시보드_

### Heartbeat 시스템

에이전트는 스케줄된 주기나 이벤트 트리거로 활성화됩니다. 재시작 후에도 세션 상태를 유지(Persistent Session)해 처음부터 다시 시작하지 않습니다.

### 어댑터 호환성

OpenClaw, Claude Code, Codex, Cursor, Python 프로세스, Bash, HTTP 기반 에이전트를 모두 지원합니다.

---

## 설치 및 시작

### 원커맨드 온보딩

```bash
npx paperclipai onboard --yes
```

### 수동 설치

```bash
git clone https://github.com/paperclipai/paperclip.git
cd paperclip
pnpm install
pnpm dev
```

- API 서버: `http://localhost:3100`
- 별도 DB 설정 불필요 — 기본적으로 임베디드 PGlite 사용

**요구사항:** Node.js 20+, pnpm 9.15+

### 상태 확인

```bash
curl http://localhost:3100/api/health
curl http://localhost:3100/api/companies
```

---

## 효과적인 사용법

Paperclip은 설치보다 **어떻게 운영하느냐**가 핵심입니다.

### 1. 명확한 회사 목표 설정부터

```
좋은 예: "3개월 내 $1M MRR을 달성하는 AI 메모 앱 #1 만들기"
나쁜 예: "좋은 앱 만들기"
```

Paperclip의 모든 에이전트는 이 최상위 목표에서 역추적해 작업 맥락을 이해합니다. 목표가 모호하면 전체 정렬이 무너집니다.

### 2. 작업 계층을 의도적으로 활용

```
Mission
  └── Initiative (전략적 방향)
        └── Project (구체적 프로젝트)
              └── Milestone (마일스톤)
                    └── Issue (실제 작업)
```

이 계층을 평탄화하지 마세요. 계층 구조가 곧 에이전트의 맥락이고, 비용 추적의 단위입니다.

### 3. 예산 설정을 첫날부터

에이전트를 배포하기 전에 예산 한도를 설정하세요. 자동 일시정지는 사후 조치가 아니라 안전망입니다. 특히 24/7 자율 운영 시 LLM 비용 폭주를 막는 유일한 방어선입니다.

### 4. Board 승인 게이트를 우회하지 않기

에이전트 채용, CEO 전략 변경 등 중요 결정은 반드시 Board(인간) 승인을 거칩니다. 이 단계를 건너뛰고 싶은 유혹이 생겨도, 이것이 **인간이 통제권을 유지하는 핵심 메커니즘**입니다.

### 5. Heartbeat 주기를 고려한 태스크 설계

에이전트는 실시간이 아닙니다. 작업은 한 Heartbeat 주기 내에 완료 가능한 단위로 설계하세요. 멀티스텝 작업은 중간 상태를 명확히 저장하는 방식으로 구성합니다.

### 6. 회사 템플릿 내보내기/가져오기 활용

```bash
# UI에서 Export company → secrets 제거 후 재사용
```

성공적인 조직 구조를 템플릿화해 다른 프로젝트에 빠르게 적용할 수 있습니다. 팀 표준 조직 구조를 만들어두면 신규 프로젝트 셋업 시간을 크게 줄입니다.

### 7. 멀티 컴퍼니 격리 활용

단일 Paperclip 인스턴스에서 여러 독립 프로젝트(회사)를 완전 격리 운영할 수 있습니다. 데이터와 에이전트가 섞이지 않으므로 보안 민감한 프로젝트도 안전하게 병렬 운영됩니다.

---

## 개발 관련 명령어

```bash
pnpm dev:once       # 파일 감시 없이 1회 실행
pnpm dev:server     # 서버만 실행
pnpm build          # 프로덕션 빌드
pnpm typecheck      # TypeScript 검사
pnpm test:run       # 테스트 실행
pnpm db:generate    # DB 마이그레이션 생성
pnpm db:migrate     # 마이그레이션 적용

# 로컬 개발 DB 초기화
rm -rf data/pglite && pnpm dev
```

### 텔레메트리 비활성화

```bash
PAPERCLIP_TELEMETRY_DISABLED=1 pnpm dev
# 또는
DO_NOT_TRACK=1 pnpm dev
```

---

## Paperclip이 해결하지 않는 것

Paperclip은 명확한 범위를 가집니다. 다음은 의도적으로 Paperclip의 영역 밖입니다.

- 에이전트 자체 구축 (Claude Code, Codex 등이 담당)
- 챗봇 인터페이스
- 워크플로우 파이프라인 (n8n, Zapier 영역)
- 프롬프트 관리
- 코드 리뷰

**조율과 거버넌스**에만 집중합니다.

---

## 누구에게 적합한가

| 상황 | 적합 여부 |
|------|-----------|
| 20개 이상의 에이전트 동시 조율이 필요한 경우 | ✅ |
| 24/7 자율 운영 + 인간 감독 구조가 필요한 경우 | ✅ |
| LLM 비용 엄격 통제가 필요한 경우 | ✅ |
| 여러 자율 프로젝트를 병렬 운영하는 경우 | ✅ |
| 단일 에이전트로 간단한 작업 자동화가 목적인 경우 | ❌ |
| 챗봇이나 대화형 AI가 주 목적인 경우 | ❌ |

---

## 리소스

- GitHub: [https://github.com/paperclipai/paperclip](https://github.com/paperclipai/paperclip)
- 공식 문서: [https://paperclip.ing/docs](https://paperclip.ing/docs)
- Discord: [https://discord.gg/m4HZY7xNG3](https://discord.gg/m4HZY7xNG3)
- 라이선스: MIT

---

AI 에이전트를 단순히 "쓰는" 것에서 "운영하는" 것으로 전환하고 싶다면, Paperclip은 현재 가장 실용적인 출발점입니다. 오픈소스이고, 설치는 한 줄이며, 4주 만에 45k 스타를 받은 데는 이유가 있습니다.
