# Audit System Reference

## Overview

The audit system automatically records who did what and when on sensitive data, using an AOP-based approach. Annotate a service method with `@AuditLog` and the aspect intercepts the call, captures request data, resolves the target record ID, and persists the log asynchronously to `tb_audit_log`.

Key design properties:
- Zero boilerplate in service methods — one annotation is all that is needed
- Async persistence via a dedicated thread pool (`auditLogExecutor`) — does not block the main request
- Two severity levels: `WEAK` (silent logging) and `STRONG` (mandatory change reason)
- SpEL-based target ID resolution for flexible parameter extraction

---

## Components

| Layer | Class | Package |
|---|---|---|
| Annotation | `@AuditLog` | `com.sqisoft.sef.core.audit.annotation` |
| Enum | `AuditAction` | `com.sqisoft.sef.core.audit.annotation` |
| Enum | `AuditLevel` | `com.sqisoft.sef.core.audit.annotation` |
| Aspect | `AuditLogAspect` | `com.sqisoft.sef.core.audit.aspect` |
| DTO | `AuditReasonRequest` | `com.sqisoft.sef.core.audit.dto` |
| Domain | `AuditLog` | `com.sqisoft.sef.modules.auditlog.domain` |
| Mapper | `AuditLogMapper` | `com.sqisoft.sef.modules.auditlog.mapper` |
| Service | `AuditLogService` / `AuditLogServiceImpl` | `com.sqisoft.sef.modules.auditlog.service` |

---

## @AuditLog Annotation

```java
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface AuditLog {
    String targetTb();              // DB table name, e.g. "tb_user"
    AuditAction action();           // CREATE | UPDATE | DELETE | READ
    AuditLevel level() default AuditLevel.WEAK; // STRONG requires changeRsn
    String targetIdParam() default ""; // SpEL expression to extract target PK
}
```

### Attribute details

| Attribute | Type | Required | Description |
|---|---|---|---|
| `targetTb` | `String` | Yes | Target database table name (e.g. `"tb_board"`) |
| `action` | `AuditAction` | Yes | Operation type: `CREATE`, `UPDATE`, `DELETE`, `READ` |
| `level` | `AuditLevel` | No (default `WEAK`) | `STRONG` enforces a non-empty `changeRsn` field |
| `targetIdParam` | `String` | No | SpEL expression referencing a method parameter (e.g. `"#userId"`, `"#cdGrpId"`) |

---

## AuditAction Enum

```java
public enum AuditAction {
    CREATE, UPDATE, DELETE, READ
}
```

| Value | Typical use |
|---|---|
| `CREATE` | Insert new record |
| `UPDATE` | Modify existing record |
| `DELETE` | Remove a record |
| `READ` | Sensitive data access (e.g. PII lookup) |

---

## AuditLevel Enum

```java
public enum AuditLevel {
    STRONG, WEAK
}
```

| Value | Behavior |
|---|---|
| `WEAK` | Log is written silently; `changeRsn` is optional |
| `STRONG` | Throws `BusinessException(BAD_REQUEST)` before proceeding if `changeRsn` is null or blank |

Use `STRONG` for high-sensitivity mutations (e.g. admin-forced password reset, role assignment, account termination).

---

## AuditLogAspect — Internal Flow

The aspect is an `@Around` advice triggered on any method annotated with `@AuditLog`.

```
Incoming call
     |
     v
1. Extract changeRsn from method args (looks for field named "changeRsn" in any arg object)
     |
     v
2. If level == STRONG and changeRsn is blank → throw BusinessException (method never executes)
     |
     v
3. Serialize request args to JSON (reqData) — excludes SecurityUser, HttpServletRequest, MultipartFile
     |
     v
4. pjp.proceed()  ← actual method executes here
     |
     v
5. Resolve targetId:
     a. If targetIdParam is set → evaluate SpEL expression against method parameters
     b. If action == CREATE and no targetId yet → inspect return value (ApiResponse.data.*Id / *Sq)
     c. Still empty → inspect arg object fields for *Id / *Sq
     |
     v
6. auditLogService.registerAuditLog(AuditLog.create(...))  ← async, non-blocking
     |
     v
Return result to caller
```

### targetId resolution priority (CREATE)

1. `targetIdParam` SpEL expression (explicit)
2. Response body field ending in `Id` or `Sq` (auto-detect from `ApiResponse.data`)
3. Request arg field ending in `Id` or `Sq` (fallback)

### Serialization exclusions

The following parameter types are skipped when building `reqData`:
- `SecurityUser` (authentication object)
- `HttpServletRequest`
- `MultipartFile` / `MultipartFile[]`

---

## Change Reason Handling (STRONG level)

The aspect scans all method arguments for a field named `changeRsn` (walks the class hierarchy). The standard way to carry this field is to extend or embed `AuditReasonRequest`:

```java
// AuditReasonRequest — base DTO
@Getter
@NoArgsConstructor
@AllArgsConstructor
public class AuditReasonRequest {
    @Size(max = 500, message = "변경 사유는 500자 이하여야 합니다.")
    private String changeRsn;
}
```

Request DTOs that need to support `STRONG` level auditing must include a `changeRsn` field — either by extending `AuditReasonRequest` or by declaring the field directly.

```java
// Option A: extend
public class UserUpdateRequest extends AuditReasonRequest {
    private String userName;
    // ...
}

// Option B: embed field directly
public class RoleAssignRequest {
    private String roleId;
    private String changeRsn;  // same field name required
}
```

The client must supply a non-blank value in the request body JSON:

```json
{
  "roleId": "USER_ROLE_ADM",
  "changeRsn": "Admin promotion approved by team lead"
}
```

---

## Usage Examples

### Basic CREATE (WEAK)

```java
@AuditLog(targetTb = "tb_board", action = AuditAction.CREATE)
public BoardCreateResponse createBoard(BoardCreateRequest request, SecurityUser user) {
    // targetId is auto-resolved from the response object's *Id/*Sq field
}
```

### UPDATE with explicit targetIdParam (WEAK)

```java
@AuditLog(targetTb = "tb_board", action = AuditAction.UPDATE, targetIdParam = "#boardSq")
public void updateBoard(Long boardSq, BoardUpdateRequest request) {
    // boardSq parameter is directly used as targetId
}
```

### DELETE with explicit targetIdParam (WEAK)

```java
@AuditLog(targetTb = "tb_user", action = AuditAction.DELETE, targetIdParam = "#userId")
public void deleteUser(String userId) {
    // userId parameter is used as targetId
}
```

### STRONG level — change reason required

```java
@AuditLog(
    targetTb = "tb_user",
    action = AuditAction.UPDATE,
    level = AuditLevel.STRONG,
    targetIdParam = "#userId"
)
public void updateUserRole(String userId, RoleAssignRequest request) {
    // BusinessException thrown before this executes if request.changeRsn is blank
}
```

### READ audit — sensitive data access

```java
@AuditLog(targetTb = "tb_user", action = AuditAction.READ, targetIdParam = "#userId")
public UserDetailResponse getUserDetail(String userId) {
    // logs the read access; changeRsn not required (WEAK default)
}
```

---

## Database Table Structure

Table: `tb_audit_log`

| Column | Java field | Type | Description |
|---|---|---|---|
| `audit_sq` | `auditSq` | BIGINT (PK, auto) | Auto-generated primary key |
| `target_tb` | `targetTb` | VARCHAR | Target table name (e.g. `tb_user`) |
| `target_id` | `targetId` | VARCHAR | PK value of the affected record |
| `actn_cd` | `actnCd` | VARCHAR | Action: `CREATE`, `UPDATE`, `DELETE`, `READ` |
| `chng_rsn` | `chngRsn` | VARCHAR | Change reason (required for `STRONG` level) |
| `req_data` | `reqData` | TEXT / JSON | Serialized request parameters (JSON) |
| `rgtr_id` | `rgtrId` | VARCHAR | User ID of the actor (`anonymous` if unauthenticated) |
| `reg_dt` | `regDt` | TIMESTAMP | Timestamp of the action (set to `LocalDateTime.now()` at creation) |
| `reg_ip` | `regIp` | VARCHAR | Client IP address (X-Forwarded-For aware; `::1` normalized to `127.0.0.1`) |

### INSERT statement (from AuditLogMapper.xml)

```xml
<insert id="save" useGeneratedKeys="true" keyProperty="auditSq" keyColumn="audit_sq">
    INSERT INTO tb_audit_log (target_tb, target_id, actn_cd, chng_rsn, req_data, rgtr_id, reg_dt, reg_ip)
    VALUES (#{targetTb}, #{targetId}, #{actnCd}, #{chngRsn}, #{reqData}, #{rgtrId}, #{regDt}, #{regIp})
</insert>
```

---

## Async Execution

`registerAuditLog` is annotated with `@Async("auditLogExecutor")`, meaning it runs on a separate thread pool and does not block the HTTP response. Failures are caught internally and logged as `[AUDIT-FAIL]` at ERROR level — they do not propagate back to the caller.

This means: even if audit log persistence fails, the business operation succeeds. This is intentional to prevent audit infrastructure issues from breaking normal service behavior.
