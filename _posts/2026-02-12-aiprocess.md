---
title: "소스코드 보안성 검토를 위한 Architect Agent 구축 가이드"
date: 2026-02-12 17:00:00 +0900
categories: [AI & Automation, AI Security]
categories: [AI & Automation, AI Security]
tags: [ai, process, automation, security]
---

소스코드 보안성 검토 프로세스에서 **첫 번째 에이전트인 Architect Agent**는 코드의 전체 구조를 파악하고, 이후 단계의 에이전트(취약점 분석, 비즈니스 로직 검토 등)가 효과적으로 작동할 수 있는 기반 정보를 생성하는 역할을 합니다. 이 글에서는 Architect Agent를 설계하고 구축하는 방법을 단계별로 안내합니다.

---

## 🎯 Architect Agent란?

Architect Agent는 소스코드 검토 파이프라인의 **1단계 에이전트**로, 코드를 직접 분석하기 전에 **"이 코드는 어떤 구조로 이루어져 있는가?"**를 먼저 파악합니다.

### 왜 구조 확인이 먼저인가?

보안 전문가가 소스코드를 검토할 때도, 가장 먼저 하는 일은 **전체 구조를 파악**하는 것입니다.

- 어떤 프레임워크를 사용하는가?
- 인증/인가 로직은 어디에 위치하는가?
- 외부 API 통신은 어디서 발생하는가?
- 민감 데이터(DB, 파일, 환경변수)에 접근하는 경로는?

이 정보 없이 바로 취약점 스캐닝을 시작하면, **탐지 범위 누락**이나 **오탐(False Positive)**이 급증합니다.

---

## 🏗️ 멀티 에이전트 파이프라인에서의 위치

```
┌─────────────────────────────────────────────────────────────────┐
│                  소스코드 보안성 검토 파이프라인                    │
├─────────────┬──────────────┬──────────────┬─────────────────────┤
│  1단계       │  2단계        │  3단계        │  4단계              │
│  Architect   │  Vulnerability│  Business    │  Report             │
│  Agent       │  Agent        │  Logic Agent │  Agent              │
│  (구조 분석)  │  (취약점 탐지) │  (비즈니스    │  (보고서 생성)       │
│              │               │   로직 검토)  │                     │
└──────┬───────┴───────┬───────┴──────┬───────┴──────────┬──────────┘
       │               │              │                  │
       ▼               ▼              ▼                  ▼
  구조 맵 생성    SAST/패턴 매칭   인증·인가 흐름 검증   최종 보고서
  기술 스택 식별   의존성 취약점    데이터 흐름 추적     위험도 분류
  진입점 목록화    시크릿 탐지     권한 검증 로직 검토   개선 권고안
```

> Architect Agent의 **출력(Output)**이 후속 에이전트들의 **입력(Input)**이 됩니다.

---

## 📋 Architect Agent의 핵심 역할 5가지

### 1. 프로젝트 메타데이터 수집

프로젝트의 기본 정보를 자동으로 식별합니다.

| 수집 항목 | 방법 | 예시 출력 |
|-----------|------|-----------|
| 언어 | 파일 확장자, 빌드 파일 분석 | Java 17, Python 3.11 |
| 프레임워크 | 의존성 파일 파싱 | Spring Boot 3.2, Django 5.0 |
| 빌드 도구 | 빌드 설정 파일 탐지 | Gradle 8.x, npm |
| 의존성 목록 | `pom.xml`, `package.json` 등 | 외부 라이브러리 N개 |

### 2. 디렉토리 구조 매핑

코드의 물리적 구조를 트리 형태로 매핑하고, 각 디렉토리의 **역할을 추론**합니다.

```
src/
├── main/
│   ├── java/com/example/app/
│   │   ├── controller/    ← [WEB] API 진입점
│   │   ├── service/       ← [LOGIC] 비즈니스 로직
│   │   ├── repository/    ← [DATA] DB 접근 계층
│   │   ├── config/        ← [CONFIG] 보안 설정
│   │   ├── security/      ← [AUTH] 인증/인가
│   │   └── model/         ← [MODEL] 데이터 모델
│   └── resources/
│       ├── application.yml ← [CONFIG] 환경 설정
│       └── static/         ← [STATIC] 정적 리소스
└── test/                   ← [TEST] 테스트 코드
```

### 3. 보안 관심 영역(Security Hotspot) 식별

구조 분석을 기반으로 보안 검토가 **집중적으로 필요한 영역**을 표시합니다.

| 보안 관심 영역 | 탐지 기준 | 우선순위 |
|---------------|-----------|----------|
| 인증/인가 모듈 | `security/`, `auth/`, `filter/` 디렉토리 | 🔴 최상 |
| API 진입점 | `controller/`, `handler/`, `routes/` | 🔴 최상 |
| DB 접근 계층 | `repository/`, `dao/`, ORM 설정 | 🟠 상 |
| 설정 파일 | `.yml`, `.env`, `.properties` | 🟠 상 |
| 외부 통신 | HTTP Client, gRPC, 메시지 큐 설정 | 🟡 중 |
| 파일 업로드/다운로드 | `upload/`, `file/`, `storage/` | 🟡 중 |

### 4. API 엔드포인트 도출 (Entry Point Extraction)

엔드포인트는 **외부에서 코드에 접근할 수 있는 모든 경로**입니다. Architect Agent의 핵심 임무 중 하나로, 정확한 엔드포인트 목록이 없으면 취약점 진단의 범위 자체가 불완전해집니다.

#### 엔드포인트 도출이 중요한 이유

```
  개발자가 문서화한 API: 30개
  실제 코드에 존재하는 API: 52개
  ─────────────────────────────
  숨겨진/누락된 API: 22개  ← 보안 사각지대
```

> API 문서(Swagger, Postman 등)만 믿으면 안 됩니다. **코드 기반의 엔드포인트 도출**이 필수입니다.

#### 프레임워크별 엔드포인트 탐지 패턴

| 프레임워크 | 탐지 대상 (Annotation / Decorator / Function) | 예시 |
|-----------|----------------------------------------------|------|
| **Spring Boot** | `@GetMapping`, `@PostMapping`, `@PutMapping`, `@DeleteMapping`, `@RequestMapping` | `@PostMapping("/api/users")` |
| **FastAPI** | `@app.get()`, `@app.post()`, `@router.get()`, `@router.post()` | `@router.post("/login")` |
| **Django** | `urlpatterns`, `path()`, `re_path()` | `path('api/users/', views.UserView)` |
| **Express.js** | `app.get()`, `app.post()`, `router.get()`, `router.post()` | `router.get('/api/data', handler)` |
| **Flask** | `@app.route()`, `@blueprint.route()` | `@app.route('/upload', methods=['POST'])` |
| **ASP.NET** | `[HttpGet]`, `[HttpPost]`, `[Route]`, `MapGet()`, `MapPost()` | `[HttpPost("api/auth")]` |
| **Go (Gin)** | `r.GET()`, `r.POST()`, `r.Group()` | `r.POST("/api/login", handler)` |

#### 엔드포인트 분류 기준

도출된 엔드포인트를 보안 관점에서 자동 분류합니다.

```
┌──────────────────────────────────────────────────────────────┐
│                    엔드포인트 분류 매트릭스                     │
├──────────────┬───────────────────────────────────────────────┤
│  분류 기준    │  세부 항목                                     │
├──────────────┼───────────────────────────────────────────────┤
│  HTTP 메서드  │  GET / POST / PUT / DELETE / PATCH            │
│  인증 여부    │  인증 필요 / 비인증(Public) / 조건부 인증        │
│  권한 수준    │  일반 사용자 / 관리자 / 시스템 내부              │
│  데이터 유형  │  읽기(R) / 쓰기(W) / 수정(U) / 삭제(D)          │
│  입력 방식    │  Path Param / Query Param / Body / File Upload  │
│  민감도      │  일반 / 개인정보 / 금융정보 / 인증정보            │
└──────────────┴───────────────────────────────────────────────┘
```

#### 보안 속성 자동 맵핑

각 엔드포인트에 보안 속성을 자동으로 부여합니다.

| 보안 속성 | 판단 기준 | 위험 신호 🚨 |
|-----------|----------|-------------|
| **인증 필요 여부** | Security Filter, Middleware, Decorator 확인 | 비인증 API에서 데이터 조회/수정 가능 |
| **권한 검증** | `@PreAuthorize`, `@Roles`, 권한 체크 로직 유무 | 인증만 있고 인가 없는 API |
| **입력 검증** | `@Valid`, `@RequestBody`, Validator 적용 여부 | 검증 없이 사용자 입력을 처리 |
| **Rate Limiting** | Throttle, Rate Limit 설정 확인 | 인증 API(로그인 등)에 제한 없음 |
| **파일 처리** | MultipartFile, FileUpload 파라미터 | 파일 확장자/크기 제한 미확인 |
| **리다이렉트** | Redirect URL을 파라미터로 받는 경우 | Open Redirect 가능성 |

#### 엔드포인트 도출 스크립트 예시 (Python)

```python
import re
import json
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import Optional

@dataclass
class Endpoint:
    method: str           # GET, POST, PUT, DELETE
    path: str             # /api/users/{id}
    file: str             # UserController.java
    line: int             # 소스코드 라인 번호
    auth_required: Optional[bool] = None    # 인증 필요 여부
    roles: Optional[list] = None            # 필요 권한
    has_validation: bool = False            # 입력 검증 여부
    has_file_upload: bool = False           # 파일 업로드 여부
    risk_level: str = "MEDIUM"              # LOW / MEDIUM / HIGH / CRITICAL

class EndpointExtractor:
    """프레임워크별 API 엔드포인트 자동 추출기"""

    # 프레임워크별 정규식 패턴
    PATTERNS = {
        "spring": {
            "mapping": re.compile(
                r'@(Get|Post|Put|Delete|Patch|Request)Mapping\s*\(\s*'
                r'(?:value\s*=\s*)?["\']([^"\']+)["\']'
            ),
            "class_mapping": re.compile(
                r'@RequestMapping\s*\(\s*["\']([^"\']+)["\']'
            ),
            "auth": re.compile(
                r'@PreAuthorize|@Secured|@RolesAllowed'
            ),
            "validation": re.compile(
                r'@Valid|@Validated|@RequestBody'
            ),
            "file_upload": re.compile(
                r'MultipartFile|@RequestPart'
            ),
        },
        "fastapi": {
            "mapping": re.compile(
                r'@(?:app|router)\.(get|post|put|delete|patch)\s*\(\s*'
                r'["\']([^"\']+)["\']'
            ),
            "auth": re.compile(
                r'Depends\s*\(\s*(?:get_current_user|verify_token|auth)'
            ),
            "validation": re.compile(
                r'Body\s*\(|Query\s*\(|Pydantic'
            ),
            "file_upload": re.compile(
                r'UploadFile|File\s*\('
            ),
        },
        "express": {
            "mapping": re.compile(
                r'(?:app|router)\.(get|post|put|delete|patch)\s*\(\s*'
                r'["\']([^"\']+)["\']'
            ),
            "auth": re.compile(
                r'authenticate|passport\.authenticate|verifyToken|authMiddleware'
            ),
            "validation": re.compile(
                r'express-validator|joi\.validate|celebrate'
            ),
            "file_upload": re.compile(
                r'multer|upload\.single|upload\.array'
            ),
        },
    }

    def __init__(self, project_path: str, framework: str = "spring"):
        self.project_path = Path(project_path)
        self.framework = framework
        self.patterns = self.PATTERNS.get(framework, {})

    def extract(self) -> list[Endpoint]:
        """모든 소스 파일에서 엔드포인트 추출"""
        endpoints = []
        extensions = {
            "spring": "*.java",
            "fastapi": "*.py",
            "express": "*.js",
        }

        for source_file in self.project_path.rglob(
            extensions.get(self.framework, "*")
        ):
            if self._should_skip(source_file):
                continue
            endpoints.extend(self._extract_from_file(source_file))

        return self._assess_risk(endpoints)

    def _extract_from_file(self, filepath: Path) -> list[Endpoint]:
        """단일 파일에서 엔드포인트 추출"""
        content = filepath.read_text(encoding="utf-8", errors="ignore")
        lines = content.split("\n")
        endpoints = []

        # 클래스 레벨 매핑 (Spring의 @RequestMapping 등)
        base_path = ""
        class_match = self.patterns.get("class_mapping")
        if class_match:
            m = class_match.search(content)
            if m:
                base_path = m.group(1)

        # 메서드 레벨 매핑
        mapping_pattern = self.patterns.get("mapping")
        if not mapping_pattern:
            return endpoints

        for i, line in enumerate(lines, 1):
            match = mapping_pattern.search(line)
            if match:
                method = match.group(1).upper()
                path = base_path + match.group(2)

                # 주변 코드 분석 (앞뒤 10줄)
                context = "\n".join(lines[max(0, i-10):min(len(lines), i+20)])

                ep = Endpoint(
                    method=method,
                    path=path,
                    file=str(filepath.relative_to(self.project_path)),
                    line=i,
                    auth_required=self._check_auth(context),
                    has_validation=self._check_validation(context),
                    has_file_upload=self._check_file_upload(context),
                )
                endpoints.append(ep)

        return endpoints

    def _check_auth(self, context: str) -> bool:
        """인증/인가 설정 확인"""
        pattern = self.patterns.get("auth")
        return bool(pattern and pattern.search(context))

    def _check_validation(self, context: str) -> bool:
        """입력 검증 확인"""
        pattern = self.patterns.get("validation")
        return bool(pattern and pattern.search(context))

    def _check_file_upload(self, context: str) -> bool:
        """파일 업로드 확인"""
        pattern = self.patterns.get("file_upload")
        return bool(pattern and pattern.search(context))

    def _assess_risk(self, endpoints: list[Endpoint]) -> list[Endpoint]:
        """엔드포인트별 위험도 자동 판정"""
        for ep in endpoints:
            risk_score = 0

            # 비인증 API
            if not ep.auth_required:
                risk_score += 3

            # 데이터 변경 API (POST/PUT/DELETE)
            if ep.method in ("POST", "PUT", "DELETE"):
                risk_score += 2

            # 입력 검증 없음
            if not ep.has_validation:
                risk_score += 2

            # 파일 업로드
            if ep.has_file_upload:
                risk_score += 2

            # 민감 경로 패턴
            sensitive_patterns = [
                "admin", "user", "auth", "login", "password",
                "token", "upload", "file", "export", "download",
                "config", "setting", "payment", "transfer"
            ]
            if any(p in ep.path.lower() for p in sensitive_patterns):
                risk_score += 1

            # 위험도 매핑
            if risk_score >= 7:
                ep.risk_level = "CRITICAL"
            elif risk_score >= 5:
                ep.risk_level = "HIGH"
            elif risk_score >= 3:
                ep.risk_level = "MEDIUM"
            else:
                ep.risk_level = "LOW"

        return endpoints

    def _should_skip(self, filepath: Path) -> bool:
        skip_dirs = {"test", "tests", "__pycache__", "node_modules", ".git"}
        return any(d in filepath.parts for d in skip_dirs)

    def to_json(self, endpoints: list[Endpoint]) -> str:
        return json.dumps(
            [asdict(ep) for ep in endpoints],
            indent=2, ensure_ascii=False
        )
```

#### 엔드포인트 도출 결과 예시

```json
[
  {
    "method": "POST",
    "path": "/api/auth/login",
    "file": "controller/AuthController.java",
    "line": 45,
    "auth_required": false,
    "roles": null,
    "has_validation": true,
    "has_file_upload": false,
    "risk_level": "HIGH",
    "security_notes": "비인증 API - 브루트포스/Rate Limiting 확인 필요"
  },
  {
    "method": "POST",
    "path": "/api/files/upload",
    "file": "controller/FileController.java",
    "line": 32,
    "auth_required": true,
    "roles": ["USER"],
    "has_validation": false,
    "has_file_upload": true,
    "risk_level": "CRITICAL",
    "security_notes": "파일 업로드 + 입력 검증 없음 - 악성 파일 업로드 위험"
  },
  {
    "method": "GET",
    "path": "/api/admin/users",
    "file": "controller/AdminController.java",
    "line": 28,
    "auth_required": true,
    "roles": ["ADMIN"],
    "has_validation": false,
    "has_file_upload": false,
    "risk_level": "MEDIUM",
    "security_notes": "관리자 전용 API - IDOR 취약점 확인 필요"
  },
  {
    "method": "GET",
    "path": "/api/health",
    "file": "controller/HealthController.java",
    "line": 15,
    "auth_required": false,
    "roles": null,
    "has_validation": false,
    "has_file_upload": false,
    "risk_level": "LOW",
    "security_notes": "헬스체크 API - 정보 노출 수준 확인"
  }
]
```

#### 엔드포인트 보안 요약 대시보드 (LLM 출력)

```
╔══════════════════════════════════════════════════════════════╗
║              📊 엔드포인트 보안 분석 요약                     ║
╠══════════════════════════════════════════════════════════════╣
║  총 엔드포인트: 52개                                         ║
║                                                              ║
║  🔴 CRITICAL:  3개 (5.8%)  - 즉시 검토 필요                  ║
║  🟠 HIGH:     12개 (23.1%) - 우선 검토                       ║
║  🟡 MEDIUM:   25개 (48.1%) - 일반 검토                       ║
║  🟢 LOW:      12개 (23.1%) - 모니터링                        ║
║                                                              ║
║  ⚠️  주요 발견사항:                                          ║
║  • 비인증 API 8개 중 데이터 변경 API 3개 존재                  ║
║  • 파일 업로드 API 2개 중 입력 검증 미적용 1개                  ║
║  • 관리자 API 5개 - 권한 상승(Privilege Escalation) 검토 필요  ║
║  • /api/internal/* 경로 4개 - 외부 노출 여부 확인 필요          ║
╚══════════════════════════════════════════════════════════════╝
```

---

### 5. 데이터 흐름 경로 추적 (Entry → Exit)

외부 입력이 코드 내부를 어떻게 흐르는지 **고수준(High-Level) 경로**를 식별합니다.

```
[외부 요청] → Controller → Service → Repository → [DB]
                  │                       │
                  ├── Validation?         ├── Parameterized Query?
                  ├── Authentication?     └── Sensitive Data Logging?
                  └── Authorization?
```

### 6. 구조 분석 리포트 생성

위 분석 결과를 **구조화된 JSON/Markdown 형태**로 출력하여, 후속 에이전트가 참조할 수 있도록 합니다.

---

## 🛠️ 구현 방법: LLM 기반 Architect Agent

### 방법 1: 프롬프트 엔지니어링 기반 (빠른 시작)

LLM에 소스코드와 함께 구조화된 프롬프트를 전달하는 방식입니다.

#### System Prompt 예시

```
당신은 소스코드 보안 검토를 위한 Architect Agent입니다.
주어진 소스코드의 구조를 분석하여 다음 정보를 JSON 형식으로 출력하세요.

1. project_metadata: 언어, 프레임워크, 빌드 도구, 주요 의존성
2. directory_structure: 디렉토리별 역할 분류 (WEB, LOGIC, DATA, AUTH, CONFIG)
3. security_hotspots: 보안 검토가 필요한 파일/디렉토리 목록과 우선순위
4. entry_points: 외부에서 접근 가능한 API 엔드포인트 목록
5. data_flow: 주요 데이터 흐름 경로 (입력 → 처리 → 저장)
6. external_integrations: 외부 시스템 연동 정보 (API, DB, 메시지 큐 등)
7. risk_summary: 구조적 관점에서의 초기 리스크 요약

분석 시 다음 원칙을 따르세요:
- 보안 관점에서 위험도가 높은 영역을 우선 식별합니다
- 인증/인가 구현 유무를 반드시 확인합니다
- 환경변수/시크릿 관리 방식을 파악합니다
- 입력 검증(Input Validation)의 위치를 추적합니다
```

#### User Prompt 구성 예시

```
아래 프로젝트의 구조를 분석해주세요.

[프로젝트 파일 트리]
{tree 명령어 결과 또는 디렉토리 구조}

[주요 설정 파일 내용]
{pom.xml / package.json / requirements.txt 등}

[핵심 소스코드]
{controller, security config 등 보안 관련 주요 파일}
```

#### 예상 출력 (JSON)

```json
{
  "project_metadata": {
    "language": "Java 17",
    "framework": "Spring Boot 3.2.1",
    "build_tool": "Gradle 8.5",
    "dependencies": {
      "security": ["spring-boot-starter-security", "jjwt"],
      "database": ["spring-boot-starter-data-jpa", "mysql-connector"],
      "web": ["spring-boot-starter-web"]
    }
  },
  "security_hotspots": [
    {
      "path": "src/main/java/com/example/config/SecurityConfig.java",
      "category": "AUTH",
      "priority": "CRITICAL",
      "reason": "Spring Security 필터 체인 설정, CORS/CSRF 정책 정의"
    },
    {
      "path": "src/main/java/com/example/controller/UserController.java",
      "category": "WEB",
      "priority": "HIGH",
      "reason": "사용자 입력을 직접 처리하는 API 진입점"
    }
  ],
  "entry_points": [
    {"method": "POST", "path": "/api/auth/login", "auth_required": false},
    {"method": "GET", "path": "/api/users/{id}", "auth_required": true},
    {"method": "POST", "path": "/api/files/upload", "auth_required": true}
  ],
  "risk_summary": {
    "overall_risk": "MEDIUM",
    "key_concerns": [
      "파일 업로드 기능 존재 - 악성 파일 업로드 가능성 검토 필요",
      "JWT 기반 인증 사용 - 토큰 관리 정책 확인 필요",
      "CORS 설정이 와일드카드(*) 허용 여부 확인 필요"
    ]
  }
}
```

---

### 방법 2: 스크립트 + LLM 하이브리드 (권장)

정적 분석 도구로 정확한 데이터를 수집한 뒤, LLM이 해석하는 방식입니다.

#### 단계별 구현

```
Step 1: 정적 수집 (스크립트)          Step 2: 지능형 분석 (LLM)
┌──────────────────────────┐      ┌──────────────────────────┐
│  • tree 명령으로 구조 추출  │      │  • 수집된 데이터 해석      │
│  • 의존성 파일 파싱         │  ──▶ │  • 보안 관심 영역 분류     │
│  • grep으로 패턴 탐지       │      │  • 리스크 우선순위 판정     │
│  • 파일별 LOC/복잡도 측정   │      │  • 구조 리포트 생성        │
└──────────────────────────┘      └──────────────────────────┘
```

#### Step 1: 정보 수집 스크립트 (Python 예시)

```python
import os
import json
import subprocess

class ArchitectCollector:
    """소스코드 구조 정보를 수집하는 클래스"""

    # 보안 관련 키워드 패턴
    SECURITY_PATTERNS = {
        "auth": ["auth", "login", "token", "jwt", "oauth", "session"],
        "crypto": ["encrypt", "decrypt", "hash", "cipher", "secret"],
        "input": ["request", "param", "input", "form", "upload"],
        "database": ["query", "sql", "repository", "dao", "orm"],
        "config": ["config", "setting", "env", "properties", "yml"],
    }

    # 주요 의존성 파일
    DEPENDENCY_FILES = {
        "java": ["pom.xml", "build.gradle", "build.gradle.kts"],
        "python": ["requirements.txt", "Pipfile", "pyproject.toml"],
        "javascript": ["package.json"],
        "go": ["go.mod"],
        "csharp": ["*.csproj"],
    }

    def __init__(self, project_path: str):
        self.project_path = project_path
        self.result = {}

    def collect_tree(self) -> dict:
        """디렉토리 구조를 트리 형태로 수집"""
        tree = subprocess.run(
            ["find", self.project_path, "-type", "f",
             "-not", "-path", "*/.git/*",
             "-not", "-path", "*/node_modules/*",
             "-not", "-path", "*/__pycache__/*"],
            capture_output=True, text=True
        )
        return {"files": tree.stdout.strip().split("\n")}

    def detect_language_and_framework(self) -> dict:
        """언어와 프레임워크를 자동 탐지"""
        detected = {"languages": [], "frameworks": [], "build_tools": []}
        for lang, dep_files in self.DEPENDENCY_FILES.items():
            for dep_file in dep_files:
                if self._file_exists(dep_file):
                    detected["languages"].append(lang)
                    detected["build_tools"].append(dep_file)
        return detected

    def find_security_hotspots(self) -> list:
        """보안 관련 파일/디렉토리를 패턴 매칭으로 탐지"""
        hotspots = []
        for category, patterns in self.SECURITY_PATTERNS.items():
            for pattern in patterns:
                result = subprocess.run(
                    ["grep", "-rl", "--include=*.java", "--include=*.py",
                     "--include=*.js", "--include=*.ts",
                     pattern, self.project_path],
                    capture_output=True, text=True
                )
                if result.stdout:
                    for filepath in result.stdout.strip().split("\n"):
                        hotspots.append({
                            "file": filepath,
                            "category": category,
                            "matched_pattern": pattern
                        })
        return hotspots

    def extract_entry_points(self) -> list:
        """API 진입점(엔드포인트) 추출"""
        # Spring Boot 예시: @RequestMapping, @GetMapping 등 탐지
        annotations = [
            "@GetMapping", "@PostMapping", "@PutMapping",
            "@DeleteMapping", "@RequestMapping",
            "@app.route", "@router."  # Flask, FastAPI
        ]
        entry_points = []
        for annotation in annotations:
            result = subprocess.run(
                ["grep", "-rn", annotation, self.project_path],
                capture_output=True, text=True
            )
            if result.stdout:
                for line in result.stdout.strip().split("\n"):
                    entry_points.append(line)
        return entry_points

    def collect_all(self) -> dict:
        """모든 정보를 수집하여 반환"""
        return {
            "tree": self.collect_tree(),
            "tech_stack": self.detect_language_and_framework(),
            "security_hotspots": self.find_security_hotspots(),
            "entry_points": self.extract_entry_points(),
        }

    def _file_exists(self, filename: str) -> bool:
        for root, dirs, files in os.walk(self.project_path):
            if filename in files:
                return True
        return False
```

#### Step 2: LLM 분석 호출

```python
import openai  # 또는 사용하는 LLM SDK

def analyze_with_llm(collected_data: dict) -> dict:
    """수집된 데이터를 LLM에 전달하여 구조 분석 리포트 생성"""

    system_prompt = """당신은 소스코드 보안 검토를 위한 Architect Agent입니다.
수집된 프로젝트 구조 데이터를 분석하여 보안 관점의 구조 리포트를 생성하세요.
출력은 반드시 JSON 형식으로 하세요."""

    user_prompt = f"""
아래 수집된 프로젝트 정보를 분석하고, 보안 검토를 위한 구조 리포트를 생성하세요.

[수집 데이터]
{json.dumps(collected_data, indent=2, ensure_ascii=False)}

다음 항목을 포함하세요:
1. 프로젝트 개요 및 기술 스택
2. 보안 관심 영역 (우선순위 포함)
3. API 진입점 목록 및 인증 필요 여부
4. 데이터 흐름 경로
5. 구조적 리스크 요약 및 후속 에이전트를 위한 권고사항
"""

    response = openai.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        response_format={"type": "json_object"}
    )

    return json.loads(response.choices[0].message.content)
```

---

## 🔗 후속 에이전트와의 연계

Architect Agent의 출력은 다음 에이전트에 **컨텍스트**로 전달됩니다.

```python
# 파이프라인 실행 예시
def run_security_review_pipeline(project_path: str):
    # 1단계: Architect Agent
    collector = ArchitectCollector(project_path)
    raw_data = collector.collect_all()
    architecture_report = analyze_with_llm(raw_data)

    # 2단계: Vulnerability Agent (구조 리포트를 컨텍스트로 전달)
    vuln_result = vulnerability_agent.analyze(
        project_path=project_path,
        context=architecture_report  # Architect Agent의 출력
    )

    # 3단계: Business Logic Agent
    logic_result = business_logic_agent.analyze(
        project_path=project_path,
        context=architecture_report,
        vulnerabilities=vuln_result
    )

    # 4단계: Report Agent
    final_report = report_agent.generate(
        architecture=architecture_report,
        vulnerabilities=vuln_result,
        business_logic=logic_result
    )

    return final_report
```

---

## 📌 Architect Agent 구축 시 핵심 체크리스트

| 항목 | 설명 | 구현 여부 |
|------|------|-----------|
| 언어/프레임워크 자동 탐지 | 의존성 파일 기반 식별 | ☐ |
| 디렉토리 역할 분류 | 각 폴더의 목적 추론 | ☐ |
| 보안 핫스팟 식별 | 인증, 입력 처리, DB 접근 영역 표시 | ☐ |
| API 엔드포인트 목록화 | 외부 진입점 자동 추출 | ☐ |
| 데이터 흐름 추적 | 입력 → 처리 → 저장 경로 식별 | ☐ |
| 구조화된 출력 | JSON 형식의 표준 리포트 생성 | ☐ |
| 후속 에이전트 연계 | 분석 결과를 다음 단계로 전달 | ☐ |

---

## 🏁 마치며

Architect Agent는 소스코드 보안성 검토의 **"지도를 그리는 역할"**입니다. 좋은 지도가 있어야 탐험(취약점 진단)이 효율적이듯, 정확한 구조 분석은 전체 보안 검토의 품질을 좌우합니다.

다음 단계로는 이 구조 분석 결과를 활용하는 **Vulnerability Agent**(취약점 탐지 에이전트)를 구축하여, Semgrep, CodeQL 등의 SAST 도구와 LLM을 결합한 지능형 취약점 분석 체계를 완성할 수 있습니다.
