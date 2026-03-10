# Monolithic WAR Structure

## Overview

SEF 2026 is a single WAR deployment: the Nuxt 4 frontend is built to static files, copied into `src/main/resources/static/`, and packaged alongside the Spring Boot 2.7 backend into one WAR file deployed to a single WAS instance.

## Architecture Diagram

```
Client (Browser)
    |
    | HTTP/HTTPS
    v
WAS (JEUS 8 / WebLogic / Tomcat)
    |
    +-- sef.war
        |
        +-- Static files (Nuxt build)    --> HTML/CSS/JS served directly
        |       /_nuxt/*, index.html
        |
        +-- Spring Boot 2.7.18 Backend
                |
                Controller  (/api/**)
                    |
                Service (interface + impl)
                    |
                Mapper (@Mapper, MyBatis)
                    |
                Database (PostgreSQL / Oracle)
```

Backend layers are simple controller/service/mapper -- NOT DDD 4-layer (presentation/application/domain/infrastructure).

## Project Directory Structure

```
sqisoft-sef-2026/
├── frontend/                              # Nuxt 4 at project root
│   ├── app.vue
│   ├── pages/
│   ├── components/
│   ├── composables/
│   ├── stores/
│   ├── layouts/
│   ├── types/
│   ├── utils/
│   ├── nuxt.config.ts
│   └── package.json
│
├── src/main/java/com/sqisoft/sef/
│   ├── SefApplication.java
│   ├── ServletInitializer.java
│   ├── core/
│   │   ├── dto/                           # ApiResponse, PageRequest, etc.
│   │   ├── enums/                         # ErrorCode, etc.
│   │   ├── exception/                     # BusinessException, GlobalExceptionHandler
│   │   └── utils/                         # ExcelUtil, MailUtil, FileUtil
│   ├── infra/
│   │   ├── config/                        # JacksonConfig, SchedulingConfig
│   │   ├── persistence/                   # DatabaseConfig
│   │   ├── security/                      # WebSecurityConfig, JWT filters
│   │   │   ├── common/
│   │   │   ├── config/
│   │   │   ├── expression/
│   │   │   ├── jwt/
│   │   │   ├── service/
│   │   │   └── token/
│   │   ├── egovframe/                     # eGovFrame integration
│   │   ├── otp/
│   │   └── scheduler/                     # TokenCleanupScheduler
│   └── modules/
│       ├── auth/                          # Authentication module
│       │   ├── controller/                # AuthController.java
│       │   ├── domain/                    # RefreshToken.java (entity)
│       │   ├── dto/
│       │   │   ├── request/               # AuthRequest, JwtRequest, RefreshTokenRequest
│       │   │   └── response/              # AuthResponse, JwtResponse, TokenResponse
│       │   ├── mapper/                    # RefreshTokenMapper.java
│       │   └── service/
│       │       ├── AuthService.java       # Interface
│       │       └── impl/
│       │           └── AuthServiceImpl.java
│       ├── user/                          # Same pattern as auth
│       ├── board/
│       ├── code/
│       ├── menu/
│       ├── menurole/
│       └── role/
│
├── src/main/resources/
│   ├── mybatis/
│   │   ├── config/mybatis-config.xml
│   │   └── mapper/**/*.xml
│   ├── properties/
│   │   ├── local/env.properties
│   │   ├── dev/env.properties
│   │   └── prod/env.properties
│   ├── application.yml
│   ├── application-dev.yml
│   ├── application-prod.yml
│   ├── static/                            # Nuxt build output copied here
│   └── log4j2.xml
│
├── build.gradle.kts
├── settings.gradle.kts
└── gradlew.bat / gradlew
```

### Module Internal Pattern (every module follows this)

```
modules/{module}/
├── controller/         # @RestController, HTTP handling only
├── domain/             # Entity/model classes (plain Java, Lombok)
├── dto/
│   ├── request/        # Inbound DTOs (@Valid)
│   └── response/       # Outbound DTOs
├── mapper/             # @Mapper interface (MyBatis, eGovFrame)
└── service/
    ├── SomeService.java        # Interface
    └── impl/
        └── SomeServiceImpl.java  # @Service implementation
```

No `infrastructure/`, `application/`, `presentation/`, `vo/`, `repository/`, or `usecase/` directories.

## WAR File Structure (built artifact)

```
sef.war
├── WEB-INF/
│   ├── classes/
│   │   ├── com/sqisoft/sef/           # Compiled Java classes
│   │   │   ├── core/
│   │   │   ├── infra/
│   │   │   └── modules/
│   │   ├── static/                    # Nuxt build (index.html, _nuxt/*)
│   │   ├── mybatis/
│   │   │   ├── config/mybatis-config.xml
│   │   │   └── mapper/
│   │   ├── properties/
│   │   ├── application.yml
│   │   └── log4j2.xml
│   └── lib/                           # Dependency JARs
└── META-INF/
```

## Development Environment

Run frontend and backend separately during development:

```
Terminal 1:  gradlew.bat bootRun          --> http://localhost:7171
Terminal 2:  cd frontend && pnpm dev      --> http://localhost:3000
```

Frontend proxies API calls to `:7171` via Nuxt dev server config.

## Production Build

```bash
cd frontend && pnpm build                           # 1. Build Nuxt
cp -r .output/public/* ../src/main/resources/static/ # 2. Copy static output
cd .. && gradlew.bat clean build -x test             # 3. Build WAR
# Result: build/libs/sef.war
```
