---
name: backend
description: Government project backend. Spring Boot 2.7 + MyBatis + eGovFrame. Module-based architecture with controller/service/mapper pattern. Frontend (Nuxt 4) built separately and packaged into single WAR. Use for backend development or WAR deployment in sqisoft-sef-2026.
---

# Backend Skill

## Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | Spring Boot | 2.7.18 |
| Java | OpenJDK | 8 |
| Build | Gradle (Kotlin DSL) | - |
| Packaging | WAR | JEUS/WebLogic |
| Data Access | MyBatis | 2.3.1 |
| Security | Spring Security + JWT | jjwt 0.11.5 |
| Gov Framework | eGovFrame | 4.1.0 |
| API Docs | Swagger (springdoc) | OpenAPI 3 |
| DB | PostgreSQL / Oracle | - |
| Frontend | Nuxt 4, shadcn-nuxt, TailwindCSS | pnpm |

## Top-Level 3-Tier Structure

```
com.sqisoft.sef/
  core/        # Shared: ApiResponse, ErrorCode, BusinessException, audit, utils (excel, mail, file, password, time)
  infra/       # Config, security, persistence, egovframe, otp, scheduler
  modules/     # Business modules (auth, user, board, code, role, menu, menurole, terms, auditlog,
               #                   noticepopup, system/{visitlog,apilog,errorlog,loginhistory})
```

- `core` has no dependency on `infra` or `modules`.
- `infra` provides cross-cutting config consumed by `modules`.
- `modules` contains all business logic, organized by domain.

## Module Internal Structure

Every module follows this exact layout:

```
modules/{name}/
  controller/                  # @RestController, HTTP handling only
  domain/                      # Entity classes with factory/update methods
  dto/
    request/                   # @Valid request DTOs
    response/                  # Response DTOs with static from(domain) or of(params) method
  mapper/                      # @Mapper("nameMapper") interface (MyBatis)
  service/
    {Name}Service.java         # Interface (required)
    impl/
      {Name}ServiceImpl.java   # extends EgovAbstractServiceImpl
```

## HTTP Method Constraints

Government network policy: **only GET and POST allowed**.

| Operation | Standard REST | This Project |
|-----------|--------------|--------------|
| List/Read | `GET /resources` | `GET /resources` |
| Create | `POST /resources` | `POST /resources` |
| Update | `PUT /resources/{id}` | `POST /resources/{id}/update` |
| Delete | `DELETE /resources/{id}` | `POST /resources/{id}/delete` |
| Action | - | `POST /resources/{id}/{action}` |
| Batch | - | `POST /resources/batch-{action}` |

## Data Access Pattern

Service injects Mapper directly. No Repository, no Vo, no RepositoryImpl.

```
Controller -> Service (interface) -> ServiceImpl -> Mapper (MyBatis interface) -> XML -> DB
```

- Domain objects are passed directly to Mapper methods (`boardMapper.save(board)`).
- Mapper returns domain objects (`Optional<Board>`, `List<Board>`).
- MyBatis XML handles column-to-field mapping (`mapUnderscoreToCamelCase=true`).

## eGovFrame Rules

1. **@Mapper**: Use `org.egovframe.rte.psl.dataaccess.mapper.Mapper` with bean name (e.g., `@Mapper("boardMapper")`). No `@MapperScan` needed -- `SefEgovConfigAppCommon` handles component scanning.
2. **Swagger**: `@Tag(name, description)` on controller class, `@Operation(summary, description)` on each method. Import from `io.swagger.v3.oas.annotations`.
3. **Service**: Always split into interface + impl. Impl class extends `EgovAbstractServiceImpl` from `org.egovframe.rte.fdl.cmmn`.

## ApiResponse Quick Reference

Fields: `timestamp`, `code`, `message`, `status`, `data` (null fields excluded via `@JsonInclude(NON_NULL)`).

| Method | Usage |
|--------|-------|
| `ApiResponse.success()` | No data, 200 OK |
| `ApiResponse.success(data)` | With data, 200 OK |
| `ApiResponse.success(HttpStatus)` | No data, custom status |
| `ApiResponse.success(HttpStatus, data)` | With data, custom status |
| `ApiResponse.error(ErrorCode)` | Error with default message |
| `ApiResponse.error(ErrorCode, msg)` | Error with custom message |

ErrorCode values: `INTERNAL_ERROR`, `BAD_REQUEST`, `NOT_FOUND`, `CONFLICT`, `UNAUTHORIZED`, `FORBIDDEN`.

Pagination: `PageResponse<T>` with fields `totalCnt`, `pageSize`, `currentPage`, `resultList`.

## Modules

| Module | Path | Description |
|--------|------|-------------|
| auth | `modules/auth/` | Authentication (login, logout, token refresh) |
| user | `modules/user/` | User management, registration, OTP, statistics |
| board | `modules/board/` | Post/board CRUD, file attachments, statistics |
| code | `modules/code/` | Code group/detail management |
| role | `modules/role/` | Role management |
| menu | `modules/menu/` | Hierarchical menu management |
| menurole | `modules/menurole/` | Menu-role authorization mapping (CRUD permissions) |
| terms | `modules/terms/` | Terms & conditions management, user consent tracking |
| auditlog | `modules/auditlog/` | Audit log recording (no controller, used via @AuditLog annotation) |
| noticepopup | `modules/noticepopup/` | Notice popup management and scheduling |
| system/apilog | `modules/system/apilog/` | API request/response log tracking |
| system/errorlog | `modules/system/errorlog/` | Application error log tracking |
| system/loginhistory | `modules/system/loginhistory/` | Login history tracking |
| system/visitlog | `modules/system/visitlog/` | Visit tracking, analytics (IP, browser, device, heatmap) |

**Note**: `auditlog` has no controller -- it is invoked via `@AuditLog` aspect annotation on other module methods.

## References

- `references/api-conventions.md` -- HTTP method rules, URL patterns, controller example
- `references/architecture.md` -- 3-tier structure, module internals, object conversion flow
- `references/mybatis-config.md` -- MyBatis XML config and mapper setup
- `references/security-setup.md` -- JWT auth, Spring Security, WebSecurityConfig
- `references/egovframework.md` -- eGovFrame integration details
- `references/folder-structure.md` -- Full directory tree
- `references/spring-boot-setup.md` -- Boot config, JEUS compatibility
- `references/frontend-integration.md` -- Nuxt build + WAR packaging
- `references/audit-system.md` -- @AuditLog annotation, AuditLevel, AuditAction usage
- `references/excel-export.md` -- @ExcelHeader, ExcelUtilsV1, multi-sheet export
- `references/otp-system.md` -- OTP generation, verification, rate limiting, VerifyToken flow
- `references/scheduler-setup.md` -- Token cleanup, dormancy, password change schedulers
- `references/statistics-pattern.md` -- Statistics module pattern (KPI, trend, distribution)
