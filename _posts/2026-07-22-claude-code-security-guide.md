---
title: Claude Code 보안 가이드 - 안전한 AI 코딩 에이전트 설정과 베스트 프랙티스
date: 2026-07-22 19:30:00 +0900
categories: [AI & Automation, Security]
tags: [claude-code, security, ai, devsecops, configuration]
---

# Claude Code 보안 가이드: 안전한 AI 코딩 에이전트 설정과 베스트 프랙티스

Claude Code는 Anthropic에서 개발한 강력한 CLI 기반 AI 코딩 에이전트입니다. 터미널에서 직접 명령을 실행하고, 코드를 수정하며, 테스트를 수행할 수 있어 생산성을 극대화합니다. 

하지만 강력한 만큼 보안상의 주의도 필요합니다. Claude Code는 **실행하는 사용자의 권한을 그대로 상속받기 때문에**, 제대로 격리하거나 제어하지 않으면 의도하지 않은 명령어 실행이나 민감한 파일 노출 등의 위험(예: 프롬프트 인젝션, 패키지 의존성 오염 등)이 발생할 수 있습니다.

이 글에서는 Claude Code를 안전하게 사용하기 위한 **보안 설정 모델, 핵심 구성 옵션, 그리고 실무적인 격리/강화 방안**을 정리합니다.

---

## 1. Claude Code 설정 구조 및 우선순위 (Configuration Scopes)

Claude Code의 설정 파일(`settings.json`)은 관리 범위와 공유 목적에 따라 계층적으로 적용됩니다. 높은 우선순위의 설정이 낮은 우선순위 설정을 덮어씁니다.

| 우선순위 | 구분 (Scope) | 저장 경로 / 방식 | 용도 및 특징 |
| :--- | :--- | :--- | :--- |
| **1 (가장 높음)** | **Managed** | 시스템 디렉터리 (`managed-settings.json`) | 조직/기업 레벨의 강제 정책. 개별 사용자가 재정의 불가능. |
| **2** | **Session CLI** | 터미널 실행 시의 명령줄 인수 | 일시적 세션용 오버라이드. |
| **3** | **Local Project** | `.claude/settings.local.json` | 개인 맞춤형 프로젝트 설정. **Git Ignore 권장** (API Key, 개인 경로 등). |
| **4** | **Shared Project** | `.claude/settings.json` | 프로젝트 팀원 공용 설정. **Git Repository에 커밋/공유**. |
| **5 (가장 낮음)** | **User Global** | `~/.claude/settings.json` | 사용자 전역 기본 설정. 모든 프로젝트에 공통 적용. |

> [!TIP]
> 프로젝트 공용 설정(`.claude/settings.json`)에 기본 보안 규칙을 정의해 두고, 개발자 개개인의 개발 환경 특성에 따른 예외 사항은 `.claude/settings.local.json`에 정의하는 것을 추천합니다.

---

## 2. 권한 제어 시스템 (Permissions: Allow vs Deny)

Claude Code는 도구(Tool) 및 Bash 명령어 실행 시 **Deny(거부) → Ask(질문) → Allow(허용)** 순으로 규칙을 엄격하게 평가합니다. 

*   **Deny (최우선)**: 설정된 패턴에 부합하면 사용자 확인 없이 즉시 차단합니다.
*   **Ask (기본값)**: 실행 전에 사용자에게 동의를 요구합니다.
*   **Allow**: 승인 프롬프트 없이 자동으로 명령을 수행합니다.

### 🔒 추천하는 `settings.json` 보안 차단(Deny) 및 허용(Allow) 설정 예시

```json
{
  "$schema": "https://json-schema.org/claude-code-settings.json",
  "permissions": {
    "deny": [
      "Bash(rm -rf *)",
      "Bash(curl *)",
      "Bash(wget *)",
      "Bash(sudo *)",
      "Bash(chmod *)",
      "Bash(chown *)",
      "read_file(./.env)",
      "read_file(./.env.*)",
      "read_file(~/.ssh/*)",
      "read_file(~/.aws/*)"
    ],
    "allow": [
      "Bash(npm run lint)",
      "Bash(npm run test *)",
      "Bash(git diff)",
      "Bash(git status)"
    ]
  }
}
```

### 🛠️ 권한 관리 관련 주요 CLI 명령어
*   `/permissions`: 인터랙션 UI를 띄워 현재 활성화된 권한 규칙을 확인하고 관리합니다.
*   `/config`: 설정 옵션을 탭 인터페이스로 조회/수정하거나, 단일 설정을 업데이트(`config key=value`)합니다.
*   `/status`: 수정된 설정 파일이 정상적으로 로드되었는지 최종 확인합니다.

---

## 3. Auto Mode(자동 모드) 보안 매커니즘

Claude Code의 `Auto mode`는 별도의 승인 프롬프트 없이 AI가 연속적인 작업을 자율적으로 수행하게 만듭니다. 이 모드에서는 백그라운드의 **AI Safety Classifier(안전 분류기)**가 위험도를 실시간으로 평가합니다.

### 🛡️ Auto Mode의 기본 보안 제약 사항
*   **작업 영역 제한**: 기본적으로 현재 작업 디렉터리(CWD)와 설정된 리포지토리의 원격(Remote) 경로만 신뢰합니다.
*   **고위험 작업 원천 차단**: 
    *   대규모 파일 삭제 또는 클라우드 스토리지 리소스 삭제 행위.
    *   민감한 데이터나 자격 증명을 외부 엔드포인트로 전송 시도.
    *   운영 환경 배포(Production Deployment), 데이터베이스 마이그레이션.
    *   `main` 브랜치로의 직접 푸시 또는 강제 푸시(`force push`).
    *   스크립트를 다운로드하여 즉시 셸로 실행하는 형태 (`curl | bash`).
*   **오버라이드 순서**: 개발자가 명시한 `deny` 규칙과 프롬프트 상의 구체적인 금지 지시(예: *"절대로 빌드 스크립트를 수정하지 마"*)는 분류기보다 우선하여 작동합니다.
*   **확인 명령어**: 터미널에서 `claude auto-mode defaults`를 실행하면 자동 모드 활성화 시 적용되는 기본 룰을 점검할 수 있습니다.

---

## 4. 격리를 통한 보안 극대화 (Hardening Best Practices)

설정 파일의 Deny 룰만으로는 완벽한 보안 경계를 보장하기 어렵습니다. 악의적인 프롬프트 인젝션이나 예기치 못한 패키지 취약점으로 인한 탈취를 방지하기 위해 **방어적인 샌드박스 설계(Defense-in-depth)**가 필수적입니다.

### ① 내장 샌드박스 (`/sandbox`) 활용
`/sandbox` 명령어를 사용하여 Claude Code 세션을 시작하면, 파일 시스템 및 네트워크 접근이 물리적으로 분리된 샌드박스 환경 내에서만 Bash 명령이 실행되므로 호스트 시스템을 안전하게 지킬 수 있습니다.

### ② 개발 컨테이너 (Dev Containers / Docker) 도입
가장 추천하는 방법은 프로젝트 자체를 VS Code Dev Container나 Docker 환경 내에서 실행하는 것입니다.
*   호스트의 개인 SSH 키, 클라우드 자격 증명(AWS/Azure 등)이 에이전트에 노출되지 않도록 환경 변수와 볼륨 마운트를 제한합니다.
*   비루트(`non-root`) 사용자로 컨테이너를 가동하여 에이전트가 시스템 설정을 임의로 수정하는 것을 방지합니다.

### ③ MCP(Model Context Protocol) 서버 권한 최소화
외부 도구와 연동해 주는 MCP 서버를 등록할 때도 최소 권한 원칙을 고수해야 합니다.
*   신뢰할 수 없는 타사 MCP 서버의 설치를 지양합니다.
*   도메인이나 특정 실행 파일 경로를 명시하여 접근 가능한 범위를 엄격히 제한합니다.

---

## 5. 보안 점검 체크리스트 (Summary)

Claude Code를 사내 인프라 또는 상용 프로젝트에 도입하기 전에 아래 체크리스트를 점검하세요.

- [ ] `.env` 파일과 SSH 디렉터리가 `deny` 룰에 포함되어 있는가?
- [ ] `.claude/settings.local.json` 파일이 `.gitignore`에 등록되어 로컬 전용으로 격리되었는가?
- [ ] 에이전트 실행 환경의 OS 사용자 권한이 `root` 또는 `Administrator`가 아닌 일반 사용자 권한인가?
- [ ] 운영 브랜치(`main`/`master`)로의 직접 푸시 권한이 차단되어 있고, Pull Request를 통한 코드 리뷰 단계를 거치는가?
- [ ] 필요한 경우 IT 부서에서 `managed-settings.json`을 통해 전사 공통 보안 규칙을 배포했는가?

---

> Claude Code는 뛰어난 성능을 자랑하는 개발 파트너이지만, 사용 시에는 **"능력은 출중하지만 아직 보안 인식이 부족한 인턴 개발자"**를 대하듯 꼼꼼한 코드 검증과 권한 경계 설계가 동반되어야 안전하게 그 혜택을 누릴 수 있습니다.
