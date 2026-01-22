---
layout: post
title: "AI 정오탐 자동 분석 연동 가이드"
date: 2026-01-21
categories: [AI & Automation, Security AI] # 카테고리 설정
tags: [LLM, Security, AI-Agent, False-Positive] # 태그 설정
render_with_liquid: false
---

> **보안의 한계를 AI로 넘다** > 본 포스팅은 LLM과 AI 에이전트를 활용하여 반복적인 보안 정책 관리를 자동화하고, 
> 특히 정적 분석 시스템에서 발생하는 정오탐(False Positive) 분석의 효율을 극대화하는 실무 기술을 다룹니다.

---

## 📋 목차

1. [개요](#개요)
2. [구현 방법 비교](#구현-방법-비교)
3. [방법 1: Claude API](#방법-1-claude-api-권장)
4. [방법 2: MCP 서버](#방법-2-mcp-서버)
5. [방법 3: Ollama (로컬 LLM)](#방법-3-ollama-로컬-llm)
6. [구현 결정](#구현-결정)

---

## 개요

### 현재 문제점
- Semgrep 스캔 결과에 **오탐(False Positive)**이 포함됨
- 수동으로 각 취약점을 검토하는 데 시간 소요
- 대량의 결과에서 실제 취약점 파악 어려움

### 목표
```
[Semgrep 스캔] → [AI 자동 분석] → [정탐만 표시]
```

### 기대 효과
- ✅ 분석 시간 단축 (수작업 → 자동화)
- ✅ 일관된 판단 기준 적용
- ✅ 실제 취약점에 집중 가능

---

## 구현 방법 비교

| 방법 | 자동화 수준 | 비용 | 오프라인 | 정확도 | 구현 난이도 |
|------|------------|------|----------|--------|-------------|
| **Claude API** | ✅ 완전 자동 | 💰 API 비용 | ❌ | ⭐⭐⭐ 높음 | ⭐ 쉬움 |
| **MCP 서버** | ⚠️ 반자동 | 무료 | ❌ | ⭐⭐⭐ 높음 | ⭐⭐ 보통 |
| **Ollama** | ✅ 완전 자동 | 무료 | ✅ | ⭐⭐ 보통 | ⭐⭐⭐ 어려움 |

---

## 방법 1: Claude API (권장)

### 개요
Anthropic의 Claude API를 직접 호출하여 각 취약점을 분석합니다.

### 아키텍처
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Semgrep   │ ──→ │  Python     │ ──→ │ Claude API  │
│   스캔 결과  │     │  분석 모듈   │     │ (Anthropic) │
└─────────────┘     └─────────────┘     └─────────────┘
                           │
                           ↓
                    ┌─────────────┐
                    │  정탐 결과   │
                    │  필터링     │
                    └─────────────┘
```

### 장점
- ✅ 완전 자동화 가능
- ✅ Cursor와 동일한 Claude 모델 사용
- ✅ 높은 정확도 (claude-sonnet-4-20250514)
- ✅ 구현이 간단함

### 단점
- ❌ API 키 필요
- ❌ API 비용 발생 (약 $3/1M 토큰)
- ❌ 인터넷 연결 필요

### 비용 예상
| 취약점 수 | 예상 토큰 | 예상 비용 |
|-----------|----------|----------|
| 10개 | ~20,000 | ~$0.06 |
| 50개 | ~100,000 | ~$0.30 |
| 100개 | ~200,000 | ~$0.60 |

### 구현 코드 예시

```python
# ai_analyzer.py
import os
import json
import urllib.request
import ssl

class ClaudeAnalyzer:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.model = "claude-sonnet-4-20250514"
    
    def analyze_finding(self, finding: dict) -> dict:
        """단일 취약점 정오탐 분석"""
        
        prompt = f"""보안 전문가로서 다음 Semgrep 취약점을 분석해주세요.

## 취약점 정보
- 룰: {finding.get('check_id', 'N/A')}
- 파일: {finding.get('path', 'N/A')}
- 라인: {finding.get('start', {}).get('line', 'N/A')}
- 설명: {finding.get('extra', {}).get('message', 'N/A')}

## 코드
```
{finding.get('extra', {}).get('lines', 'N/A')}
```

이 취약점이 정탐(TRUE_POSITIVE)인지 오탐(FALSE_POSITIVE)인지 판별하고,
JSON 형식으로 응답해주세요:
{{"verdict": "TRUE_POSITIVE 또는 FALSE_POSITIVE", "confidence": "HIGH/MEDIUM/LOW", "reason": "판단 근거"}}
"""
        
        headers = {
            'Content-Type': 'application/json',
            'x-api-key': self.api_key,
            'anthropic-version': '2023-06-01'
        }
        
        data = {
            'model': self.model,
            'max_tokens': 500,
            'messages': [{'role': 'user', 'content': prompt}]
        }
        
        req = urllib.request.Request(
            'https://api.anthropic.com/v1/messages',
            data=json.dumps(data).encode('utf-8'),
            headers=headers
        )
        
        ctx = ssl.create_default_context()
        with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
            result = json.loads(resp.read().decode('utf-8'))
        
        return self._parse_response(result)
    
    def filter_true_positives(self, findings: list) -> list:
        """정탐만 필터링"""
        true_positives = []
        
        for finding in findings:
            analysis = self.analyze_finding(finding)
            if analysis.get('verdict') == 'TRUE_POSITIVE':
                finding['ai_analysis'] = analysis
                true_positives.append(finding)
        
        return true_positives
```

### 설정 방법
1. [Anthropic Console](https://console.anthropic.com/)에서 API 키 발급
2. 환경 변수 설정: `ANTHROPIC_API_KEY=sk-ant-api...`
3. 웹 UI에서 API 키 입력

---

## 방법 2: MCP 서버

### 개요
Cursor의 MCP(Model Context Protocol)를 활용하여 스캔 결과를 Cursor AI에 제공합니다.

### 아키텍처
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Semgrep   │ ──→ │  MCP 서버   │ ←── │  Cursor AI  │
│   스캔 결과  │     │  (Python)   │     │             │
└─────────────┘     └─────────────┘     └─────────────┘
                           ↑
                           │
                    [사용자가 Cursor에서
                     분석 요청]
```

### 장점
- ✅ Cursor 네이티브 통합
- ✅ Cursor 구독에 포함된 AI 사용
- ✅ API 비용 없음

### 단점
- ❌ 완전 자동화 불가 (사용자가 분석 요청 필요)
- ❌ MCP 서버 설정 필요
- ❌ Cursor 설정 수정 필요

### 구현 코드 예시

```python
# mcp_server.py
from mcp.server import Server
from mcp.types import Tool, TextContent

app = Server("secops-scanner")

@app.list_tools()
async def list_tools():
    return [
        Tool(
            name="get_scan_results",
            description="Semgrep 스캔 결과를 가져옵니다",
            inputSchema={"type": "object", "properties": {}}
        ),
        Tool(
            name="analyze_finding",
            description="특정 취약점을 분석합니다",
            inputSchema={
                "type": "object",
                "properties": {
                    "index": {"type": "integer", "description": "취약점 인덱스"}
                }
            }
        )
    ]

@app.call_tool()
async def call_tool(name: str, arguments: dict):
    if name == "get_scan_results":
        return TextContent(text=json.dumps(scan_results, ensure_ascii=False))
    elif name == "analyze_finding":
        idx = arguments.get("index", 0)
        finding = scan_results[idx]
        return TextContent(text=format_finding_for_analysis(finding))
```

### Cursor 설정
```json
// ~/.cursor/mcp.json
{
  "mcpServers": {
    "secops": {
      "command": "python",
      "args": ["C:/Users/jnyoon/Desktop/secops/mcp_server.py"]
    }
  }
}
```

### 사용 방법
1. MCP 서버 실행
2. Cursor에서 채팅 열기 (Cmd+L)
3. "스캔 결과를 분석하고 정탐만 알려줘" 요청

---

## 방법 3: Ollama (로컬 LLM)

### 개요
로컬에서 실행되는 LLM(Ollama)을 사용하여 분석합니다.

### 아키텍처
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Semgrep   │ ──→ │  Python     │ ──→ │   Ollama    │
│   스캔 결과  │     │  분석 모듈   │     │ (로컬 LLM)  │
└─────────────┘     └─────────────┘     └─────────────┘
                                              │
                                         (localhost:11434)
```

### 장점
- ✅ 완전 무료
- ✅ 오프라인 사용 가능
- ✅ 데이터 외부 전송 없음 (보안)
- ✅ 속도 제한 없음

### 단점
- ❌ Ollama 설치 필요
- ❌ GPU 권장 (CPU만 사용 시 느림)
- ❌ 정확도가 Claude보다 낮을 수 있음
- ❌ 모델 다운로드 필요 (수 GB)

### 설치 방법

```bash
# 1. Ollama 설치 (Windows)
# https://ollama.com/download 에서 다운로드

# 2. 모델 다운로드 (추천: codellama 또는 llama3)
ollama pull codellama:13b
# 또는
ollama pull llama3:8b

# 3. Ollama 서버 실행 (자동 시작됨)
ollama serve
```

### 구현 코드 예시

```python
# ollama_analyzer.py
import requests
import json

class OllamaAnalyzer:
    def __init__(self, model: str = "codellama:13b"):
        self.model = model
        self.base_url = "http://localhost:11434"
    
    def analyze_finding(self, finding: dict) -> dict:
        """Ollama로 취약점 분석"""
        
        prompt = f"""You are a security expert. Analyze this vulnerability finding.

Rule: {finding.get('check_id', 'N/A')}
File: {finding.get('path', 'N/A')}
Line: {finding.get('start', {}).get('line', 'N/A')}
Description: {finding.get('extra', {}).get('message', 'N/A')}

Code:
{finding.get('extra', {}).get('lines', 'N/A')}

Is this a TRUE_POSITIVE (real vulnerability) or FALSE_POSITIVE (false alarm)?
Respond in JSON format: {{"verdict": "TRUE_POSITIVE or FALSE_POSITIVE", "reason": "brief explanation"}}
"""
        
        response = requests.post(
            f"{self.base_url}/api/generate",
            json={
                "model": self.model,
                "prompt": prompt,
                "stream": False
            },
            timeout=120
        )
        
        result = response.json()
        return self._parse_response(result.get('response', ''))
    
    def filter_true_positives(self, findings: list) -> list:
        """정탐만 필터링"""
        true_positives = []
        
        for i, finding in enumerate(findings):
            print(f"[Ollama] 분석 중... {i+1}/{len(findings)}")
            analysis = self.analyze_finding(finding)
            
            if analysis.get('verdict') == 'TRUE_POSITIVE':
                finding['ai_analysis'] = analysis
                true_positives.append(finding)
        
        return true_positives
```

### 추천 모델
| 모델 | 크기 | 속도 | 정확도 | 추천 |
|------|------|------|--------|------|
| `codellama:7b` | 4GB | 빠름 | 보통 | 빠른 분석 |
| `codellama:13b` | 8GB | 보통 | 좋음 | ⭐ 균형 |
| `llama3:8b` | 5GB | 빠름 | 좋음 | 일반 분석 |
| `llama3:70b` | 40GB | 느림 | 매우 좋음 | 정밀 분석 |

---

## 구현 결정

### 추천 순위

1. **🥇 Claude API** - 가장 빠르고 정확한 결과
   - 적합: 클라우드 환경, 정확도 중시
   
2. **🥈 Ollama** - 무료 + 오프라인
   - 적합: 에어갭 환경, 비용 제약

3. **🥉 MCP 서버** - Cursor 네이티브
   - 적합: 수동 분석 선호, Cursor 활용

### 선택 가이드

```
인터넷 사용 가능?
    │
    ├── Yes ─→ API 비용 가능?
    │              │
    │              ├── Yes ─→ Claude API (방법 1) ⭐
    │              │
    │              └── No ─→ MCP 서버 (방법 2)
    │
    └── No ─→ Ollama (방법 3)
```

---

## 다음 단계

구현 방법을 선택한 후 알려주세요:

- [ ] **방법 1: Claude API** - `ANTHROPIC_API_KEY` 필요
- [ ] **방법 2: MCP 서버** - Cursor 설정 수정 필요  
- [ ] **방법 3: Ollama** - Ollama 설치 필요
