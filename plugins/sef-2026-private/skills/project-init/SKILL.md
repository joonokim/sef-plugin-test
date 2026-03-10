---
name: project-init
description: 민간 서비스 프로젝트 초기 구조 생성. 백엔드와 프론트엔드 분리 구조, 마이크로서비스 기반, Docker 설정 포함, CI/CD 파이프라인 템플릿. 민간 기업 프로젝트를 시작하거나 초기화할 때 사용.
---

# 민간 서비스 프로젝트 초기화

## 개요

민간 기업(스타트업, 일반 기업, SaaS 서비스 등)을 위한 프로젝트 초기 구조를 생성하는 스킬입니다.

### 주요 특징

- **백엔드와 프론트엔드 분리** 구조
- 각각 독립된 서버에 배포
- API 기반 통신 (RESTful API)
- 마이크로서비스 지향 아키텍처
- Docker 컨테이너화 지원
- CI/CD 파이프라인 템플릿 포함

## 사용 시나리오

- "민간 서비스 프로젝트를 시작해주세요"
- "백엔드와 프론트엔드를 분리한 프로젝트를 만들어주세요"
- "마이크로서비스 구조로 프로젝트를 초기화해주세요"
- "Docker를 사용하는 프로젝트를 만들어주세요"

## 생성되는 프로젝트 구조

```
project/
├── backend/                          # 독립된 백엔드 프로젝트
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/
│   │   │   │   └── com/example/
│   │   │   │       ├── controller/
│   │   │   │       ├── service/
│   │   │   │       ├── repository/
│   │   │   │       ├── domain/
│   │   │   │       └── dto/
│   │   │   └── resources/
│   │   │       └── application.yml
│   │   └── test/
│   ├── Dockerfile
│   ├── pom.xml
│   └── README.md
│
├── frontend/                         # 독립된 프론트엔드 프로젝트
│   ├── src/ (또는 app/)
│   │   ├── components/
│   │   ├── pages/
│   │   ├── stores/
│   │   └── utils/
│   ├── Dockerfile
│   ├── package.json
│   ├── nuxt.config.ts (또는 next.config.js, vite.config.ts)
│   └── README.md
│
├── docker-compose.yml                # 로컬 개발 환경
├── .github/
│   └── workflows/
│       ├── backend-ci.yml
│       └── frontend-ci.yml
└── README.md
```

## 기술 스택 옵션

### 백엔드

- **Spring Boot** (JAR 패키징) - Java/Kotlin
- **Node.js** + Express/NestJS - TypeScript
- **Django/FastAPI** - Python

### 프론트엔드

- **Nuxt 4** - Vue 3 + TypeScript, SSR/SSG/SPA
- **Next.js** - React + TypeScript, SSR/SSG
- **React** - SPA, Vite
- **Vue 3** - SPA, Vite

### 데이터베이스

- PostgreSQL
- MySQL/MariaDB
- MongoDB

### 인프라

- Docker & Docker Compose
- Kubernetes
- AWS (ECS, EKS, EC2, S3, CloudFront)
- Vercel, Netlify (프론트엔드)

## 초기화 단계

1. 프로젝트 루트 디렉토리 생성
2. 백엔드 프로젝트 초기화
   - Spring Boot / Node.js / Python 선택
   - Maven/Gradle 또는 npm/yarn 설정
   - Dockerfile 생성
3. 프론트엔드 프로젝트 초기화
   - Nuxt 4 / Next.js / React / Vue 선택
   - 패키지 매니저 설정
   - Dockerfile 생성
4. Docker Compose 설정
5. CI/CD 파이프라인 템플릿 생성
6. 환경변수 관리 설정 (.env.example)
7. README.md 생성

## Docker Compose 예시

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

## 환경변수 관리

### 백엔드 (.env)

```bash
# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=mydb
DB_USER=user
DB_PASSWORD=password

# JWT
JWT_SECRET=your-secret-key
JWT_EXPIRATION=86400000

# AWS (선택사항)
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=ap-northeast-2
```

### 프론트엔드 (.env)

```bash
# API
NUXT_PUBLIC_API_BASE_URL=http://localhost:8080/api

# OAuth (선택사항)
NUXT_PUBLIC_GOOGLE_CLIENT_ID=
NUXT_PUBLIC_GITHUB_CLIENT_ID=
```

## 참고 자료

자세한 내용은 다음 문서를 참조하세요:
- `references/microservice-structure.md`: 마이크로서비스 아키텍처 설명
- `assets/private-project-template/`: 프로젝트 템플릿

## 관련 스킬

- `backend`: 민간 백엔드 개발
- `frontend` (sef-2026 플러그인): 공통 프론트엔드 개발
- `deployment`: 민간 서비스 배포
- `tech-stack` (sef-2026 플러그인): 기술 스택 선택 가이드
