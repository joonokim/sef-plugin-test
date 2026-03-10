# sef-plugin-test

공공/민간 서비스 개발을 위한 Claude Code 플러그인 마켓플레이스입니다.

## 설치 방법

### 1. 마켓플레이스 추가

```bash
/plugin marketplace add joonokim/sef-plugin-test
```

### 2. 플러그인 설치

```bash
# 공공/민간 통합 플러그인 (프론트엔드, 백엔드, 배포, 기술 스택, 에이전트)
/plugin install sef-2026@sef-plugin-test

# DB 스키마 조회 (선택)
/plugin install sef-2026-table-structure@sef-plugin-test
```

### 로컬 테스트 (개발자용)

```bash
# 로컬 마켓플레이스 추가
/plugin marketplace add ./

# 플러그인 설치
/plugin install sef-2026@sef-plugin-test
```

---

## 목차

- [개요](#개요)
- [플러그인 구조](#플러그인-구조)
- [스킬 목록](#스킬-목록)
- [공공 vs 민간 서비스 차이점](#공공-vs-민간-서비스-차이점)
- [Claude Code 사용 예시](#claude-code-사용-예시)
- [Claude 에이전트 시스템](#claude-에이전트-시스템)

---

## 개요

이 플러그인은 **공공 기반 서비스**와 **민간 기반 서비스**의 서로 다른 아키텍처를 하나의 통합 플러그인(`sef-2026`)으로 지원합니다.

### 핵심 설계 원칙

1. **단일 플러그인**: 공공/민간 스킬을 `sef-2026` 하나로 통합 관리
2. **네이밍 규칙**: `{기능}-{유형}` 패턴으로 공공/민간 구분 (예: `backend-public`, `deployment-private`)
3. **공통 프론트엔드**: Nuxt 4 기반 공통 프론트엔드 (민간/공공 동일 소스)
4. **모듈화**: 각 스킬은 독립적으로 사용 가능하며 필요시 조합 가능

---

## 플러그인 구조

```
plugins/
├── sef-2026/                                    # 통합 플러그인
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── skills/
│   │   ├── setup/                               # 프로젝트 초기화 (공공/민간 선택)
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   │       ├── public/
│   │   │       │   ├── monolithic-structure.md
│   │   │       │   └── war-deployment.md
│   │   │       └── private/
│   │   │           └── microservice-structure.md
│   │   │
│   │   ├── frontend/                            # 공통 프론트엔드
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   │
│   │   ├── frontend-init/                       # 프론트엔드 초기화
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   │
│   │   ├── backend-public/                      # 공공 백엔드
│   │   │   ├── SKILL.md
│   │   │   ├── references/ (13개)
│   │   │   └── scripts/
│   │   │
│   │   ├── backend-private/                     # 민간 백엔드
│   │   │   ├── SKILL.md
│   │   │   ├── references/ (5개)
│   │   │   └── scripts/
│   │   │
│   │   ├── deployment-public/                   # 공공 배포
│   │   │   ├── SKILL.md
│   │   │   ├── references/ (3개)
│   │   │   └── scripts/
│   │   │
│   │   ├── deployment-private/                  # 민간 배포
│   │   │   ├── SKILL.md
│   │   │   ├── references/ (5개)
│   │   │   └── scripts/
│   │   │
│   │   ├── module-generator/                    # 도메인 모듈 생성
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   │
│   │   ├── page-generator/                      # CRUD 페이지 생성
│   │   │   ├── SKILL.md
│   │   │   └── references/
│   │   │
│   │   ├── tech-stack/                          # 기술 스택 가이드
│   │   │   └── SKILL.md
│   │   │
│   │   └── workflow-guide/                      # 워크플로우 가이드
│   │       └── SKILL.md
│   │
│   ├── agents/
│   │   ├── automation/ (5개)
│   │   ├── documentation/ (8개)
│   │   └── skill-management/ (4개)
│   │
│   ├── reference/
│   └── assets/
│
└── sef-2026-table-structure/                    # DB 스키마 조회
    ├── .claude-plugin/
    └── skills/
```

---

## 스킬 목록

### 공통 스킬

| 스킬 | 설명 |
|------|------|
| `setup` | 프로젝트 초기화 (AskUserQuestion으로 공공/민간 선택) |
| `frontend` | 공통 프론트엔드 (Nuxt 4 + TypeScript + shadcn-vue) |
| `frontend-init` | Nuxt 4 프론트엔드 scaffolding |
| `module-generator` | 도메인 모듈 세트 생성 (types + composable + store) |
| `page-generator` | 목록/상세/등록/수정 CRUD 페이지 생성 |
| `tech-stack` | 프로젝트 유형별 기술 스택 추천 |
| `workflow-guide` | Phase 1~6 워크플로우 가이드 |

### 공공 프로젝트 스킬

| 스킬 | 설명 |
|------|------|
| `backend-public` | Spring Boot 2.7 + MyBatis + eGovFrame, GET/POST만 허용 |
| `deployment-public` | WAR 빌드 → JEUS/WebLogic/Tomcat 배포 |

### 민간 프로젝트 스킬

| 스킬 | 설명 |
|------|------|
| `backend-private` | Spring Boot 3.2 + JPA + Redis + Docker |
| `deployment-private` | Docker/Kubernetes/AWS + CI/CD 배포 |

---

## 공공 vs 민간 서비스 차이점

### 공공 기반 서비스 (Public Sector)

- **단일 WAS 서버** -- 프론트엔드 + 백엔드를 하나의 WAR로 패키징
- **모듈 기반 아키텍처** -- controller/service/mapper 패턴
- **기술 스택**: Spring Boot 2.7 + MyBatis + eGovFrame + Java 8
- **WAS**: JEUS 8, WebLogic 14c/12c, Tomcat
- **HTTP 제약**: GET/POST만 허용 (정부망 정책)

```bash
# 배포 프로세스
1. cd frontend && pnpm build
2. cp -r frontend/.output/public/* src/main/resources/static/
3. ./gradlew clean build -x test  # → build/libs/sef.war
4. WAR 파일을 JEUS/WebLogic에 배포
```

### 민간 기반 서비스 (Private Sector)

- **백엔드/프론트엔드 분리** -- 각각 독립 배포
- **마이크로서비스 지향** -- Docker 컨테이너화
- **기술 스택**: Spring Boot 3.2 + JPA + Redis + Java 17
- **인프라**: Docker, Kubernetes, AWS (ECS, EKS, EC2)
- **HTTP**: RESTful API (GET/POST/PUT/DELETE)

```bash
# 배포 프로세스
1. docker build -t myapp-backend:latest ./backend
2. docker build -t myapp-frontend:latest ./frontend
3. docker push → AWS ECS/EKS 배포 또는 S3 + CloudFront
```

---

## Claude Code 사용 예시

### 프로젝트 시작

```bash
# 프로젝트 초기화 (공공/민간 선택 화면 표시)
"프로젝트를 시작해주세요"
→ 사용 스킬: setup → frontend-init

# 전체 워크플로우 확인
"어디서부터 시작해야 해?"
→ 사용 스킬: workflow-guide
```

### 공공 프로젝트 개발

```bash
"공공 프로젝트 백엔드 모듈을 만들어주세요"
→ 사용 스킬: backend-public

"WAR 파일을 JEUS에 배포해주세요"
→ 사용 스킬: deployment-public
```

### 민간 프로젝트 개발

```bash
"민간 서비스 백엔드 API를 만들어주세요"
→ 사용 스킬: backend-private

"Docker로 AWS에 배포해주세요"
→ 사용 스킬: deployment-private
```

### 프론트엔드 개발 (공통)

```bash
"게시판 도메인 모듈을 생성해주세요"
→ 사용 스킬: module-generator → page-generator
```

---

## Claude 에이전트 시스템

프로젝트에는 스킬 개발 및 관리를 지원하는 전문 에이전트 17개가 포함되어 있습니다.

| 카테고리 | 에이전트 | 설명 |
|----------|----------|------|
| **Automation** (5) | code-reviewer | 코드 리뷰 |
| | component-builder | Vue 3 + shadcn-vue 컴포넌트 생성 |
| | script-generator | 빌드/배포 스크립트 생성 |
| | security-auditor | 보안 검사 |
| | test-generator | 테스트 코드 생성 |
| **Documentation** (8) | api-designer | REST API 설계 |
| | development-planner | 개발 로드맵 생성 |
| | prd-generator | PRD 생성 |
| | prd-validator | PRD 기술 검증 |
| | reference-writer | 레퍼런스 문서 작성 |
| | screen-spec-writer | 화면 명세서 작성 |
| | starter-cleaner | 스타터킷 정리 및 초기화 |
| | ui-markup-specialist | UI/UX 마크업 전문가 (Nuxt 4) |
| **Skill Management** (4) | architecture-validator | 아키텍처 검증 |
| | db-schema-designer | DB 스키마 설계 |
| | reference-updater | references 문서 동기화 |
| | skill-creator | 스킬 생성 및 관리 |

---

## 변경 이력

### v3.0.0 (2026-03-10)
- **공공/민간 스킬을 `sef-2026` 단일 플러그인으로 통합**
- `sef-2026-public`, `sef-2026-private` 플러그인 제거
- 신규 스킬 6개: `setup`, `backend-public`, `backend-private`, `deployment-public`, `deployment-private`, `workflow-guide`
- 스킬 참조를 `sef-2026:` 통합 prefix로 업데이트

### v2.1.0 (2026-02-09)
- 공공/민간 스킬을 별도 플러그인으로 분리
- `sef-2026`: 공통 (frontend, tech-stack, agents, reference)
- `sef-2026-private`: 민간 서비스 (backend, deployment, project-init)
- `sef-2026-public`: 공공 서비스 (backend, deployment, project-init)

### v2.0.0 (2026-02-09)
- 마켓플레이스 플러그인으로 전환
- 콘텐츠를 `.claude/`에서 `plugins/sef-2026/`으로 이동

---

## 참고 자료

- [전자정부프레임워크](https://www.egovframe.go.kr/)
- [Spring Boot 공식 문서](https://spring.io/projects/spring-boot)
- [Nuxt 4 공식 문서](https://nuxt.com/)
- [Vue.js 공식 문서](https://vuejs.org/)

---

**작성자**: joonokim
**최종 수정일**: 2026-03-10
**버전**: 3.0.0
