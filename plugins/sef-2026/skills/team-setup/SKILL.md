---
name: team-setup
description: AI 개발 팀 구성 및 병렬 개발 실행. 검증루프와 서브 에이전트 위임 패턴 적용. "팀 구성", "팀 만들어줘", "team setup", "개발팀 세팅" 요청 시 사용. setup 스킬 후속으로도, 독립적으로도 실행 가능.
---

# AI 개발 팀 구성 (team-setup)

## 개요

AI 에이전트 팀을 구성하여 ROADMAP.md 기반 병렬 개발을 수행합니다. 검증루프(Verification Loop)와 서브 에이전트 위임 패턴을 적용하여 품질을 보장합니다.

## Step 0: 사전 조건 확인

### 실행 모드 자동 판별

- **연계 모드**: `sef-2026:setup`에서 호출된 경우 -- 초기화 직후 팀 구성
- **독립 모드**: 기존 프로젝트에서 직접 호출 -- 프로젝트 구조가 이미 존재

### 필수 확인 사항

1. `docs/ROADMAP.md` 존재 확인
   - 없으면: `development-planner` 에이전트를 먼저 실행하도록 안내
2. 프로젝트 유형 확인 (공공/민간)
   - 기존 구조에서 자동 감지 (WAR 패키징 → 공공, Docker → 민간)
   - 판별 불가 시 AskUserQuestion으로 확인

---

## Step 1: 팀 규모 선택

**AskUserQuestion으로 팀 규모를 선택합니다:**

```
질문: "개발 팀 규모를 선택해주세요."
선택지:
  - "소규모 (2명): backend-dev + frontend-dev"
  - "표준 (3명): backend-dev + frontend-dev + reviewer (권장)"
```

---

## Step 2: 팀 생성 및 에이전트 스폰

### 팀 생성

- `TeamCreate`로 팀 생성: `{project}-dev-team`

### 역할 테이블

| 역할 | 담당 | 참조 스킬/에이전트 |
|------|------|-------------------|
| team-lead | 작업 분배, 검증루프, 통합 | (팀 생성자 본인) |
| backend-dev | 백엔드 모듈 개발 | `sef-2026:backend-public` / `sef-2026:backend-private` |
| frontend-dev | 프론트 모듈/페이지 개발 | `sef-2026:module-generator`, `sef-2026:page-generator` |
| reviewer | 코드 리뷰, 품질 검증 | `code-reviewer` 에이전트 (표준 팀만) |

### 에이전트 스폰 규칙

- Agent 도구로 각 역할 에이전트 스폰
- **현재 모델 통일**: Agent 호출 시 `model` 파라미터 미지정 (부모 모델 상속)
- 각 에이전트에 역할, 담당 범위, 참조 스킬을 명확히 전달

---

## Step 3: 작업 분해 및 할당

1. `docs/ROADMAP.md`의 Task를 `TaskCreate`로 등록
2. 병렬 가능 Task 식별:
   - 독립 도메인 모듈 (예: 사용자 관리 / 게시판 / 통계)
   - BE/FE 초기 단계 (API 인터페이스 합의 후 동시 개발)
3. `SendMessage`로 에이전트에 작업 지시:
   - Task ID, 상세 요구사항, 참조 스킬명 포함
   - 산출물 경로와 완료 기준 명시

---

## Step 4: 서브 에이전트 위임 패턴

### 위임 조건

- 독립 도메인 모듈 병렬 개발
- BE/FE 동시 개발 (API 계약 확정 후)
- 단순/반복 작업 (boilerplate 생성, 유사 모듈 복제)

### 위임 절차

1. team-lead가 병렬 가능 Task 그룹 식별
2. Agent 도구로 서브 에이전트 스폰 (최대 3~5개 동시)
3. 각 서브 에이전트에 **단일 Task + 참조 스킬** 전달
4. 완료 시 `TaskUpdate`로 상태 변경 (`in_progress` → `completed`)

### 제약 사항

- 서브 에이전트는 단순/반복 작업만 수행
- 복잡한 판단 (아키텍처 결정, 모듈 간 의존성 해결)은 team-lead가 처리
- 서브 에이전트 간 직접 통신 금지 -- 반드시 team-lead를 경유

---

## Step 5: 검증루프 (Verification Loop)

> 상세는 `references/verification-loop.md` 참조

### 4개 평가 기준

| 기준 | 설명 |
|------|------|
| 목표 달성 | Task의 요구사항을 충족하는가 |
| 완전성 | 누락된 파일, 메서드, 설정이 없는가 |
| 정확성 | 버그, 타입 에러, 잘못된 로직이 없는가 |
| 일관성 | 기존 코드 컨벤션과 아키텍처 패턴을 따르는가 |

### 검증 프로세스

- **최대 3라운드** 검증 수행
- 라운드별 미달 시 전략 선택:

| 전략 | 조건 | 행동 |
|------|------|------|
| A: 부분 수정 | 경미한 문제 (오타, 누락 import 등) | 해당 에이전트가 즉시 수정 |
| B: 재작업 | 구조적 문제 (잘못된 패턴, 설계 오류) | Task를 반려하고 재작업 지시 |
| C: Task 분할 | 범위 과대 (하나의 Task가 너무 큼) | Task를 분할 후 재할당 |

- **Round 3 후에도 미통과** → AskUserQuestion으로 사용자 판단 요청

---

## Step 6: 팀 종료

1. `TaskList`로 전체 Task 완료 확인
2. `SendMessage` type: `"shutdown_request"` 전송
3. 최종 결과 요약 보고:
   - 완료된 Task 목록
   - 생성/수정된 파일 목록
   - 검증루프 결과 요약
   - 미완료 또는 에스컬레이션된 항목

---

## 관련 스킬

- `sef-2026:setup` -- 프로젝트 초기화 (공공/민간 선택)
- `sef-2026:workflow-guide` -- 프로젝트 워크플로우 가이드
- `sef-2026:backend-public` -- 공공 백엔드 개발
- `sef-2026:backend-private` -- 민간 백엔드 개발
- `sef-2026:module-generator` -- 도메인 모듈 세트 생성
- `sef-2026:page-generator` -- CRUD 페이지 생성
