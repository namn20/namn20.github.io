---
layout: post
title: "GitHub 스타 합산 1.6만 개 — Karpathy의 통제와 gstack의 확장을 Antigravity에 적용하기"
date: 2026-04-25
categories: [AI, Productivity]
tags: [antigravity, karpathy, gstack, llm, ai-agent, workflow]
description: "AI 에이전트를 다룰 때 '무엇을 하지 말아야 할지'를 가르치는 Karpathy 가이드라인과, '어떤 역할을 맡길지'를 나누는 gstack 프레임워크를 결합하여 완벽한 AI 코딩 워크플로우를 만드는 방법을 다룹니다."
---

# 🚀 GitHub 스타 합산 1.6만 개 — Karpathy의 통제와 gstack의 확장을 Antigravity에 적용하기

AI 코딩 에이전트(Cursor, Claude Code, Antigravity 등)가 대중화되면서, 개발자의 고민은 "AI에게 코딩을 어떻게 시킬까?"에서 **"AI를 어떻게 효율적으로 관리할까?"**로 진화했습니다. 

최근 깃허브(GitHub)에서 폭발적인 인기를 끌었던 두 개의 리포지토리가 이 고민에 대한 완벽한 해답을 제시합니다.

- **[Karpathy Guidelines (SKILL.md)](https://github.com/forrestchang/andrej-karpathy-skills/blob/main/skills/karpathy-guidelines/SKILL.md)**: AI의 무분별한 코드 작성을 억제하는 **통제의 철학** (Star 6.5K+)
- **[gstack](https://github.com/garrytan/gstack)**: 가상 소프트웨어 개발팀처럼 AI의 역할을 나누는 **확장의 철학** (Star 10K+)

이 글에서는 전혀 다른 방향성을 가진 두 가지 개념이 어떻게 하나의 완벽한 워크플로우로 결합될 수 있는지, 그리고 이를 **Antigravity AI 에이전트에 어떻게 적용할 수 있는지** 알아봅니다.

---

## 📌 1. 두 철학의 만남: 통제(Constraint)와 확장(Expansion)

이 두 가지 개념은 서로 충돌하지 않고 완전히 다른 계층(Layer)에서 작동합니다.

| | Karpathy Guidelines (통제) | gstack (확장) |
|---|---|---|
| **설계 목표** | AI가 얼마나 **덜** 하게 만들 것인가? | AI가 얼마나 **더** 할 수 있게 만들 것인가? |
| **핵심 문제** | 과잉 구현, 임의 리팩토링 방지 | 단일 에이전트의 제한된 컨텍스트 한계 극복 |
| **작동 방식** | 단일 에이전트 내부의 **행동 원칙** | 여러 에이전트 간의 **협업(역할) 구조** |

즉, **gstack**으로 "어떤 역할을 분담할지" 오케스트레이션하고, 그 역할을 수행하는 각각의 에이전트는 **Karpathy 가이드라인**의 행동 원칙을 따르도록 설계하는 것이 가장 이상적입니다.

---

## 🛑 2. 계층 1: 에이전트 행동 통제 (Karpathy Guidelines)

Andrej Karpathy의 관찰에서 출발한 가이드라인은 AI가 흔히 저지르는 실수를 방지하는 4원칙을 제시합니다.

1. **Think Before Coding (코딩 전 생각하기):** 모호한 요청에 대충 코드를 짜지 말고 질문하게 만듭니다.
2. **Simplicity First (단순함 최우선):** "나중을 위한" 불필요한 추상화나 기능 추가를 차단합니다.
3. **Surgical Changes (외과적 변경):** 수정이 필요한 라인만 건드리고 주변 구역을 함부로 리팩토링하지 못하게 합니다.
4. **Goal-Driven Execution (목표 주도 실행):** 막연한 작업 대신 검증 가능한 테스트를 통과하는 형태의 목표를 설정합니다.

### 💡 Antigravity 적용: Global SKILL 등록
이 가이드라인은 모든 에이전트가 기본적으로 장착해야 하는 '기본 소양'입니다. Antigravity의 기본 시스템 프롬프트나 전역 Custom Skill로 등록해 둡니다.

---

## 🛠️ 3. 계층 2: 에이전트 역할 확장 (gstack 프레임워크)

YC CEO Garry Tan이 공개한 gstack은 기존의 "AI야 전부 만들어줘"라는 접근법을 버립니다. 대신 AI를 CEO, 엔지니어링 매니저, 디자이너, QA 등으로 **역할별로 분리**합니다.

한 명의 에이전트에게 모든 것을 맡기면 평균적인 결과만 나옵니다. 하지만 역할을 세분화하면 각 역할별로 **특화된 검증 기준**이 적용됩니다. 

- **CEO 역할**은 "이 기능이 사용자에게 가치가 있나?"를 비판적으로 평가합니다.
- **QA 역할**은 오직 시스템이 망가지지 않았는지 동작 검증에만 집중합니다.
- **보안 Officer 역할**은 OWASP 기준에 맞는 감사만 수행합니다.

### 💡 Antigravity 적용: 페르소나별 SKILL 분리
Antigravity에서는 역할 수만큼 개별 Custom SKILL을 생성하여 이를 구현할 수 있습니다. 예를 들어, 보안 전담 SKILL은 다음과 같이 작성할 수 있습니다.

```markdown
# Antigravity SKILL: security-officer
당신은 보안 감사 전문가입니다. 기능 개선이나 리팩토링은 제안하지 않습니다.
오로지 다음 기준에 의거하여 코드를 감사하십시오:
1. OWASP Top 10 (인젝션, 민감 데이터 노출 등)
2. 하드코딩된 시크릿 키 존재 여부
3. 클라이언트 신뢰 문제 (서버사이드 치트 방어 로직)
발견된 사항은 [CRITICAL / HIGH / MEDIUM]으로 분류하여 보고합니다.
```

---

## 🚀 4. 최종 워크플로우 실전 가이드

두 가지 개념을 합친 완벽한 Antigravity 실무 워크플로우는 다음과 같이 진행됩니다.

1. **[기획] `product-reviewer` SKILL 호출:** 
   사용자 가치를 평가받습니다. (Karpathy 1원칙: 불필요한 구현인지 먼저 생각하기 적용됨)
2. **[설계] `arch-reviewer` SKILL 호출:**
   아키텍처 영향도를 평가받습니다. (Karpathy 2원칙: 오버엔지니어링 방지 규칙 적용됨)
3. **[구현] Antigravity에 개발 지시:**
   개발이 진행됩니다. (Karpathy 3/4원칙: 외과적 변경 및 목표 기반 실행 적용됨)
4. **[보안] `security-officer` SKILL 호출:**
   개발된 코드의 취약점을 집중 감사합니다.
5. **[QA] `qa-checklist` SKILL 호출:**
   UI 및 회귀 테스트 동작을 확인합니다.

## 💻 5. 실습: 토이 프로젝트로 알아보는 통합 워크플로우

간단한 **브라우저 기반 메모장 웹앱**을 만든다고 가정해 보겠습니다. 이 워크플로우가 얼마나 강력한 차이를 만드는지 실전 흐름을 따라가 봅니다.

### 시나리오: "메모장 앱을 만들어줘."

**[잘못된 접근 (기본 AI)]**
- AI가 임의로 React 프레임워크를 세팅합니다.
- 묻지도 않고 Firebase 연동 코드를 작성해버립니다.
- 다크모드, 애니메이션 등 요구하지 않은 피처를 마구 추가하여 500줄짜리 복잡한 코드를 던져줍니다.

### [올바른 접근 (Karpathy + gstack 적용)]

**1단계: 전역 통제 (Karpathy 적용)**
모든 에이전트는 이미 '명시되지 않은 기능 추가 금지'와 '단순함 최우선' 규칙을 탑재하고 있습니다.

**2단계: `product-reviewer` SKILL (기획 검토)**
> **Me**: "메모장 앱을 웹용으로 만들어줘."
> **Product-Reviewer**: "메모가 브라우저를 닫아도 유지되어야 하나요? 사용자 로그인이나 클라우드 동기화가 필요한가요?"
> **Me**: "아니, 그냥 내 브라우저에서만 유지되면 돼."

**3단계: `arch-reviewer` SKILL (아키텍처 결정)**
> **Arch-Reviewer**: "클라우드가 필요 없고 브라우저에서만 동작한다면, React나 DB 서버는 오버엔지니어링(Over-engineering)입니다. 단일 HTML 파일에 Vanilla JS와 `LocalStorage`만 사용하는 것이 원칙에 맞습니다. 그렇게 진행할까요?"
> **Me**: "좋아."

**4단계: 구현 및 `code-reviewer` SKILL (코드 리뷰)**
> **Code-Reviewer**: "작성된 코드를 리뷰했습니다. 사용자가 매우 긴 텍스트를 입력했을 때 레이아웃이 깨지는 문제가 발생할 수 있어 `word-wrap: break-word;` 등의 외과적(Surgical) 수정만 반영해 두었습니다. 다른 기존 로직은 건드리지 않았습니다."

**5단계: `qa-checklist` SKILL (최종 테스트)**
> **QA-Checklist**: 
> - [x] 메모 텍스트 입력 후 저장 버튼 클릭 시 추가되는가?
> - [x] 브라우저 새로고침 시 이전에 작성한 메모가 남아있는가? (LocalStorage 검증)
> - [x] 삭제 버튼 클릭 시 정확히 해당 메모만 삭제되는가?

---

## 🎯 결론

**단순함이 전문성을 만듭니다.**
Karpathy 가이드라인으로 AI의 무분별한 코드 생성을 억제하고, gstack의 역할 분리 방법론을 통해 전문성을 확장하십시오. 

AI 시대에 1인 개발자가 20인 팀의 퍼포먼스를 낼 수 있는 비밀은, 얼마나 비싼 모델을 쓰느냐가 아니라 **어떤 규칙과 절차로 에이전트를 통제하고 조정하느냐**에 달려 있습니다.
