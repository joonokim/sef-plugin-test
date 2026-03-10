# SQisoft SEF 2026 Plugin

## 개요

SQisoft SEF(Software Engineering Framework) 2026 Plugin은 공공 및 민간 프로젝트의 효율적인 개발을 지원하는 Claude Code 스킬 모음입니다.

## 프로젝트 목표

- 프로젝트 유형별 최적 기술 스택 가이드 제공
- 공공/민간 프로젝트의 특성에 맞는 개발 프레임워크 제공
- 일관된 코드 품질과 아키텍처 표준 유지
- 개발 생산성 향상

## 주요 기능

### 1. 기술 스택 가이드 (tech-stack)
- Nuxt 4, Next.js, React 등 프론트엔드 기술 비교
- Spring Boot, Node.js 백엔드 옵션
- 데이터베이스 선택 가이드
- 공공/민간 서비스 스택 추천

### 2. 공공 부문 (sef-2026-public 플러그인)
- 전자정부프레임워크 기반 프로젝트 초기화
- Nuxt 4 + Spring Boot + MyBatis 스택
- WAR 배포 및 WAS 설정
- Oracle/Tibero 데이터베이스 연동

### 3. 민간 부문 (sef-2026-private 플러그인)
- 마이크로서비스 아키텍처 프로젝트 초기화
- 프론트엔드/백엔드 분리 구조
- Docker 및 Kubernetes 배포
- PostgreSQL/MongoDB 연동

### 4. 공통 기능 (common)
- 인증 시스템 (JWT, OAuth2, Session)
- 게시판 시스템
- CRUD 기본 기능

## 플러그인 구조

이 프로젝트는 3개의 플러그인으로 구성됩니다:

- **sef-2026** (이 플러그인): 공통 프론트엔드, 기술 스택 가이드, 에이전트, 참조 문서
- **sef-2026-private**: 민간 서비스 스킬 (backend, deployment, project-init)
- **sef-2026-public**: 공공 서비스 스킬 (backend, deployment, project-init)

### sef-2026 (공통) 디렉토리 구조

```
plugins/sef-2026/
├── assets/                  # 공통 에셋 및 템플릿
├── reference/              # 공통 참고 문서
├── agents/                 # 에이전트
└── skills/                 # 공통 스킬 모음
    ├── tech-stack/         # 기술 스택 가이드
    └── frontend/           # 공통 프론트엔드 (Nuxt 4)
```

## 사용 방법

### 프로젝트 시작하기

1. **기술 스택 결정**
   ```
   /tech-stack을 사용하여 프로젝트에 적합한 기술 스택 선택
   ```

2. **공공 프로젝트 초기화**
   ```
   sef-2026-public 플러그인의 project-init 스킬 사용
   - Nuxt 4 + Spring Boot + MyBatis
   - WAR 패키징 및 WAS 배포
   ```

3. **민간 프로젝트 초기화**
   ```
   sef-2026-private 플러그인의 project-init 스킬 사용
   - 프론트엔드/백엔드 분리
   - Docker 기반 배포
   ```

### 기능 추가하기

- **인증 시스템**: `auth-system` 스킬 사용
- **게시판 기능**: `board-system` 스킬 사용
- **공통 기능**: `common-features` 스킬 사용

## 기술 스택

### 공공 프로젝트 기본 스택

```yaml
프론트엔드:
  - Nuxt 4
  - TypeScript
  - Nuxt UI
  - Pinia

백엔드:
  - Spring Boot 3.x
  - MyBatis
  - 전자정부프레임워크

데이터베이스:
  - Oracle 19c
  - Tibero

배포:
  - JEUS / WebLogic / Tomcat
  - WAR 패키징
```

### 민간 프로젝트 기본 스택

```yaml
프론트엔드:
  - Nuxt 4 / Next.js
  - TypeScript
  - Pinia / Zustand

백엔드:
  - Spring Boot + JPA
  - Node.js + NestJS + Prisma

데이터베이스:
  - PostgreSQL
  - MySQL
  - MongoDB

배포:
  - Docker
  - Kubernetes
  - AWS / GCP / Azure
```

## 코딩 컨벤션

자세한 코딩 컨벤션은 `reference/conventions/` 디렉토리를 참고하세요.

- TypeScript 코딩 스타일
- Java 코딩 스타일
- Git 커밋 메시지 규칙
- API 설계 원칙

## 보안 가이드라인

보안 관련 가이드는 `reference/security/` 디렉토리를 참고하세요.

- 인증/인가 모범 사례
- 데이터 암호화
- SQL 인젝션 방지
- XSS 방지

## 기여 방법

1. 새로운 스킬 추가 시 `skills/` 디렉토리 아래에 추가
2. 공통 참고 자료는 `reference/` 디렉토리에 추가
3. 템플릿 및 에셋은 `assets/` 디렉토리에 추가

## 라이선스

Copyright (c) 2026 SQisoft

## 문의

프로젝트 관련 문의사항은 이슈를 등록해주세요.
