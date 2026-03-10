---
name: tech-stack
description: 프로젝트 유형별 최적 기술 스택 추천 및 선택 가이드. 프론트엔드(Nuxt 4, React, Next.js), 백엔드(Spring Boot, Node.js), 데이터베이스, 공공/민간 서비스 스택 비교. 기술 스택 선택이 필요할 때 사용.
---

# 기술 스택 가이드

## 개요

프로젝트 유형과 요구사항에 따라 최적의 기술 스택을 선택하는 가이드입니다.

## 사용 시나리오

- "어떤 기술 스택을 선택해야 하나요?"
- "Nuxt 4와 Next.js 중 무엇을 사용해야 하나요?"
- "공공 프로젝트에 적합한 기술은 무엇인가요?"
- "마이크로서비스 구조에 맞는 기술 스택을 추천해주세요"

## 프로젝트 유형별 추천 스택

### 공공 기관 프로젝트

**특징**:
- 단일 WAS 서버 배포
- 전자정부프레임워크 요구사항
- 안정성 및 호환성 중시
- Oracle/Tibero 데이터베이스

**추천 스택**:
```
프론트엔드: Nuxt 4 + TypeScript
백엔드: Spring Boot + MyBatis
데이터베이스: Oracle / Tibero
WAS: JEUS / WebLogic / Tomcat
배포: WAR 패키징
```

자세한 내용은 `references/public-tech-stack.md` 참조

### 민간 기업 프로젝트

**특징**:
- 백엔드/프론트엔드 분리
- 마이크로서비스 아키텍처
- 빠른 개발 및 배포
- 클라우드 네이티브

**추천 스택**:
```
프론트엔드: Nuxt 4 / Next.js / React
백엔드: Spring Boot (JAR) / Node.js
데이터베이스: PostgreSQL / MySQL / MongoDB
인프라: Docker, Kubernetes, AWS
배포: 컨테이너 기반
```

자세한 내용은 `references/private-tech-stack.md` 참조

## 프론트엔드 기술 스택

### Nuxt 4 (Vue 3)

**장점**:
- SSR, SSG, SPA 모두 지원
- 파일 기반 라우팅
- Auto-imports (자동 임포트)
- TypeScript 완벽 지원
- SEO 최적화
- 풍부한 모듈 생태계 (Nuxt UI, Nuxt Content 등)

**단점**:
- React보다 작은 생태계
- 학습 곡선

**추천 시나리오**:
- SEO가 중요한 서비스
- 빠른 개발이 필요한 프로젝트
- Vue 생태계 선호
- 공공/민간 모두 적합

### Next.js (React)

**장점**:
- SSR, SSG, ISR 지원
- React 생태계
- Vercel 배포 최적화
- API Routes (풀스택 가능)
- 거대한 커뮤니티

**단점**:
- 복잡한 설정
- 번들 크기가 큼

**추천 시나리오**:
- React 생태계 선호
- 풀스택 개발
- Vercel 배포
- 민간 프로젝트

### React (SPA)

**장점**:
- 유연성
- 거대한 생태계
- 빠른 개발 서버 (Vite)
- 컴포넌트 재사용성

**단점**:
- SEO 약함
- 초기 로딩 느림

**추천 시나리오**:
- 대시보드, 관리자 페이지
- SEO가 중요하지 않은 서비스
- 단순한 SPA
- 민간 프로젝트

자세한 내용은 `references/frontend-options.md` 참조

## 백엔드 기술 스택

### Spring Boot (Java/Kotlin)

**장점**:
- 엔터프라이즈급 안정성
- JPA/Hibernate ORM
- 풍부한 생태계
- 강력한 타입 시스템
- 전자정부프레임워크 호환

**단점**:
- 상대적으로 무거움
- 개발 속도가 느림

**추천 시나리오**:
- 대규모 엔터프라이즈 애플리케이션
- 공공 프로젝트
- 안정성이 중요한 서비스
- 복잡한 비즈니스 로직

### Node.js (Express/NestJS)

**장점**:
- 빠른 개발 속도
- TypeScript 지원
- 가벼움
- 프론트엔드와 같은 언어 (JavaScript/TypeScript)

**단점**:
- 멀티스레딩 약함
- 엔터프라이즈 사례 부족

**추천 시나리오**:
- 스타트업, 민간 프로젝트
- 빠른 프로토타이핑
- 실시간 서비스 (WebSocket)
- 마이크로서비스

자세한 내용은 `references/backend-options.md` 참조

## 데이터베이스 선택

### Oracle / Tibero

**특징**: 엔터프라이즈급, 안정성, 상용 라이선스

**추천 시나리오**:
- 공공 프로젝트
- 대규모 트랜잭션
- 기존 시스템과 호환 필요

### PostgreSQL

**특징**: 오픈소스, 풍부한 기능, 표준 SQL

**추천 시나리오**:
- 민간 프로젝트
- 복잡한 쿼리
- JSON 데이터 처리

### MySQL / MariaDB

**특징**: 오픈소스, 빠름, 간단함

**추천 시나리오**:
- 웹 애플리케이션
- 중소규모 프로젝트
- 읽기 중심 서비스

### MongoDB

**특징**: NoSQL, 유연한 스키마, 수평 확장

**추천 시나리오**:
- 스키마가 자주 변경되는 서비스
- 대량의 비정형 데이터
- 실시간 분석

자세한 내용은 `references/database-options.md` 참조

## ORM/데이터 액세스 계층

### 공공 프로젝트

**MyBatis**
- 전자정부프레임워크 표준
- XML 기반 SQL 매핑
- 복잡한 쿼리 제어 가능

### 민간 프로젝트

**JPA/Hibernate**
- 객체 중심 개발
- 생산성 높음
- 표준 스펙

**Prisma (Node.js)**
- 타입 안전성
- 자동 마이그레이션
- 직관적인 API

## 상태 관리

### Nuxt 4

**Pinia** (권장)
- Vue 3 공식 상태 관리
- TypeScript 지원
- 간단한 API

### React

**Zustand** (권장)
- 간단하고 가벼움
- TypeScript 지원

**Redux Toolkit**
- 복잡한 상태 관리
- 미들웨어 지원

## 인프라 및 배포

### 공공 프로젝트

- **WAS**: JEUS, WebLogic, Tomcat
- **배포**: WAR 파일
- **서버**: 온프레미스

### 민간 프로젝트

- **컨테이너**: Docker
- **오케스트레이션**: Kubernetes
- **클라우드**: AWS, GCP, Azure
- **배포**: CI/CD 파이프라인

## 의사결정 플로우차트

```
프로젝트 시작
    │
    ├─ 공공 프로젝트?
    │   └─ Yes → Nuxt 4 + Spring Boot + MyBatis + Oracle
    │
    └─ 민간 프로젝트?
        └─ Yes → 백엔드/프론트엔드 분리
            │
            ├─ SEO 중요?
            │   ├─ Yes → Nuxt 4 or Next.js
            │   └─ No → React (SPA)
            │
            ├─ 백엔드 언어?
            │   ├─ Java 선호 → Spring Boot + JPA
            │   └─ 빠른 개발 → Node.js + Prisma
            │
            └─ 데이터베이스?
                ├─ 관계형 → PostgreSQL / MySQL
                └─ 비정형 → MongoDB
```

## 기술 스택 조합 예시

### 예시 1: 공공 기관 포털

```
프론트엔드: Nuxt 4 + TypeScript + Nuxt UI
백엔드: Spring Boot + MyBatis + 전자정부프레임워크
데이터베이스: Oracle 19c
배포: JEUS WAS, WAR 패키징
```

### 예시 2: 민간 SaaS 서비스

```
프론트엔드: Nuxt 4 + TypeScript + Pinia + Nuxt UI
백엔드: Spring Boot + JPA + Redis
데이터베이스: PostgreSQL
인프라: Docker + Kubernetes + AWS EKS
```

### 예시 3: 스타트업 MVP

```
프론트엔드: Next.js + TypeScript + Zustand
백엔드: Node.js + NestJS + Prisma
데이터베이스: PostgreSQL
배포: Vercel (프론트) + AWS ECS (백엔드)
```

### 예시 4: 관리자 대시보드

```
프론트엔드: React + Vite + TypeScript + Zustand
백엔드: Spring Boot + JPA
데이터베이스: MySQL
배포: Docker + AWS EC2
```

## 참고 자료

- `references/frontend-options.md`: 프론트엔드 기술 스택 비교
- `references/backend-options.md`: 백엔드 기술 스택 비교
- `references/database-options.md`: 데이터베이스 선택 가이드
- `references/public-tech-stack.md`: 공공 서비스 추천 스택
- `references/private-tech-stack.md`: 민간 서비스 추천 스택

## 관련 스킬

- `project-init` (sef-2026-public 플러그인): 공공 프로젝트 초기화
- `project-init` (sef-2026-private 플러그인): 민간 프로젝트 초기화
- `frontend` (이 플러그인): 공통 프론트엔드 개발
