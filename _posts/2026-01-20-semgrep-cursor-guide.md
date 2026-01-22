---
layout: post
title: "[전문가 칼럼] 차세대 AppSec 아키텍처: Git 기반 Semgrep 파이프라인과 Cursor AI를 활용한 정오탐(False Positive) 판별 전략"
date: 2026-01-20
categories: [AI & Automation, Security AI]
tags: [semgrep, cursor, ci-cd, sast, triage]
author: "Security Architect"
---

## 서론: "보안은 속도를 늦추는 걸림돌이 아니다"

반갑습니다. 오늘은 현대적인 애플리케이션 보안(AppSec) 아키텍처의 핵심인 **'지속적 검증(Continuous Verification)'** 모델에 대해 논의해보고자 합니다.

 과거의 보안 검수는 개발이 끝난 후 별도로 수행되는 '병목(Bottleneck)' 구간이었습니다. 하지만 DevOps 시대에 이러한 방식은 더 이상 유효하지 않습니다. 오늘은 코드가 리포지토리에 푸시(Push)되거나 병합(Merge)되는 시점에 **Semgrep**을 통해 자동으로 취약점을 탐지하고, 그 결과를 **Cursor AI**를 통해 심층 분석하여 정오탐(False Positive)을 판별하는, 이른바 **'AI 기반 능동형 보안 파이프라인(AI-Augmented Proactive Security Pipeline)'**을 설계해보도록 하겠습니다.

---

## 1. 아키텍처 개요 (The Architecture)

우리가 구축할 시스템의 흐름은 다음과 같습니다.

1.  **Trigger Event**: 개발자가 코드를 작성하여 Git에 `Push` 하거나 `Merge Request (PR)`를 생성합니다.
2.  **Automated Detection Layer (CI/CD)**: CI 파이프라인이 트리거되며 **Semgrep**이 실행됩니다. 이때 규칙 기반(Rule-based) 엔진이 1차적으로 잠재적 위협을 식별합니다.
3.  **Triage & Remediation Layer (AI-Assisted)**: 탐지된 결과(Artifact)를 **Cursor** 환경으로 가져와, AI 에이전트와 함께 실제 위협인지 단순 오진단(False Positive)인지 판별하고 조치합니다.

이 구조는 보안 도구의 고질적인 문제인 '오탐 피로(Alert Fatigue)'를 AI의 문맥 이해 능력으로 획기적으로 줄이는 데 그 목적이 있습니다.

---

## 2. 탐지 계층 구현: Git 이벤트와 Semgrep CI 연동

보안 아키텍처에서 가장 중요한 것은 **'가시성(Visibility)'의 시점**입니다. 코드가 머지되기 전에 문제를 발견해야 수정 비용이 최소화됩니다. 이를 'Shift Left' 전략이라 부릅니다.

### Semgrep CI 파이프라인 설계

Github Actions나 GitLab CI와 같은 CI 도구에서 Semgrep은 다음과 같이 구성되어야 합니다. 단순히 실행하는 것을 넘어, 파이프라인을 중단(Block)시킬지 경고(Audit)만 줄지 정책적 결정이 필요합니다.

**CI 설정 예시 (개념적 코드):**

```yaml
# 보안 검수는 'Push'와 'PR' 단계에서 필수적으로 수행되어야 함
on:
  push:
    branches: ["main", "develop"]
  pull_request:

jobs:
  semgrep-security-scan:
    runs-on: ubuntu-latest
    container:
      image: semgrep/semgrep
    steps:
      - uses: actions/checkout@v3
      
      # 1. Semgrep 실행 및 결과를 JSON으로 출력
      # 단순히 텍스트를 터미널에 뿌리는 것에 그치지 않고, 
      # 데이터를 구조화(Structured Data)하여 후처리할 수 있어야 함.
      - name: Run Semgrep
        run: semgrep scan --config=p/security-audit --json > semgrep-results.json
        
      # 2. 결과 리포트를 아티팩트로 저장 (추후 Cursor 분석용)
      - name: Upload Scan Artifact
        uses: actions/upload-artifact@v3
        with:
          name: semgrep-report
          path: semgrep-results.json
```

**교수의 조언 (Professor's Note):**
> "실무에서는 `p/default` 룰셋만으로는 부족합니다. 조직의 비즈니스 로직에 특화된 **Custom Rule**을 작성하여 적용하는 것이 진정한 의미의 SAST 활용입니다. CLI 단계에서 JSON 출력을 저장해두는 것은 추후 데이터 분석을 위한 필수적인 단계임을 명심하십시오."

---

## 3. 판별 계층 구현: Cursor를 활용한 AI 정오탐 분석 (Triage)

자, 이제 파이프라인이 경고를 뱉어냈습니다. 수백 개의 경고 중 진짜 위험한 것은 무엇일까요? 여기서 우리는 **Cursor**라는 강력한 AI 도구를 '보안 분석가(Security Analyst)'의 보조 도구로 활용합니다.

SAST 도구는 문법적 패턴을 매칭하는 데에는 탁월하지만, **'코드의 의도(Intent)'**나 **'외부 맥락(Context)'**을 이해하는 데에는 한계가 있어 오탐(False Positive)이 필연적으로 발생합니다.

### 워크플로우: AI 기반 정오탐 판별 프로세스

1.  **Artifact 로드**: CI에서 생성된 `semgrep-results.json` 파일을 Cursor 프로젝트 루트에 배치합니다.
2.  **Context 주입**: Cursor의 Chat 기능(또는 Composer)을 열고, Semgrep 결과 파일과 소스 코드를 동시에 참조시킵니다.
3.  **AI 질의 (Prompt Engineering)**:

    > **전문가 프롬프트 예시:**
    >
    > "지금 `semgrep-results.json`에서 ID `vuln-1`로 탐지된 SQL Injection 취약점을 봐주게.
    > 관련된 소스 코드 파일(`user_dao.py`)을 분석해서, 실제로 입력값 검증이 누락되어 공격 가능한 상태인지(True Positive),
    > 아니면 상위 함수에서 이미 Sanitization을 수행하고 있어 안전한 상태인지(False Positive) 논리적으로 판단해서 설명해주게."

### 정오탐 판별 기준 (Evaluation Criteria)

보안 아키텍트로서 판별 시 다음 세 가지를 AI에게 확인시켜야 합니다.

1.  **도달 가능성 (Reachability)**: 외부의 사용자 입력(Untrusted Input)이 해당 취약 코드까지 실제로 도달할 수 있는가?
2.  **완화 조치 유무 (Mitigation)**: 프레임워크 레벨이나 미들웨어에서 이미 방어 로직이 적용되어 있는가?
3.  **영향도 (Impact)**: 해당 취약점이 악용되었을 때 실제로 비즈니스에 영향이 있는가?

Cursor AI는 전체 프로젝트의 파일 간 참조 관계를 파악할 수 있으므로, 단순 스크립트보다 훨씬 정확하게 "이 변수는 `Filter()` 함수를 거쳐 왔으므로 안전합니다"와 같은 추론을 내릴 수 있습니다.

---

## 4. MCP(Model Context Protocol)를 통한 미래의 보안 관제

현재는 개발자가 수동으로 JSON을 옮겨서 질문해야 하지만, 여러분이 질문했던 **MCP**가 도입되면 이 과정은 아키텍처적으로 완전히 통합됩니다.

*   **As-Is**: CI 결과 다운로드 -> Cursor에 업로드 -> 질의
*   **To-Be (with MCP)**: Cursor가 MCP 프로토콜을 통해 사내 CI 서버나 SonarQube, DefectDojo 같은 취약점 관리 시스템에 **직접 접속**.
    *   AI가 *"최근 빌드에서 실패한 보안 항목 가져와"* 라고 명령하면, MCP 서버가 Semgrep 리포트를 반환하고, AI가 즉시 에디터에서 해당 코드 라인을 띄우며 *"이 부분은 오탐이므로 예외 처리하겠습니다"*라고 제안하는 구조가 됩니다.

---

## 결론 (Conclusion)

보안은 도구를 많이 깐다고 강화되는 것이 아닙니다. **탐지된 위협을 얼마나 빠르고 정확하게 소화(Digest)하느냐**가 핵심입니다.

Git 이벤트 기반의 **Semgrep** 자동화가 '빈틈없는 감시자'라면, **Cursor**는 그 감시 결과를 해석하는 '지혜로운 조언자'입니다. 이 두 축을 결합하여 오탐에 허덕이는 보안 팀이 아니라, 비즈니스 로직의 결함을 꿰뚫어 보는 **Security Architect**의 관점을 가지시길 바랍니다.


