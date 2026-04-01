---
title: Claude Code + GSD - 기획부터 검증까지 자동화하는 법
date: 2026-04-01 09:00:00 +0900
categories: [AI & Automation, AI Tools]
tags: [claude-code, gsd, ai, coding-agent, automation, llm]
---

# Claude Code + GSD: 기획부터 검증까지 자동화하는 법

Claude Code는 강력합니다. 하지만 GSD(Get Shit Done)는 그것을 **신뢰할 수 있게** 만들어 줍니다.

이 글에서는 AgentOS 채널의 영상을 바탕으로, Claude Code와 GSD를 함께 사용해 소프트웨어 개발 전 과정을 자동화하는 방법을 소개합니다.

---

## GSD란?

GSD(Get Shit Done)는 Claude Code, Gemini CLI, Cursor, Windsurf 등 다양한 AI 코딩 도구를 위한 **경량 메타 프롬프팅 + 컨텍스트 엔지니어링 + 스펙 기반 개발 시스템**입니다.

```bash
npx get-shit-done-cc@latest
```

설치 후 대화형 프롬프트에서 런타임(Claude Code 등)과 설치 범위(전역/로컬)를 선택하면 됩니다.

### 왜 GSD인가?

AI 코딩 도구를 사용하다 보면 공통적인 문제를 만납니다. 바로 **컨텍스트 오염(Context Rot)**입니다. 대화가 길어질수록 컨텍스트 윈도우가 채워지면서 응답 품질이 떨어지는 현상입니다.

GSD는 이 문제를 해결하기 위해 설계되었습니다.

- 메인 컨텍스트는 30~40% 수준으로 유지
- 무거운 작업은 서브에이전트에 위임 (각 에이전트는 200k 토큰의 신선한 컨텍스트를 가짐)
- 모든 단계에서 XML 구조화 프롬프트로 일관성 확보

---

## GSD 핵심 워크플로우

GSD의 개발 흐름은 6단계로 구성됩니다.

### 1단계 - 프로젝트 초기화: `/gsd:new-project`

아이디어를 완전히 이해할 때까지 질문하고, 병렬 에이전트로 도메인을 리서치한 뒤 요구사항과 로드맵을 자동 생성합니다.

생성 파일:
- `PROJECT.md` — 프로젝트 비전 (항상 로드됨)
- `REQUIREMENTS.md` — v1/v2 범위 구분된 요구사항
- `ROADMAP.md` — 페이즈별 로드맵
- `STATE.md` — 세션 간 유지되는 상태 및 결정 사항

### 2단계 - 페이즈 논의: `/gsd:discuss-phase [N]`

계획 수립 전에 구현 선호도를 파악합니다. 회색지대(gray area)를 카테고리별로 분석합니다.

- UI 기능: 레이아웃, 밀도, 인터랙션, 빈 상태 처리
- API/CLI: 응답 형식, 에러 처리, 상세도
- 콘텐츠 시스템: 구조, 톤, 흐름
- 조직화 작업: 그룹핑 기준, 네이밍, 예외 처리

생성 파일: `{phase_num}-CONTEXT.md`

### 3단계 - 계획 수립: `/gsd:plan-phase [N]`

CONTEXT.md를 바탕으로 구현 방법을 리서치하고, 2~3개의 **원자적 태스크 플랜**을 XML 구조로 작성한 뒤 요구사항과 대조 검증합니다. 검증을 통과할 때까지 반복합니다.

```xml
<task type="auto">
  <name>로그인 엔드포인트 생성</name>
  <files>src/app/api/auth/login/route.ts</files>
  <action>
    jose로 JWT 처리 (jsonwebtoken은 CommonJS 문제로 제외).
    users 테이블에서 자격증명 검증.
    성공 시 httpOnly 쿠키 반환.
  </action>
  <verify>curl -X POST localhost:3000/api/auth/login → 200 + Set-Cookie</verify>
  <done>올바른 자격증명은 쿠키 반환, 잘못된 경우 401 반환</done>
</task>
```

### 4단계 - 실행: `/gsd:execute-phase [N]`

플랜들을 **웨이브 방식으로 병렬 실행**합니다.

```
WAVE 1 (병렬)              WAVE 2 (병렬)              WAVE 3
┌─────────┐ ┌─────────┐    ┌─────────┐ ┌─────────┐    ┌─────────┐
│ Plan 01 │ │ Plan 02 │ →  │ Plan 03 │ │ Plan 04 │ →  │ Plan 05 │
│ 유저 모델│ │ 상품 모델│    │ 주문 API│ │ 장바구니│    │ 결제 UI │
└─────────┘ └─────────┘    └─────────┘ └─────────┘    └─────────┘
```

- 각 실행기는 신선한 200k 토큰 컨텍스트로 시작
- 태스크마다 원자적 git 커밋 생성

```bash
abc123f feat(08-02): add email confirmation flow
def456g feat(08-02): implement password hashing
hij789k feat(08-02): create registration endpoint
```

### 5단계 - 검증: `/gsd:verify-work [N]`

검증 가능한 결과물을 추출하고 하나씩 확인합니다. 실패 시 디버그 에이전트가 자동으로 원인을 진단하고 수정 플랜을 생성합니다.

생성 파일: `{phase_num}-UAT.md`, 이슈 발견 시 수정 플랜

### 6단계 - 배포 및 다음 마일스톤

```bash
/gsd:ship [N]           # PR 생성 및 리뷰
/gsd:complete-milestone # 마일스톤 완료 처리
/gsd:new-milestone      # 새 마일스톤 시작
/gsd:next               # 다음 단계 자동 감지
```

---

## 멀티 에이전트 오케스트레이션

| 단계 | 오케스트레이터 역할 | 에이전트 |
|------|-------------------|----------|
| 리서치 | 결과 취합 및 발표 | 4개 병렬 리서처 (스택/기능/아키텍처/리스크) |
| 계획 | 검증 및 반복 관리 | 플래너 + 체커 (통과까지 루프) |
| 실행 | 웨이브 그룹화 및 진행 추적 | 병렬 실행기 (신선한 200k 컨텍스트) |
| 검증 | 결과 제시 및 다음 단계 라우팅 | 검증기 + 디버그 에이전트 |

---

## 모델 프로필 설정

비용과 품질의 균형을 프로필로 조절할 수 있습니다.

| 프로필 | 계획 | 실행 | 검증 |
|--------|------|------|------|
| `quality` | Opus | Opus | Sonnet |
| `balanced` (기본값) | Opus | Sonnet | Sonnet |
| `budget` | Sonnet | Sonnet | Haiku |
| `inherit` | 상속 | 상속 | 상속 |

```bash
/gsd:set-profile balanced
```

---

## 빠른 작업: Quick Mode

전체 플로우 없이 즉석 작업이 필요할 때는 Quick Mode를 사용합니다.

```bash
/gsd:quick              # 기본 빠른 실행
/gsd:quick --discuss    # 실행 전 간단 논의
/gsd:quick --research   # 실행 전 리서치
/gsd:quick --full       # 플랜 체크 + 검증 포함
```

---

## 보안 기능

v1.27부터 보안 강화 기능이 내장되어 있습니다.

- 경로 순회 공격 방지
- 프롬프트 인젝션 탐지 (`security.cjs` 중앙 모듈)
- `.planning/` 쓰기 시 PreToolUse 가드 훅 동작
- 안전한 JSON 파싱 및 셸 인수 새니타이징

---

## 마치며

GSD는 AI 코딩의 고질적인 문제인 컨텍스트 오염을 서브에이전트 오케스트레이션과 XML 구조화 프롬프트로 해결합니다. 기획부터 검증까지 일관된 품질을 유지하면서 자동화할 수 있는 강력한 워크플로우입니다.

단순히 코드를 빠르게 쓰는 것이 아니라, **신뢰할 수 있는 방식으로** 소프트웨어를 완성하고 싶다면 GSD를 도입해 보세요.

- GitHub: [gsd-build/get-shit-done](https://github.com/gsd-build/get-shit-done)
- 설치: `npx get-shit-done-cc@latest`
- 커뮤니티: discord.gg/gsd
