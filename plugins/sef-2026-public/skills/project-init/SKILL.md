---
name: project-init
description: Government project initial structure. Single WAS architecture, module-based structure with controller/service/mapper pattern, Gradle Kotlin DSL, frontend at project root level. Use when starting or initializing a government project.
---

# Government Project Initialization

## Overview

Generates the initial structure for government/public-sector projects based on SEF 2026.
Single WAR deployment with Nuxt 4 frontend and Spring Boot 2.7 backend in one package.

## Key Characteristics

- **Single WAS server** -- one WAR file containing frontend + backend
- **Module-based architecture** with controller/service/mapper layering (NOT DDD/Hexagonal)
- **Frontend at project root** (`frontend/`, NOT `backend/frontend/`)
- **Nuxt 4 build output** copied into `src/main/resources/static/` and packaged into WAR
- **MyBatis** with eGovFrame 4.1 `@Mapper` annotation
- **Gradle Kotlin DSL** (`build.gradle.kts`, NOT Maven)
- **Java 8** (OpenJDK 1.8, required for JEUS 8 compatibility)
- **Package manager**: pnpm (NOT npm)

## Tech Stack

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

## Project Structure

```
sqisoft-sef-2026/
├── frontend/                          # Nuxt 4 (project root level)
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
│   ├── core/                          # Shared utilities
│   │   ├── audit/                     # @AuditLog annotation, AuditLogAspect
│   │   │   ├── annotation/            # AuditAction, AuditLevel, AuditLog
│   │   │   ├── aspect/                # AuditLogAspect
│   │   │   └── dto/                   # AuditReasonRequest
│   │   ├── dto/                       # ApiResponse, PageRequest
│   │   ├── enums/                     # ErrorCode
│   │   ├── exception/                 # GlobalExceptionHandler
│   │   └── utils/                     # Excel, Mail, File, Password, Time utils
│   ├── infra/                         # Infrastructure config
│   │   ├── config/                    # Jackson, Async, Scheduling, Swagger
│   │   ├── persistence/              # Database config
│   │   ├── security/                 # WebSecurity, JWT
│   │   ├── egovframe/               # eGovFrame integration
│   │   ├── otp/                     # OTP support, VerifyToken
│   │   └── scheduler/               # Token cleanup, Dormancy, Password change
│   └── modules/                      # Business modules
│       ├── {module}/                 # auth, user, board, code, menu, role, menurole, terms
│       │   ├── controller/           # REST controllers
│       │   ├── domain/               # Entity classes
│       │   ├── dto/                  # request/ and response/ DTOs
│       │   ├── mapper/               # MyBatis mapper interfaces
│       │   └── service/              # Service interface + impl/
│       ├── auditlog/                 # Audit log (no controller, @AuditLog aspect)
│       ├── noticepopup/              # Notice popup management
│       └── system/
│           ├── apilog/               # API request/response log tracking
│           ├── errorlog/             # Application error log tracking
│           ├── loginhistory/         # Login history tracking
│           └── visitlog/             # Visit tracking & analytics
│
├── src/main/resources/
│   ├── mybatis/config/ + mapper/
│   ├── properties/{local,dev,prod}/env.properties
│   ├── application.yml
│   └── static/                       # Nuxt build output target
│
├── build.gradle.kts                  # Gradle Kotlin DSL
└── gradlew.bat / gradlew
```

## References

- `references/monolithic-structure.md` -- Single WAR architecture and module layout
- `references/war-deployment.md` -- WAR build and WAS deployment guide

## Related Skills

- `workflow-guide` -- Full project creation workflow (Phase 1~6 checklist)
- `backend` -- Backend development patterns and conventions
- `deployment` -- Production deployment procedures
