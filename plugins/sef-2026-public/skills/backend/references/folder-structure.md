# Project Folder Structure Reference

## Full Directory Tree

```
sqisoft-sef-2026/
├── frontend/                          # Nuxt 4 SPA (at project root, NOT nested)
│   ├── pages/                         # File-based routing
│   ├── components/                    # Vue components
│   │   └── ui/                        # shadcn-vue components
│   ├── composables/                   # Composables (useAuth, etc.)
│   ├── stores/                        # Pinia stores
│   ├── middleware/                    # Route middleware
│   ├── plugins/                       # Nuxt plugins
│   ├── layouts/                       # Layout components
│   ├── types/                         # TypeScript types
│   ├── assets/                        # CSS, images
│   ├── lib/                           # Shared utilities (api client, etc.)
│   ├── utils/                         # Utility functions
│   ├── server/                        # Nuxt server routes (if needed)
│   ├── scripts/                       # Build/helper scripts
│   ├── app.vue
│   ├── nuxt.config.ts
│   ├── tailwind.config.ts
│   └── package.json                   # uses pnpm
│
├── src/main/
│   ├── java/com/sqisoft/sef/
│   │   ├── SefApplication.java        # Spring Boot entry point
│   │   ├── ServletInitializer.java    # WAR deployment support
│   │   │
│   │   ├── core/                      # Cross-cutting concerns
│   │   │   ├── dto/
│   │   │   │   ├── ApiResponse.java   # Unified API response wrapper
│   │   │   │   └── page/
│   │   │   │       ├── PageRequest.java
│   │   │   │       └── PageResponse.java
│   │   │   ├── enums/
│   │   │   │   └── ErrorCode.java     # Standard error codes
│   │   │   ├── exception/
│   │   │   │   ├── BusinessException.java
│   │   │   │   └── handler/
│   │   │   │       └── GlobalExceptionHandler.java
│   │   │   └── utils/
│   │   │       ├── excel/             # Excel export (POI)
│   │   │       ├── files/             # FileUtil
│   │   │       ├── mail/              # Mail sending (adapter, sender, dto, enums)
│   │   │       └── time/              # TimeUtils
│   │   │
│   │   ├── infra/                     # Infrastructure / config
│   │   │   ├── config/
│   │   │   │   ├── JacksonConfig.java
│   │   │   │   ├── SchedulingConfig.java
│   │   │   │   └── SwaggerConfig.java
│   │   │   ├── egovframe/
│   │   │   │   ├── cmm/
│   │   │   │   │   └── SefEgovComTraceHandler.java
│   │   │   │   └── config/
│   │   │   │       └── SefEgovConfigAppCommon.java  # ComponentScan base
│   │   │   ├── init/                  # DB initialization / data seeding
│   │   │   ├── logging/               # Log configuration, log-related beans
│   │   │   ├── otp/
│   │   │   │   └── OtpProvider.java
│   │   │   ├── persistence/
│   │   │   │   └── config/
│   │   │   │       ├── DatabaseConfig.java   # DataSource, SqlSessionFactory
│   │   │   │       ├── MapperConfig.java     # MapperConfigurer (scans modules)
│   │   │   │       └── MyBatisConfig.java
│   │   │   ├── scheduler/
│   │   │   │   └── TokenCleanupScheduler.java
│   │   │   └── security/
│   │   │       ├── common/            # SecurityUser, AuthenticationResult
│   │   │       ├── config/
│   │   │       │   ├── BCryptConfig.java
│   │   │       │   ├── MethodSecurityConfig.java
│   │   │       │   ├── WebConfig.java           # CORS + SPA fallback routing
│   │   │       │   └── WebSecurityConfig.java   # JWT filter chain (antMatchers)
│   │   │       ├── expression/        # Custom @PreAuthorize expressions
│   │   │       ├── jwt/               # JwtTokenProvider, JwtAuthenticationFilter, etc.
│   │   │       ├── service/           # CustomUserDetailsService, CustomUserDetails
│   │   │       └── token/             # TokenStore interface
│   │   │
│   │   └── modules/                   # Business modules
│   │       ├── auth/
│   │       ├── auditlog/            # Audit log (no controller, @AuditLog aspect)
│   │       ├── board/
│   │       ├── code/
│   │       ├── menu/
│   │       ├── menurole/
│   │       ├── noticepopup/         # Notice popup management
│   │       ├── role/
│   │       ├── system/
│   │       │   ├── apilog/          # API request/response log tracking
│   │       │   ├── errorlog/        # Application error log tracking
│   │       │   ├── loginhistory/    # Login history tracking
│   │       │   └── visitlog/        # Visit tracking, analytics
│   │       ├── terms/               # Terms & conditions, user consent
│   │       └── user/
│   │
│   └── resources/
│       ├── application.yml            # Main config (port 7171)
│       ├── application-dev.yml
│       ├── application-prod.yml
│       ├── log4j2.xml
│       ├── log4jdbc.log4j2.properties
│       ├── mybatis/
│       │   ├── config/
│       │   │   └── mybatis-config.xml # cacheEnabled=false, mapUnderscoreToCamelCase=true
│       │   └── mapper/
│       │       ├── auth/              # RefreshTokenMapper.xml
│       │       ├── auditlog/          # AuditLogMapper.xml
│       │       ├── board/             # BoardMapper.xml, BoardFileMapper.xml
│       │       ├── code/              # CodeMapper.xml
│       │       ├── menu/              # MenuMapper.xml
│       │       ├── menurole/          # MenuRoleMapper.xml
│       │       ├── noticepopup/       # NoticePopupMapper.xml
│       │       ├── role/              # RoleMapper.xml
│       │       ├── system/            # ApiLogMapper.xml, ErrorLogMapper.xml, etc.
│       │       ├── terms/             # TermsMapper.xml, UserTermsMapper.xml
│       │       └── user/              # UserMapper.xml
│       └── properties/
│           ├── local/env.properties
│           ├── dev/env.properties
│           └── prod/env.properties
│
├── build.gradle.kts
└── gradlew.bat
```

## Module Internal Structure

Every module under `modules/` follows this exact layout. This is NOT Hexagonal Architecture.

```
modules/{moduleName}/
├── controller/
│   ├── {Name}Controller.java          # Public API
│   └── {Name}AdminController.java     # Admin API (optional)
├── domain/
│   └── {Name}.java                    # Domain object (plain class, NOT JPA entity)
├── dto/
│   ├── request/
│   │   ├── {Name}RegisterRequest.java
│   │   ├── {Name}UpdateRequest.java
│   │   └── {Name}SearchRequest.java
│   └── response/
│       ├── {Name}ListResponse.java
│       └── {Name}DetailResponse.java
├── mapper/
│   └── {Name}Mapper.java             # @Mapper("nameMapper") interface
└── service/
    ├── {Name}Service.java             # Interface
    └── impl/
        └── {Name}ServiceImpl.java     # extends EgovAbstractServiceImpl
```

There is NO `vo/`, NO `repository/`, NO `infrastructure/`, NO `application/`, NO `presentation/` directory.

## Existing Modules

| Module | Description | Has AdminController |
|--------|-------------|---------------------|
| auth | Login, token refresh, logout | No |
| auditlog | Audit log recording (no controller, @AuditLog aspect) | No |
| board | Posts with file attachments | Yes (BoardAdminController) |
| code | Code groups and code details | Yes (CodeAdminController) |
| menu | Menu tree management | No |
| menurole | Menu-role permission mapping | Yes (MenuRoleAdminController) |
| noticepopup | Notice popup management and scheduling | Yes (NoticePopupAdminController) |
| role | Role management | Yes (RoleAdminController) |
| system/apilog | API request/response log tracking | Yes |
| system/errorlog | Application error log tracking | Yes |
| system/loginhistory | Login history tracking | Yes |
| system/visitlog | Visit tracking, analytics (IP, browser, device) | Yes |
| terms | Terms & conditions, user consent tracking | Yes |
| user | User registration, management | Yes (UserAdminController) |

## core/ Package Overview

| Class | Purpose |
|-------|---------|
| `ApiResponse<T>` | Unified JSON response wrapper |
| `PageRequest` | Pagination input (pageSize default 10, currentPage default 1) |
| `PageResponse<T>` | Pagination output (totalCnt, pageSize, currentPage, resultList) |
| `ErrorCode` | Enum: INTERNAL_ERROR, BAD_REQUEST, NOT_FOUND, CONFLICT, UNAUTHORIZED, FORBIDDEN |
| `BusinessException` | Runtime exception carrying ErrorCode + optional customMessage |
| `GlobalExceptionHandler` | `@RestControllerAdvice` catches exceptions, returns `ApiResponse.error(...)` |

## ApiResponse Reference

Fields: `timestamp` (LocalDateTime formatted as String), `code` (String), `message` (String), `status` (HttpStatus), `data` (T, nullable via `@JsonInclude(NON_NULL)`).

```java
// Static factory methods (actual signatures from source):
ApiResponse.success()                          // 200 OK, no data
ApiResponse.success(HttpStatus status)         // Custom status, no data
ApiResponse.success(T data)                    // 200 OK with data
ApiResponse.success(HttpStatus status, T data) // Custom status with data
ApiResponse.error(ErrorCode errorCode)         // Error with default message
ApiResponse.error(ErrorCode errorCode, String detailMessage) // Error with custom message
```

Controller usage pattern:
```java
return ResponseEntity.ok(ApiResponse.success(data));
return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.success(HttpStatus.CREATED));
```

## infra/ Package Overview

| Sub-package | Purpose |
|-------------|---------|
| `config/` | JacksonConfig, SchedulingConfig, SwaggerConfig (`@Profile({"local","dev"})`) |
| `egovframe/` | SefEgovConfigAppCommon (ComponentScan), SefEgovComTraceHandler |
| `persistence/config/` | DatabaseConfig (DataSource + SqlSessionFactory), MapperConfig (MapperConfigurer), MyBatisConfig |
| `security/config/` | WebSecurityConfig (antMatchers, JWT filter chain), WebConfig (CORS + SPA routing), BCryptConfig, MethodSecurityConfig |
| `security/jwt/` | JwtTokenProvider, JwtAuthenticationFilter, JwtAccessDeniedHandler, JwtAuthenticationEntryPoint, JwtTokenStore, JwtUtils |
| `security/expression/` | Custom SpEL: `hasMenuAuthority(menuId, 'R')` for `@PreAuthorize` |
| `security/common/` | SecurityUser, AuthenticationResult |
| `security/service/` | CustomUserDetailsService, CustomUserDetails |
| `security/token/` | TokenStore interface |
| `scheduler/` | TokenCleanupScheduler |
| `otp/` | OtpProvider |

## Security Notes

- `WebSecurityConfig` uses `antMatchers()` (Spring Security 5.x). Do NOT use `requestMatchers()`.
- Session policy: `STATELESS` (JWT only, no HTTP session).
- Custom `@PreAuthorize` expressions: `hasMenuAuthority(#menuId, 'R'|'C'|'U'|'D')`.
- Admin paths require `USER_ROLE_ADM` authority.
