---
name: setup
description: 프로젝트 초기 구조 생성 (공공/민간 통합). 공공(단일 WAR, MyBatis, eGovFrame) 또는 민간(백엔드/프론트엔드 분리, Docker, 마이크로서비스) 프로젝트를 선택하여 초기화. "프로젝트 시작", "프로젝트 초기화", "setup", "프로젝트 만들어줘" 요청 시 사용.
---

# 프로젝트 초기화 (공공/민간 통합)

## 개요

SEF 2026 기반 프로젝트의 초기 구조를 생성합니다. 공공(정부/공공기관)과 민간(기업/스타트업) 두 가지 유형을 지원합니다.

## Step 0: 프로젝트 유형 선택

**반드시 AskUserQuestion 도구를 사용하여 프로젝트 유형을 확인합니다:**

```
질문: "프로젝트 유형을 선택해주세요."
선택지:
  - "public" (공공 프로젝트: 단일 WAR, MyBatis, eGovFrame, JEUS/WebLogic/Tomcat)
  - "private" (민간 프로젝트: 백엔드/프론트엔드 분리, Docker, 마이크로서비스)
```

선택에 따라 아래 Path A 또는 Path B를 실행합니다.

---

## Path A: 공공 프로젝트 (public)

### 특징

- **단일 WAS 서버** -- 하나의 WAR 파일에 프론트엔드 + 백엔드 포함
- **모듈 기반 아키텍처** -- controller/service/mapper 레이어링 (DDD/Hexagonal 아님)
- **프론트엔드는 프로젝트 루트** (`frontend/`, NOT `backend/frontend/`)
- **Nuxt 4 빌드 출력**을 `src/main/resources/static/`에 복사하여 WAR에 패키징
- **MyBatis** + eGovFrame 4.1 `@Mapper` 어노테이션
- **Gradle Kotlin DSL** (`build.gradle.kts`, NOT Maven)
- **Java 8** (OpenJDK 1.8, JEUS 8 호환)
- **패키지 매니저**: pnpm (NOT npm)

### 기술 스택

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Spring Boot | 2.7.18 |
| Java | OpenJDK | 8 |
| Build | Gradle Kotlin DSL | - |
| ORM | MyBatis | 2.3.1 |
| Gov Framework | eGovFrame | 4.1.0 |
| Frontend | Nuxt 4 + Vue 3 + TypeScript | - |
| Security | Spring Security + JWT (jjwt) | 0.11.5 |
| Database | PostgreSQL / Oracle | - |
| WAS | JEUS 8, WebLogic 14c/12c, Tomcat | - |

### 프로젝트 구조

```
{project}/
├── frontend/                          # Nuxt 4 (프로젝트 루트 레벨)
│   ├── app.vue
│   ├── pages/
│   ├── components/
│   ├── composables/
│   ├── stores/
│   ├── layouts/
│   ├── types/
│   ├── nuxt.config.ts
│   └── package.json                   # pnpm
│
├── src/main/java/com/sqisoft/sef/
│   ├── SefApplication.java
│   ├── ServletInitializer.java        # WAR deployment entry point
│   ├── core/                          # 공유 유틸리티
│   │   ├── audit/                     # @AuditLog annotation, AuditLogAspect
│   │   ├── dto/                       # ApiResponse, PageRequest
│   │   ├── enums/                     # ErrorCode
│   │   ├── exception/                 # GlobalExceptionHandler
│   │   └── utils/                     # Excel, Mail, File, Password, Time utils
│   ├── infra/                         # 인프라 설정
│   │   ├── config/                    # Jackson, Async, Scheduling, Swagger
│   │   ├── persistence/               # Database config
│   │   ├── security/                  # WebSecurity, JWT
│   │   ├── egovframe/                 # eGovFrame integration
│   │   ├── otp/                       # OTP support
│   │   └── scheduler/                 # Token cleanup, Dormancy, Password change
│   └── modules/                       # 업무 모듈
│       └── {module}/
│           ├── controller/
│           ├── domain/
│           ├── dto/request/ + response/
│           ├── mapper/                # MyBatis
│           └── service/ + impl/
│
├── src/main/resources/
│   ├── mybatis/config/ + mapper/
│   ├── properties/{local,dev,prod}/env.properties
│   ├── application.yml
│   └── static/                        # Nuxt 빌드 출력 대상
│
├── build.gradle.kts
└── gradlew / gradlew.bat
```

### 초기화 단계

1. 프로젝트 루트 디렉토리 생성

2. 병렬 실행 (독립적이므로 동시 처리):
   - **[A] 백엔드 초기화**
     - `build.gradle.kts` 설정 (Spring Boot 2.7.18, Java 8, WAR 패키징)
     - `src/main/java/` 패키지 구조 생성 (core, infra, modules)
     - `src/main/resources/` 설정 파일 생성
   - **[B] 프론트엔드 초기화**
     - `frontend/` 디렉토리 생성 후 `sef-2026:frontend-init` 호출

3. 개발 팀 구성: `sef-2026:team-setup` 호출

### 참고 자료

- `references/public/monolithic-structure.md` -- 단일 WAR 아키텍처 및 모듈 레이아웃
- `references/public/war-deployment.md` -- WAR 빌드 및 WAS 배포 가이드

---

## Path B: 민간 프로젝트 (private)

### 특징

- **백엔드와 프론트엔드 분리** 구조
- 각각 독립된 서버에 배포
- API 기반 통신 (RESTful API)
- 마이크로서비스 지향 아키텍처
- Docker 컨테이너화 지원
- CI/CD 파이프라인 템플릿 포함

### 기술 스택 옵션

**백엔드:**
- **Spring Boot 3.2** (JAR 패키징) - Java 17/Kotlin
- **Node.js** + Express/NestJS - TypeScript
- **Django/FastAPI** - Python

**프론트엔드:**
- **Nuxt 4** - Vue 3 + TypeScript, SSR/SSG/SPA
- **Next.js** - React + TypeScript
- **React/Vue 3** - SPA, Vite

**데이터베이스:**
- PostgreSQL, MySQL/MariaDB, MongoDB

**인프라:**
- Docker & Docker Compose
- Kubernetes
- AWS (ECS, EKS, EC2, S3, CloudFront)

### 프로젝트 구조

```
project/
├── backend/                          # 독립된 백엔드 프로젝트
│   ├── src/main/java/com/example/
│   │   ├── config/                   # SecurityConfig, RedisConfig, JpaConfig
│   │   ├── controller/
│   │   ├── service/
│   │   ├── repository/               # JPA Repository
│   │   ├── domain/                   # JPA Entity
│   │   ├── dto/request/ + response/
│   │   ├── security/                 # JWT
│   │   └── exception/
│   ├── src/main/resources/
│   │   ├── application.yml
│   │   └── application-{env}.yml
│   ├── Dockerfile
│   └── pom.xml (또는 build.gradle)
│
├── frontend/                         # 독립된 프론트엔드 프로젝트
│   ├── app/ (또는 src/)
│   │   ├── components/
│   │   ├── pages/
│   │   ├── stores/
│   │   └── utils/
│   ├── Dockerfile
│   ├── package.json
│   └── nuxt.config.ts
│
├── docker-compose.yml                # 로컬 개발 환경
├── .github/workflows/
│   ├── backend-ci.yml
│   └── frontend-ci.yml
└── README.md
```

### Docker Compose 설정

```yaml
version: '3.8'

services:
  backend:
    build: ./backend
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=dev
      - DB_HOST=postgres
    depends_on:
      - postgres

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - API_BASE_URL=http://backend:8080

  postgres:
    image: postgres:15
    environment:
      - POSTGRES_DB=mydb
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

### 환경변수 관리

**백엔드 (.env)**
```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=mydb
DB_USER=user
DB_PASSWORD=password
JWT_SECRET=your-secret-key
JWT_EXPIRATION=86400000
```

**프론트엔드 (.env)**
```bash
NUXT_PUBLIC_API_BASE_URL=http://localhost:8080/api
```

### 초기화 단계

1. 프로젝트 루트 디렉토리 생성

2. 병렬 실행 (독립적이므로 동시 처리):
   - **[A] 백엔드 프로젝트 초기화** (Spring Boot / Node.js / Python 선택)
   - **[B] 프론트엔드 프로젝트 초기화** → `sef-2026:frontend-init` 호출
   - **[C] Docker Compose + CI/CD 설정**

3. 환경변수 관리 설정 (.env.example)

4. 개발 팀 구성: `sef-2026:team-setup` 호출

### 참고 자료

- `references/private/microservice-structure.md` -- 마이크로서비스 아키텍처 설명

---

## 공통 후속 단계

프로젝트 초기화 완료 후:

1. **개발 팀 구성**: `sef-2026:team-setup` 스킬을 실행하여 AI 에이전트 팀 구성. ROADMAP.md 기반 작업 분해 및 병렬 개발 시작.
2. **백엔드 개발**: 프로젝트 유형에 따라 `sef-2026:backend-public` 또는 `sef-2026:backend-private` 사용
3. **배포**: 프로젝트 유형에 따라 `sef-2026:deployment-public` 또는 `sef-2026:deployment-private` 사용

## 관련 스킬

- `sef-2026:frontend-init` -- 프론트엔드 초기화
- `sef-2026:frontend` -- 공통 프론트엔드 개발
- `sef-2026:backend-public` -- 공공 백엔드 개발
- `sef-2026:backend-private` -- 민간 백엔드 개발
- `sef-2026:deployment-public` -- 공공 배포
- `sef-2026:deployment-private` -- 민간 배포
- `sef-2026:tech-stack` -- 기술 스택 선택 가이드
- `sef-2026:team-setup` -- AI 개발 팀 구성
- `sef-2026:workflow-guide` -- 프로젝트 워크플로우 가이드
