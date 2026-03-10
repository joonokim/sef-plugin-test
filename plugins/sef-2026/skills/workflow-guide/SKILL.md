---
name: workflow-guide
description: 프로젝트 전체 생성 워크플로우 가이드. Phase 1(기획) → Phase 2(설계) → Phase 3(초기화) → Phase 4(개발) → Phase 5(품질검토) → Phase 6(배포) 순서로 스킬/에이전트 사용 안내. "프로젝트 만들어줘", "어디서부터 시작해야 해", "전체 순서 알려줘" 요청 시 사용.
---

# 공공 프로젝트 생성 워크플로우

## 전체 흐름 요약

```
Phase 1: 기획           Phase 2: 설계            Phase 3: 초기화 + 팀 구성
prd-generator       →   tech-stack           →   setup (공공)
prd-validator           architecture-validator      ├── 백엔드 초기화 ─┐
development-planner     db-schema-designer          └── frontend-init ─┤ (병렬)
                        api-designer              team-setup            ← 필수
                        screen-spec-writer
                                 ↓
Phase 4: 개발 (도메인별 반복)
  Backend:  sef-2026:backend-public
  Frontend: module-generator → page-generator → component-builder (선택)
                                 ↓
Phase 5: 품질 검토          Phase 6: 배포
code-reviewer           →   sef-2026:deployment-public
security-auditor
test-generator
reference-updater
```

---

## Phase 1: 기획

| 순서 | 에이전트 | 역할 | 입력 | 산출물 |
|------|---------|------|------|--------|
| 1 | `prd-generator` | PRD 문서 생성 | 프로젝트 아이디어/요구사항 | `docs/PRD.md` |
| 2 | `prd-validator` | PRD 기술 검증 | `docs/PRD.md` | 검증 보고서 |
| 3 | `development-planner` | 개발 로드맵 생성 | `docs/PRD.md` | `docs/ROADMAP.md` |

---

## Phase 2: 설계

| 순서 | 스킬/에이전트 | 역할 | 산출물 |
|------|-------------|------|--------|
| 4 | `sef-2026:tech-stack` | 기술 스택 확인 (Nuxt 4 + Spring Boot + MyBatis + Oracle) | 기술 스택 문서 |
| 5 | `architecture-validator` | 단일 WAS 구조 (WAR) 적합성 검증 | 아키텍처 검증 보고서 |
| 6 | `db-schema-designer` | ERD + DDL + MyBatis VO/Mapper XML 설계 | DB DDL 스크립트 |
| 7 | `api-designer` | RESTful API 명세 (GET/POST only 정책 반영) | `docs/api-spec/openapi.yaml` |
| 8 | `screen-spec-writer` | 화면 명세서 (화면 ID, 입출력, 버튼 동작, API 연동) | `docs/screen-spec/{domain}-screen-spec.md` |

### 공공 프로젝트 설계 핵심 제약

- HTTP 메서드: **GET, POST만 허용** (PUT/DELETE 금지 -- 정부망 정책)
- 수정: `POST /api/v1/{resource}/{id}/update`
- 삭제: `POST /api/v1/{resource}/{id}/delete`
- 관리자 API prefix: `/adm/v1/`
- 일반 API prefix: `/api/v1/`

---

## Phase 3: 프로젝트 초기화

### Step 1: 백엔드 구조 생성

**스킬**: `sef-2026:setup` (공공 선택)

```
{project}/
├── frontend/                          ← 프로젝트 루트 레벨 (NOT backend/frontend/)
├── src/main/java/com/sqisoft/sef/
│   ├── core/                          # ApiResponse, ErrorCode, Audit
│   ├── infra/                         # Security, MyBatis, eGovFrame 설정
│   └── modules/                       # 업무 모듈
├── src/main/resources/
│   ├── mybatis/mapper/
│   ├── properties/{local,dev,prod}/env.properties
│   └── static/                        ← Nuxt 빌드 출력 대상
└── build.gradle.kts                   # Kotlin DSL, Java 8, Spring Boot 2.7.18
```

### Step 2: 프론트엔드 초기화

**스킬**: `sef-2026:frontend-init`

공공 프로젝트 `nuxt.config.ts` 필수 설정:
```typescript
nitro: {
  preset: 'static',
  output: { dir: '../src/main/resources/static' }
},
app: { baseURL: '/[프로젝트코드]/' }
```

참조:
- `sef-2026:frontend-init` → `references/config-templates.md` (공공 WAR 배포 설정)
- `sef-2026:frontend-init` → `references/boilerplate-files.md` (types, composables, stores, layouts)

---

## Phase 4: 도메인별 개발 (반복)

### Backend 개발

**스킬**: `sef-2026:backend-public`

```
modules/{domain}/
├── controller/   # @GetMapping, @PostMapping only (PUT/DELETE 없음)
├── domain/       # Entity/VO
├── dto/
│   ├── request/  # @Valid 요청 DTO
│   └── response/ # 응답 DTO
├── mapper/       # MyBatis @Mapper (eGovFrame)
└── service/      # Interface + ServiceImpl (extends EgovAbstractServiceImpl)
```

참조 문서:
- `api-conventions.md`: URL 패턴, ApiResponse 형식
- `security-setup.md`: JWT (`security.jwt.secret-key`)
- `mybatis-config.md`: MyBatis 설정
- `egovframework.md`: eGovFrame 규칙

### Frontend 개발 (도메인당 3단계)

| 단계 | 스킬/에이전트 | 생성 파일 |
|------|-------------|---------|
| 1 | `sef-2026:module-generator` | `types/api/{domain}.ts`, `composables/use{Domain}.ts` |
| 2 | `sef-2026:page-generator` | 목록/상세/폼 페이지 (`pages/{prefix}/{domain}/`) |
| 3 | `component-builder` *(선택)* | 복잡한 폼, 커스텀 컴포넌트 |

> `page-generator` 실행 전 반드시 `module-generator`로 types + composable 먼저 생성할 것.

---

## Phase 5: 품질 검토

| 에이전트 | 검토 항목 |
|---------|---------|
| `code-reviewer` | 코드 품질, 보안, 성능, eGovFrame 규칙 준수 |
| `security-auditor` | OWASP Top 10, 공공기관 보안 가이드 (CC 인증, ISMS-P) |
| `test-generator` | JUnit 5 단위테스트, 통합테스트 생성 |
| `reference-updater` | references 문서와 실제 소스 일치 여부 검증 |

---

## Phase 6: 배포

**스킬**: `sef-2026:deployment-public`

빌드 순서:
```bash
# 1. 프론트엔드 빌드 (static 파일을 src/main/resources/static/ 에 생성)
cd frontend && pnpm build

# 2. WAR 패키징
./gradlew clean build -x test
# → build/libs/sef.war

# 3. WAS 배포 (JEUS 8 / WebLogic 14c / Tomcat)
# 참조: deployment-public/references/jeus-deployment.md
# 참조: deployment-public/references/weblogic-deployment.md

# 4. 환경 프로필 지정
# JVM 옵션: -Dspring.profiles.active=prod
```

---

## 전체 순서 체크리스트

```
□ 1.  prd-generator         PRD 작성
□ 2.  prd-validator         PRD 검증
□ 3.  development-planner   ROADMAP 생성
□ 4.  tech-stack            기술 스택 확인
□ 5.  architecture-validator 아키텍처 검증
□ 6.  db-schema-designer    DB 스키마 설계
□ 7.  api-designer          API 설계
□ 8.  screen-spec-writer    화면 명세서 작성
□ 9.  setup (공공)          백엔드 프로젝트 구조 생성
□ 10. frontend-init         프론트엔드 초기화 (9와 병렬 가능)
□ 11. team-setup            AI 개발 팀 구성 (에이전트 병렬 개발)

  [도메인별 반복]
□ 12. backend-public        백엔드 모듈 개발
□ 13. module-generator      프론트 types + composable 생성
□ 14. page-generator        프론트 페이지 생성
□ 15. component-builder     복잡 컴포넌트 생성 (선택)

  [검토]
□ 16. code-reviewer         코드 리뷰
□ 17. security-auditor      보안 검토
□ 18. test-generator        테스트 생성
□ 19. reference-updater     문서 일치 검증

  [배포]
□ 20. deployment-public     WAR 빌드 → WAS 배포
```

---

## 관련 스킬

- `sef-2026:setup` -- 프로젝트 초기화 (공공/민간 선택)
- `sef-2026:backend-public` -- 공공 백엔드 모듈 개발
- `sef-2026:deployment-public` -- WAR 빌드 및 배포
- `sef-2026:frontend-init` -- 프론트엔드 초기화
- `sef-2026:module-generator` -- 도메인 모듈 세트 생성
- `sef-2026:page-generator` -- CRUD 페이지 생성
- `sef-2026:team-setup` -- AI 개발 팀 구성 (에이전트 팀)
- `sef-2026:tech-stack` -- 기술 스택 가이드
