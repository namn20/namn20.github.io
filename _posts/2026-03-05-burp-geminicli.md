---
layout: post
title: "[보안 가이드] Burp Suite + Gemini CLI 연동: AI 기반 취약점 분석 환경 구축 완벽 가이드"
date: 2026-03-05
categories: [Security, PenTest]
tags: [burpsuite, gemini, ai, pentest, vulnerability, mcp]
---

Burp Suite의 강력한 웹 프록시 기능과 Google Gemini의 AI 분석 능력을 결합하면, 반복적인 취약점 분석 작업을 자동화하고 펜테스터의 생산성을 크게 높일 수 있습니다. 본 포스팅에서는 **실제 Burp Suite 메뉴 경로 및 클릭 순서**를 중심으로 두 도구의 연동 방법을 상세하게 안내합니다.

---

## 1. Gemini CLI API 키, 꼭 필요한가?

> **결론: 개인 사용 시 API 키 없이 Google 계정 인증만으로 사용 가능합니다.**

Gemini CLI는 두 가지 인증 방식을 지원합니다.

| 방식 | 명령어 | 특징 |
|---|---|---|
| **Google 계정 OAuth** (권장) | `gemini auth login` | API 키 불필요. 개인 Google 계정으로 브라우저 로그인. 무료 사용량 포함. |
| **API 키** | 환경변수 `GEMINI_API_KEY` 설정 | Google AI Studio에서 키 발급 필요. 서버/자동화 배포 환경에 적합. |

- **개인/테스트 환경**: `gemini auth login` 만으로 충분합니다.
- **서버/CI 환경 또는 Burp 확장에서 인증 오류 발생 시**: [Google AI Studio](https://aistudio.google.com/app/apikey)에서 API 키를 발급받아 환경 변수로 등록하세요.

```bash
# Windows (PowerShell) - API 키 사용 시
$env:GEMINI_API_KEY = "your_api_key_here"

# Linux / macOS
export GEMINI_API_KEY="your_api_key_here"
```

---

## 2. 사전 요구사항 (Prerequisites)

- **Burp Suite**: Community 또는 Professional 버전
  - BApp Store 확장 설치에는 Professional 버전이 더 안정적입니다.
- **Node.js**: v18 이상 권장 (Gemini CLI 설치 필요)
- **Google 계정**: Gemini 인증용

---

## 3. Gemini CLI 설치 및 인증

### Step 3-1. Gemini CLI 설치

터미널(PowerShell 또는 cmd)을 열고 아래 명령어를 실행합니다.

```bash
npm install -g @google/gemini-cli
```

### Step 3-2. Google 계정 인증 (OAuth 방식)

```bash
gemini auth login
```

명령어 실행 시 브라우저가 자동으로 열리며, 사용할 Google 계정으로 로그인 후 **"허용"** 버튼을 클릭하여 접근 권한을 부여합니다.

### Step 3-3. 작동 검증

```bash
gemini "hello"
```

Gemini의 정상적인 답변이 터미널에 출력되면 설치 및 인증이 완료된 것입니다.

---

## 4. Burp Suite AI Agent 확장 설치

### 방법 A: BApp Store에서 설치 (네트워크 허용 환경)

1. Burp Suite를 실행합니다.
2. 상단 탭에서 **[Extensions]** 를 클릭합니다.
   - *구버전(v2023 이전)의 경우 **[Extender]** 탭*
3. 하위 탭 중 **[BApp Store]** 를 선택합니다.
4. 검색창에 `AI Agent` 또는 `Burp AI Agent`를 입력하여 검색합니다.
5. 검색 결과에서 해당 확장을 클릭하고 우측의 **[Install]** 버튼을 눌러 설치합니다.
6. 설치 완료 후 상단에 **[AI Agent]** 탭이 새로 생성되면 성공입니다.

---

### 방법 B: 수동 설치 (방화벽으로 BApp Store 접근 불가 시)

회사 방화벽이나 네트워크 정책으로 인해 BApp Store에 접근이 차단되는 경우, 아래 방법으로 수동 설치합니다.

#### ① 확장 파일 외부망에서 다운로드

외부 인터넷이 가능한 환경(개인 PC, 스마트폰 핫스팟 등)에서 아래 경로에 접근하여 `.bapp` 또는 `.jar` 파일을 다운로드합니다.

- **GitHub 저장소**: `https://github.com/PortSwigger/burp-ai-agent` (또는 검색: `burp ai agent github`)
- Releases 탭에서 최신 버전의 `.jar` 파일을 다운로드합니다.

#### ② Burp Suite에 수동 로드

1. Burp Suite 실행 → 상단 탭 **[Extensions]** 클릭.
2. 하위 탭 **[Installed]** 선택.
3. 우측 상단의 **[Add]** 버튼 클릭.
4. 아래와 같이 설정 후 **[Next]** 클릭:
   - **Extension type**: `Java`
   - **Extension file (.jar)**: 다운로드한 `.jar` 파일 경로 선택 (예: `C:\Downloads\burp-ai-agent.jar`)
5. Output 탭에 오류 없이 로드 메시지가 나타나면 설치 성공.
6. 이후 상단에 **[AI Agent]** 탭이 생성됩니다.

> **Tip**: 사내 Proxy(예: Zscaler, Blue Coat)를 우회해야 하는 경우, Burp Suite 실행 전 사내 프록시를 잠시 비활성화하거나 IT팀에 `portswigger.net` 도메인 화이트리스트 등록을 요청하세요.

---

## 5. Gemini CLI 백엔드 연결 설정 (메뉴 기준 상세)

### Step 5-1. AI Backend 설정 메뉴 이동

1. 상단 탭에서 **[AI Agent]** 탭을 클릭합니다.
2. AI Agent 탭 내 하위 탭 또는 패널에서 **[Settings]** 또는 **[Configuration]** 을 선택합니다.
3. **[AI Backend]** 섹션을 찾습니다.

### Step 5-2. Gemini CLI 백엔드 등록

**[Add]** 또는 **[New Backend]** 버튼을 클릭하고 아래 값을 입력합니다.

| 항목 | 값 | 설명 |
|---|---|---|
| **Backend Name** | `Gemini CLI` | 식별용 이름 (자유 입력) |
| **Backend Type** | `Custom Command` | CLI 도구 직접 호출 방식 선택 |
| **Command** | `gemini` | 터미널에서 실행되는 CLI 명령어 |
| **Args** | `"{prompt}"` | 프롬프트 전달 인자. 확장 버전에 따라 `-p {prompt}` 형태일 수 있음 |
| **Env** | *(비워둠)* | OAuth 인증 사용 시 불필요. API 키 방식이면 `GEMINI_API_KEY=your_key` 입력 |

### Step 5-3. 연결 테스트

- 설정 완료 후 **[Test Connection]** 버튼 클릭.
- 하단 출력창에 `Using Gemini CLI` 또는 `Connection successful` 메시지가 출력되면 연동 성공!

---

## 6. 실전 활용 방법

### 6-1. Proxy에서 HTTP 요청 AI 분석

1. 상단 탭 **[Proxy]** → 하위 탭 **[HTTP history]** 로 이동합니다.
2. 분석할 HTTP 요청 항목을 **우클릭**합니다.
3. 컨텍스트 메뉴(Context Menu)에서 **[Extensions]** → **[AI Agent]** → **[Analyze Request]** 를 선택합니다.
4. 프롬프트 입력창이 열리면 원하는 분석 내용을 입력합니다.

```
이 HTTP 요청에서 SQL Injection, XSS, IDOR 취약점 가능성을 분석하고,
발견된 취약점별로 위험도와 공격 시나리오를 설명해줘.
```

5. Gemini CLI가 백엔드에서 자동 호출되어 분석 결과를 반환합니다.

### 6-2. Repeater에서 반복 분석

1. **[Repeater]** 탭에서 수정한 요청을 보낸 후, 응답(Response)을 우클릭합니다.
2. **[Extensions]** → **[AI Agent]** → **[Analyze Response]** 선택.
3. 응답 내 민감 정보 노출, 에러 메시지 패턴 등을 Gemini가 자동으로 분석합니다.

### 6-3. Intruder 페이로드 추천

1. **[Intruder]** 탭에서 공격 대상 파라미터를 설정한 뒤,
2. **[AI Agent]** 탭으로 이동하여 **[Generate Payloads]** 기능을 사용합니다.
3. Gemini가 해당 파라미터 유형에 적합한 취약점 페이로드 목록을 자동 생성합니다.

### 6-4. MCP 트래픽 모니터링

Gemini CLI가 외부 MCP(Model Context Protocol) 서버와 통신할 때, Burp Proxy를 통해 해당 아웃바운드 트래픽을 인터셉트하여 분석할 수 있습니다.

1. **[Proxy]** → **[Options]** → **[Proxy Listeners]** 확인 (기본: `127.0.0.1:8080`).
2. 브라우저 또는 Gemini CLI의 네트워크 설정에서 프록시를 `127.0.0.1:8080`으로 지정합니다.
3. **[Proxy]** → **[Intercept]** 탭에서 MCP 관련 요청/응답 패킷을 실시간으로 확인합니다.

---

## 7. 자주 겪는 문제 해결 (Troubleshooting)

### ❌ 인증 오류 (Authentication Error)

```bash
# 터미널에서 재인증 실행
gemini auth login
```

인증 토큰 만료 또는 권한 변경 시 발생합니다. 위 명령어로 재인증 후 Burp에서 연결 테스트를 다시 진행하세요.

### ❌ Gemini CLI를 찾을 수 없음 (Command not found)

Burp Suite가 `gemini` 명령어를 인식하지 못하는 경우, **전체 경로를 지정**합니다.

```bash
# Windows에서 gemini.cmd 위치 확인
where gemini

# 반환 예시: C:\Users\username\AppData\Roaming\npm\gemini.cmd
```

확인된 전체 경로를 AI Backend 설정의 **Command** 항목에 입력하세요.

(`C:\Users\username\AppData\Roaming\npm\gemini.cmd`)

### ❌ 포트 충돌 (Port Conflict)

- Burp Proxy 기본 포트는 **8080** 입니다.
- **[Proxy]** → **[Options]** → **[Proxy Listeners]** 에서 현재 사용 포트를 확인하고, 다른 서비스와 충돌 시 포트 번호를 변경하세요.
- 브라우저 프록시 설정도 동일하게 `127.0.0.1:<변경된포트>`로 업데이트합니다.

### ❌ BApp Store 접속 불가 (방화벽 차단)

위 **방법 B (수동 설치)** 섹션을 참고하여 외부망에서 `.jar` 파일을 다운로드 후 수동으로 로드합니다. 또한 사내 IT 보안팀에 아래 도메인의 화이트리스트 등록을 요청할 수 있습니다.

- `portswigger.net`
- `bappstore.portswigger.net`

### ❌ 확장 프로그램 오류 또는 호환성 문제

- **[Help]** → **[Check for Updates]** 에서 Burp Suite 버전을 최신으로 업데이트합니다.
- GitHub의 AI Agent 저장소 **Issues** 탭에서 동일 오류 사례를 검색합니다.
- Extension Output 로그: **[Extensions]** → **[Installed]** → 해당 확장 선택 → **[Output]** / **[Errors]** 탭에서 상세 오류 메시지를 확인합니다.

---

## 마치며

Burp Suite와 Gemini CLI의 연동은 단순한 도구 결합을 넘어, **AI가 실시간으로 HTTP 트래픽을 분석하고 취약점을 제안하는 차세대 펜테스트 워크플로우**를 가능하게 합니다. 특히:

- **취약점 자동 분류**: 수백 개의 요청 중 위험한 것을 AI가 먼저 걸러줍니다.
- **페이로드 자동 생성**: 공격 시나리오에 맞는 페이로드를 즉시 추천받을 수 있습니다.
- **MCP 통신 가시화**: Gemini의 외부 API 호출을 Burp로 모니터링함으로써 AI 툴 자체의 보안 감사도 가능합니다.

방화벽 등 제약이 있는 환경에서도 수동 설치 방법을 활용하면 충분히 구축할 수 있으니, 단계별로 따라해보시기 바랍니다!
