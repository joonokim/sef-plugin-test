# 공공 프로젝트 프론트엔드 배포 (WAR 포함)

## 개요

공공 프로젝트의 프론트엔드는 **Spring Boot WAR 파일에 포함**되어 배포됩니다. Nuxt는 `preset: 'static'` 모드로 빌드되어 Spring Boot의 `src/main/resources/static/` 폴더에 직접 출력됩니다.

## 프로젝트 위치

```
sqisoft-sef-2026/                      # 프로젝트 루트
├── src/main/resources/static/         # Nuxt 빌드 결과 출력 위치 (자동)
├── frontend/                          # Nuxt 4 프로젝트
│   ├── components/
│   ├── pages/
│   ├── nuxt.config.ts                 # nitro.output 설정으로 자동 복사
│   └── package.json
└── build.gradle.kts                   # Kotlin DSL, Spring Boot 2.7.18
```

## 빌드 프로세스

### 1. Nuxt 빌드 (자동 출력 경로 설정)

`nuxt.config.ts`의 `nitro` 설정으로 빌드 결과가 Spring Boot static 폴더에 직접 출력됩니다:

```typescript
// nuxt.config.ts
nitro: {
  preset: 'static',
  output: {
    dir: '../src/main/resources/static',
    publicDir: '../src/main/resources/static',
  },
},
```

### 2. 빌드 스크립트 (build-frontend.sh)

```bash
#!/bin/bash
set -e

echo "=== Nuxt 프론트엔드 빌드 시작 ==="

cd frontend

# 의존성 설치
echo "의존성 설치 중..."
pnpm install --frozen-lockfile

# 프로덕션 빌드 (nitro output 설정으로 자동 복사)
echo "프론트엔드 빌드 중..."
pnpm build

echo "=== 프론트엔드 빌드 완료 ==="
ls -lah ../src/main/resources/static/
```

### 3. 전체 빌드

```bash
# 1. 프론트엔드 빌드 및 출력
cd frontend
pnpm build

# 2. Spring Boot WAR 패키징 (프로젝트 루트에서)
cd ..
./gradlew build

# 결과: build/libs/*.war (프론트엔드 포함)
```

## build.gradle.kts (현재 설정)

현재 프로젝트는 **Kotlin DSL** (`build.gradle.kts`)을 사용하며, Spring Boot **2.7.18** + **Java 8** 기준입니다:

```kotlin
plugins {
    java
    war
    id("org.springframework.boot") version "2.7.18"
    id("io.spring.dependency-management") version "1.1.4"
}

group = "com.sqisoft"

java {
    sourceCompatibility = JavaVersion.VERSION_1_8
    targetCompatibility = JavaVersion.VERSION_1_8
}

tasks.war {
    enabled = true
    archiveClassifier.set("")
}

// WAR 빌드 시 frontend 빌드 먼저 실행
// pnpm build는 nuxt.config.ts의 nitro.output 설정으로 static 폴더에 자동 출력
```

> **참고**: Node Gradle Plugin을 사용하지 않고 프론트엔드 빌드를 별도로 실행합니다. `pnpm build` 명령이 `nitro.output` 설정에 의해 자동으로 `src/main/resources/static/`에 결과를 출력합니다.

## Spring Boot 설정

### application.yml

```yaml
spring:
  web:
    resources:
      static-locations: classpath:/static/

server:
  port: 7171
```

### SPA 라우팅 지원 (Controller)

SPA 모드로 빌드된 Nuxt의 Vue Router 경로를 지원하기 위해 SPA 컨트롤러가 필요합니다:

```java
@Controller
public class SpaController {

    @RequestMapping(value = "/{path:[^\\.]*}")
    public String redirect() {
        // Vue Router의 모든 경로를 index.html로 리다이렉트
        return "forward:/index.html";
    }
}
```

## WAS 배포

### JEUS 배포

```bash
# WAR 파일 복사
cp build/libs/*.war $JEUS_HOME/domains/domain1/applications/

# JEUS 재시작
jeus-admin deploy app.war
```

### WebLogic 배포

1. WebLogic Console 접속
2. Deployments → Install
3. WAR 파일 선택
4. 대상 서버 선택
5. Deploy

## CI/CD 파이프라인 (.gitlab-ci.yml)

```yaml
stages:
  - build
  - deploy

build:
  stage: build
  image: gradle:8.5-jdk8
  script:
    # Node.js / pnpm 설치
    - curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    - apt-get install -y nodejs
    - npm install -g pnpm

    # 프론트엔드 빌드 (nitro output으로 static 폴더에 자동 복사)
    - cd frontend
    - pnpm install --frozen-lockfile
    - pnpm build
    - cd ..

    # 백엔드 빌드
    - ./gradlew build -x test
  artifacts:
    paths:
      - build/libs/*.war
    expire_in: 1 week

deploy:
  stage: deploy
  script:
    - scp build/libs/*.war user@server:/path/to/deploy/
    - ssh user@server 'jeus-admin deploy app.war'
  only:
    - main
```

## 개발 워크플로우

### 로컬 개발

```bash
# Terminal 1: Spring Boot 백엔드 (프로젝트 루트에서)
./gradlew bootRun  # http://localhost:7171

# Terminal 2: Nuxt 프론트엔드 (frontend/ 디렉토리에서)
pnpm dev  # http://localhost:3000
```

개발 중에는 프론트엔드와 백엔드를 분리 실행하여 HMR(Hot Module Replacement)을 활용합니다. 프론트엔드의 `/api`, `/adm/` 요청은 `nuxt.config.ts`의 `vite.server.proxy`를 통해 `http://localhost:7171`로 프록시됩니다.

### 통합 테스트

```bash
# 프론트엔드 빌드 (frontend/ 디렉토리에서)
cd frontend
pnpm build

# 백엔드 실행 (프로젝트 루트에서)
cd ..
./gradlew bootRun

# 브라우저에서 확인
# http://localhost:7171/gbadm/
```

## 정적 리소스 캐싱

### application.yml

```yaml
spring:
  web:
    resources:
      chain:
        strategy:
          content:
            enabled: true
        cache: true
      cache:
        cachecontrol:
          max-age: 31536000  # 1년
          cache-public: true
```

## 트러블슈팅

### 1. 빌드 파일이 static 폴더에 없는 경우

```bash
# 빌드 결과 확인
ls -la frontend/.output/

# static 폴더 확인
ls -la src/main/resources/static/

# nuxt.config.ts의 nitro.output 설정 확인
# dir, publicDir이 '../src/main/resources/static'인지 확인
```

### 2. SPA 라우팅이 작동하지 않는 경우

Spring Boot에 SPA 컨트롤러가 필요합니다:

```java
@Controller
public class SpaController {
    @RequestMapping(value = "/{path:[^\\.]*}")
    public String redirect() {
        return "forward:/index.html";
    }
}
```

### 3. 기본 경로(baseURL) 관련 문제

`nuxt.config.ts`의 `app.baseURL`이 `/gbadm/`로 설정되어 있습니다. WAR 배포 시 컨텍스트 경로와 일치해야 합니다:

```typescript
app: {
  baseURL: '/gbadm/',
},
```

### 4. Gradle 빌드 캐시 문제

```bash
# Gradle 캐시 클리어
./gradlew clean

# 전체 재빌드
cd frontend && pnpm build && cd ..
./gradlew build
```

## 베스트 프랙티스

1. **Nitro 직접 출력**: `nitro.output` 설정으로 수동 복사 없이 자동 출력
2. **환경 분리**: 개발 시 프론트엔드와 백엔드 분리 실행 (HMR 활용)
3. **SPA 모드**: `ssr: false` 설정으로 완전한 정적 파일 생성
4. **SPA 라우팅**: Vue Router 경로를 지원하는 SpaController 필수
5. **버전 관리**: 빌드 파일을 Git에 포함하지 않음 (.gitignore)

## .gitignore 설정

```gitignore
# Gradle
.gradle/
build/

# Node.js (frontend)
frontend/node_modules/
frontend/.nuxt/
frontend/.output/

# Spring Boot static (빌드 결과물)
src/main/resources/static/
```

## 참고 자료

- `deployment-private.md`: 민간 프로젝트 배포 (Docker)
- Spring Boot 2.7.x 정적 리소스 가이드
- Nuxt Nitro 정적 배포 문서
