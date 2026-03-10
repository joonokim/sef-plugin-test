# sqisoft-sef-2026-plugin

공공/민간 서비스 개발을 위한 Claude Code 플러그인 마켓플레이스입니다.

## 설치 방법

### 1. 마켓플레이스 추가

```bash
/plugin marketplace add sqi-energy/sqisoft-sef-2026-plugin
```

### 2. 플러그인 설치

```bash
# 공통 (프론트엔드, 기술 스택, 에이전트)
/plugin install sef-2026@sqisoft-sef-2026

# 민간 서비스 스킬
/plugin install sef-2026-private@sqisoft-sef-2026

# 공공 서비스 스킬
/plugin install sef-2026-public@sqisoft-sef-2026
```

### 로컬 테스트 (개발자용)

```bash
# 로컬 마켓플레이스 추가
/plugin marketplace add ./

# 플러그인 설치
/plugin install sef-2026@sqisoft-sef-2026
/plugin install sef-2026-private@sqisoft-sef-2026
/plugin install sef-2026-public@sqisoft-sef-2026
```

---

## 목차

- [개요](#개요)
- [플러그인 구조](#플러그인-구조)
- [공공 vs 민간 서비스 차이점](#공공-vs-민간-서비스-차이점)
- [스킬 상세 설명](#스킬-상세-설명)
- [Claude Code 사용 예시](#claude-code-사용-예시)
- [Claude 에이전트 시스템](#claude-에이전트-시스템)

---

## 개요

이 플러그인은 **공공 기반 서비스**와 **민간 기반 서비스**의 서로 다른 아키텍처를 지원하면서, 공통 기능은 재사용할 수 있도록 설계되었습니다.

### 핵심 설계 원칙

1. **공통 프론트엔드**: Nuxt 4 기반 공통 프론트엔드 (민간/공공 동일 소스)
2. **환경별 구조 분리**: 공공/민간의 다른 배포 구조를 별도 스킬로 관리
3. **모듈화**: 각 스킬은 독립적으로 사용 가능하며 필요시 조합 가능

### 포함 콘텐츠

| 플러그인 | 스킬 | 설명 |
|----------|------|------|
| **sef-2026** (공통) | frontend, tech-stack | 공통 프론트엔드, 기술 스택 가이드, 에이전트 14개 |
| **sef-2026-private** (민간) | backend, deployment, project-init | 민간 서비스 개발 스킬 |
| **sef-2026-public** (공공) | backend, deployment, project-init | 공공 서비스 개발 스킬 |

---

## 플러그인 구조

```
plugins/
├── sef-2026/                                    # 공통 플러그인
│   ├── .claude-plugin/
│   │   └── plugin.json
│   ├── skills/
│   │   ├── frontend/                            # 공통 프론트엔드 (민간/공공 동일)
│   │   │   ├── SKILL.md
│   │   │   ├── README.md
│   │   │   └── references/
│   │   │       ├── api-client.md
│   │   │       ├── deployment-private.md
│   │   │       ├── deployment-public.md
│   │   │       ├── nuxt-setup.md
│   │   │       ├── routing.md
│   │   │       └── state-management.md
│   │   │
│   │   └── tech-stack/                          # 기술 스택 가이드
│   │       └── SKILL.md
│   │
│   ├── agents/
│   │   ├── automation/                          # 자동화 (4개)
│   │   │   ├── code-reviewer.md
│   │   │   ├── script-generator.md
│   │   │   ├── security-auditor.md
│   │   │   └── test-generator.md
│   │   ├── documentation/                       # 문서 작성 (7개)
│   │   │   ├── api-designer.md
│   │   │   ├── development-planner.md
│   │   │   ├── prd-generator.md
│   │   │   ├── prd-validator.md
│   │   │   ├── reference-writer.md
│   │   │   ├── starter-cleaner.md
│   │   │   └── ui-markup-specialist.md
│   │   └── skill-management/                    # 스킬 관리 (3개)
│   │       ├── architecture-validator.md
│   │       ├── db-schema-designer.md
│   │       └── skill-creator.md
│   │
│   ├── reference/
│   └── assets/
│
├── sef-2026-public/                             # 공공 서비스 플러그인
│   ├── .claude-plugin/
│   │   └── plugin.json
│   └── skills/
│       ├── project-init/                        # 프로젝트 초기화
│       │   ├── SKILL.md
│       │   └── references/
│       │       ├── monolithic-structure.md
│       │       └── war-deployment.md
│       ├── backend/                             # 백엔드
│       │   ├── SKILL.md
│       │   ├── references/
│       │   │   ├── api-conventions.md
│       │   │   ├── ddd-architecture.md
│       │   │   ├── egovframework.md
│       │   │   ├── folder-structure.md
│       │   │   ├── frontend-integration.md
│       │   │   ├── mybatis-config.md
│       │   │   ├── security-setup.md
│       │   │   └── spring-boot-setup.md
│       │   └── scripts/
│       │       └── build_with_nuxt.sh
│       └── deployment/                          # 배포
│           ├── SKILL.md
│           ├── references/
│           │   ├── jeus-deployment.md
│           │   ├── war-build-process.md
│           │   └── weblogic-deployment.md
│           └── scripts/
│               ├── build_war.sh
│               └── deploy_to_jeus.sh
│
└── sef-2026-private/                            # 민간 서비스 플러그인
    ├── .claude-plugin/
    │   └── plugin.json
    └── skills/
        ├── project-init/                        # 프로젝트 초기화
        │   ├── SKILL.md
        │   └── references/
        │       └── microservice-structure.md
        ├── backend/                             # 백엔드
        │   ├── SKILL.md
        │   ├── references/
        │   │   ├── docker-setup.md
        │   │   ├── folder-structure.md
        │   │   ├── jpa-setup.md
        │   │   ├── redis-cache.md
        │   │   └── spring-boot-api.md
        │   └── scripts/
        │       └── generate_api_scaffold.py
        └── deployment/                          # 배포
            ├── SKILL.md
            ├── references/
            │   ├── aws-deployment.md
            │   ├── ci-cd-pipeline.md
            │   ├── docker-compose.md
            │   ├── kubernetes.md
            │   └── nginx-config.md
            └── scripts/
                ├── build_containers.sh
                ├── deploy_backend.sh
                └── deploy_frontend.sh
```

---

## 공공 vs 민간 서비스 차이점

### 공공 기반 서비스 (Public Sector)

#### 아키텍처 특징
- **단일 WAS 서버** 구조
- 프론트엔드가 백엔드 프로젝트 별도 폴더에 위치 (`backend/frontend/`)
- Nuxt 빌드 후 Spring Boot WAR에 함께 패키징
- 하나의 배포 단위 (WAR 파일)
- **DDD + Hexagonal Architecture** 모듈형 구조

#### 기술 스택
- **WAS**: JEUS 8, WebLogic, Tomcat
- **프레임워크**: 전자정부프레임워크, Spring Boot 2.7
- **Java**: OpenJDK 8
- **프론트엔드**: Nuxt 4 + TypeScript (별도 폴더)
- **데이터베이스**: Oracle, Tibero
- **ORM**: MyBatis

#### 배포 프로세스
```bash
1. Nuxt 4 프로젝트 빌드 (cd frontend && npm run build)
2. 빌드 결과물(.output/public)을 백엔드 resources/static에 복사
3. Spring Boot WAR 패키징 (gradle clean build)
4. WAR 파일을 JEUS/WebLogic에 배포
```

---

### 민간 기반 서비스 (Private Sector)

#### 아키텍처 특징
- **백엔드와 프론트엔드 분리** 구조
- 각각 독립된 서버에 배포
- API 기반 통신 (RESTful API)
- 마이크로서비스 지향

#### 기술 스택
- **백엔드**: Spring Boot (JAR), Node.js
- **프론트엔드**: Nuxt 4, React, Next.js (독립 실행)
- **데이터베이스**: PostgreSQL, MySQL, MongoDB
- **ORM**: JPA/Hibernate
- **인프라**: Docker, Kubernetes, AWS

#### 배포 프로세스
```bash
# 백엔드 배포
1. Spring Boot JAR 빌드 (mvn package)
2. Docker 이미지 생성
3. AWS ECS/EKS 또는 EC2에 배포

# 프론트엔드 배포
1. Nuxt 4/React/Next.js 빌드 (npm run build)
2. Docker 이미지 생성 또는 정적 파일 배포
3. AWS S3/CloudFront, Vercel, Netlify에 배포
```

---

## 스킬 상세 설명

### 1. frontend - 공통 프론트엔드 (민간/공공 동일)

**목적**: 민간/공공 공통 프론트엔드 개발

**주요 기능**:
- Nuxt 4 + TypeScript 프로젝트 설정
- 파일 기반 라우팅 (pages/)
- Pinia 상태 관리
- shadcn-vue 컴포넌트 라이브러리
- API 클라이언트 패턴
- 환경별 배포 전략

**기술 스택**:
- **프레임워크**: Nuxt 4
- **언어**: TypeScript
- **UI 라이브러리**: shadcn-vue (Radix Vue + Tailwind CSS)
- **상태 관리**: Pinia
- **폼 검증**: vee-validate + Zod
- **아이콘**: Lucide Vue Next
- **토스트**: vue-sonner

---

### 2. sef-2026-public - 공공 서비스 스킬 (별도 플러그인)

#### project-init (프로젝트 초기화)
- 단일 WAS 구조 프로젝트 템플릿
- 전자정부프레임워크 기반 설정

#### backend (백엔드)
- Spring Boot 2.7 설정 (WAR 패키징)
- DDD + Hexagonal Architecture 모듈형 구조
- MyBatis, 전자정부프레임워크 통합

#### deployment (배포)
- WAR 파일 빌드
- JEUS/WebLogic 배포 자동화

---

### 3. sef-2026-private - 민간 서비스 스킬 (별도 플러그인)

#### project-init (프로젝트 초기화)
- 백엔드/프론트엔드 분리 구조
- 마이크로서비스 기반 설정

#### backend (백엔드)
- Spring Boot API 서버 (JAR 패키징)
- JPA/Hibernate, Redis 캐싱
- Docker 컨테이너화

#### deployment (배포)
- Docker/Kubernetes 배포
- AWS (ECS, EKS, EC2)
- CI/CD 파이프라인

---

### 4. tech-stack - 기술 스택 가이드 (sef-2026 공통 플러그인)

**추천 스택**:
- 공공: Nuxt 4 + Spring Boot 2.7 + MyBatis + Oracle + JEUS 8
- 민간: Nuxt 4/Next.js + Spring Boot/Node.js + JPA/Prisma + PostgreSQL + Docker + AWS

---

## Claude Code 사용 예시

### 공공 프로젝트 시작

```bash
# 프로젝트 초기화
"공공기관용 프로젝트를 Nuxt 4 + Spring Boot로 만들어주세요."

→ 사용되는 스킬:
  - project-init (sef-2026-public)
  - backend (sef-2026-public)
  - frontend (sef-2026)
```

### 민간 프로젝트 시작

```bash
# 프로젝트 초기화
"민간 서비스를 Nuxt 4 + Spring Boot로 만들어주세요. 백엔드와 프론트엔드를 분리해주세요."

→ 사용되는 스킬:
  - project-init (sef-2026-private)
  - backend (sef-2026-private)
  - frontend (sef-2026)
```

### 배포

```bash
# 공공 서비스 배포
"Nuxt 4를 빌드하고 Spring Boot와 함께 WAR로 패키징해서 JEUS에 배포해주세요."
→ 사용되는 스킬: deployment (sef-2026-public)

# 민간 서비스 배포
"Nuxt 4와 Spring Boot를 Docker로 컨테이너화하고 AWS ECS에 배포해주세요."
→ 사용되는 스킬: deployment (sef-2026-private)
```

---

## Claude 에이전트 시스템

프로젝트에는 스킬 개발 및 관리를 지원하는 전문 에이전트들이 포함되어 있습니다.

### 에이전트 구조

| 카테고리 | 에이전트 | 설명 |
|----------|----------|------|
| **Skill Management** (3) | skill-creator | 스킬 생성 및 관리 |
| | architecture-validator | 아키텍처 검증 |
| | db-schema-designer | 데이터베이스 스키마 설계 |
| **Documentation** (7) | reference-writer | 레퍼런스 문서 작성 |
| | prd-generator | PRD 생성 |
| | prd-validator | PRD 검증 |
| | api-designer | REST API 설계 |
| | development-planner | 개발 계획 수립 |
| | starter-cleaner | 스타터킷 정리 및 초기화 |
| | ui-markup-specialist | UI/UX 마크업 전문가 (Nuxt 4) |
| **Automation** (4) | script-generator | 스크립트 생성 |
| | code-reviewer | 코드 리뷰 |
| | test-generator | 테스트 코드 생성 |
| | security-auditor | 보안 검사 |

---

## 변경 이력

### v2.1.0 (2026-02-09)
- **공공/민간 스킬을 별도 플러그인으로 분리**
- `sef-2026`: 공통 (frontend, tech-stack, agents, reference)
- `sef-2026-private`: 민간 서비스 (backend, deployment, project-init)
- `sef-2026-public`: 공공 서비스 (backend, deployment, project-init)
- Claude Code 스킬 탐색 정상화 (`skills/<name>/SKILL.md` 1단계 중첩)

### v2.0.0 (2026-02-09)
- **마켓플레이스 플러그인으로 전환**
- 콘텐츠를 `.claude/`에서 `plugins/sef-2026/`으로 이동
- `.claude-plugin/marketplace.json` 및 `plugin.json` 추가
- 올인원(1개 플러그인) 방식으로 모든 스킬/에이전트 제공

---

## 참고 자료

- [전자정부프레임워크](https://www.egovframe.go.kr/)
- [Spring Boot 공식 문서](https://spring.io/projects/spring-boot)
- [Nuxt 4 공식 문서](https://nuxt.com/)
- [Vue.js 공식 문서](https://vuejs.org/)

---

## 라이선스

이 플러그인은 프로젝트 내부용입니다. 각 스킬의 라이선스는 해당 스킬의 LICENSE.txt를 참조하세요.

---

**작성자**: SQI Energy
**최종 수정일**: 2026-02-09
**버전**: 2.1.0
