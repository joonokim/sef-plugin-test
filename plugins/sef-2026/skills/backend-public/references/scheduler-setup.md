# Scheduler Setup

Spring's `@Scheduled` task execution for the SEF 2026 framework. Three built-in schedulers handle token cleanup, dormancy enforcement, and password expiry checks.

---

## Overview

| Scheduler | Default Schedule | Conditional |
|---|---|---|
| `TokenCleanupScheduler` | Daily at 02:00 | JWT mode only |
| `DormancyScheduler` | Daily at 01:00 | Always active |
| `PasswordChangeScheduler` | Daily at 00:00 | JWT mode only |

All schedulers live in `com.sqisoft.sef.infra.scheduler` and depend on the `@EnableScheduling` annotation in `SchedulingConfig`.

---

## SchedulingConfig

`src/main/java/com/sqisoft/sef/infra/config/SchedulingConfig.java`

```java
@Configuration
@EnableScheduling
public class SchedulingConfig {
}
```

This single class enables Spring's scheduling infrastructure for the entire application. No additional setup is required to add new schedulers — any `@Component` with a `@Scheduled` method is automatically picked up.

---

## TokenCleanupScheduler

**File:** `src/main/java/com/sqisoft/sef/infra/scheduler/TokenCleanupScheduler.java`

**Purpose:** Removes expired JWT refresh tokens from both the database and the in-memory revoked-token store. Prevents unbounded growth of stale token records.

**Schedule:** Daily at 02:00 (configurable via `security.jwt.cleanup-cron`).

**Conditional activation:** Only active when `security.auth.mode=jwt`. The scheduler bean is not created in session-based auth mode.

```java
@Component
@RequiredArgsConstructor
@Slf4j
@ConditionalOnProperty(name = "security.auth.mode", havingValue = "jwt")
public class TokenCleanupScheduler {

    private final RefreshTokenService refreshTokenService;
    private final TokenStore tokenStore;

    @Scheduled(cron = "${security.jwt.cleanup-cron:0 0 2 * * ?}")
    public void cleanupExpiredTokens() {
        log.info("만료된 토큰 정리 작업 시작");
        try {
            int deletedCount = refreshTokenService.cleanupExpiredTokens();
            log.info("데이터베이스에서 {}개의 만료된 리프레시 토큰 정리 완료", deletedCount);

            tokenStore.cleanupExpiredTokens();
            log.info("메모리에서 만료된 폐기 토큰 정리 완료");
        } catch (Exception e) {
            log.error("토큰 정리 작업 중 오류 발생: {}", e.getMessage(), e);
        }
    }
}
```

**Operations (in order):**
1. Delete expired rows from the refresh token table via `RefreshTokenService.cleanupExpiredTokens()` — returns the count of deleted rows.
2. Evict expired entries from the in-memory `TokenStore` (revoked/blacklisted tokens).

---

## DormancyScheduler

**File:** `src/main/java/com/sqisoft/sef/infra/scheduler/DormancyScheduler.java`

**Purpose:** Marks long-inactive users as dormant (inactive status). Enforces the Korean Personal Information Protection Act (개인정보보호법) requirement that accounts inactive for 1 year must be converted to dormant status.

**Schedule:** Daily at 01:00 (configurable via `scheduler.dormancy.cron`).

**Dormancy period:** 365 days since last login (configurable via `scheduler.dormancy.dormancy-days`).

```java
@Slf4j
@Component
@RequiredArgsConstructor
public class DormancyScheduler {

    @Value("${scheduler.dormancy.dormancy-days:365}")
    private int dormancyDays;

    private final UserMapper userMapper;

    @Scheduled(cron = "${scheduler.dormancy.cron:0 0 1 * * ?}")
    public void processDormantUsers() {
        LocalDateTime dormancyBaseDate = LocalDateTime.now().minusDays(dormancyDays);
        log.info("휴면 처리 스케줄러 시작: 기준일={}", dormancyBaseDate);

        int count = userMapper.updateStatusToInactiveForDormant(dormancyBaseDate);
        log.info("휴면 처리 완료: {}명", count);
    }
}
```

**Notes:**
- No `@ConditionalOnProperty` — always active regardless of auth mode.
- The cutoff date is computed at runtime as `now() - dormancyDays`.
- The mapper call `updateStatusToInactiveForDormant(dormancyBaseDate)` bulk-updates all users whose last login is before the cutoff.
- No try/catch: any DB failure propagates and is logged by Spring's task executor.

---

## PasswordChangeScheduler

**File:** `src/main/java/com/sqisoft/sef/infra/scheduler/PasswordChangeScheduler.java`

**Purpose:** Detects users whose password has not been changed within the allowed expiry window and flags them with `req_pswd_chg_yn = 'Y'`. On the next login, the application enforces a mandatory password change for flagged users.

**Schedule:** Daily at 00:00 (configured via `scheduler.pswd.chg-cron` — no default fallback, property is required).

**Expiry period:** 90 days since last password change (configured via `scheduler.pswd.expiry-days` — required, no default).

**Conditional activation:** Only active when `security.auth.mode=jwt`.

```java
@Slf4j
@Component
@RequiredArgsConstructor
@ConditionalOnProperty(name = "security.auth.mode", havingValue = "jwt")
public class PasswordChangeScheduler {

    private final UserMapper userMapper;

    @Value("${scheduler.pswd.expiry-days}")
    private int expiryDays;

    @Scheduled(cron = "${scheduler.pswd.chg-cron}")
    public void checkPswdExpiry() {
        log.info("비밀번호 만료 체크 시작 (기준: {}일 경과)", expiryDays);
        try {
            LocalDateTime expiredDate = LocalDateTime.now().minusDays(expiryDays);
            int updatedCount = userMapper.updateReqPswdChgForExpired(expiredDate);
            log.info("비밀번호 변경 요구 플래그 업데이트 완료: {}명", updatedCount);
        } catch (Exception e) {
            log.error("비밀번호 만료 체크 중 오류 발생: {}", e.getMessage(), e);
        }
    }
}
```

**Operation:** Sets `req_pswd_chg_yn = 'Y'` for every user whose `pswd_chg_dt` (password change date) is older than `now() - expiryDays`.

---

## Configuration Properties

All scheduler properties are declared in `src/main/resources/application.yml`:

```yaml
# Scheduler settings
scheduler:
  # Password expiry check
  pswd:
    chg-cron: "0 0 0 * * ?"     # Daily at midnight (REQUIRED - no default)
    expiry-days: 90              # Days before password expires (REQUIRED - no default)

  # Dormancy enforcement
  dormancy:
    cron: "0 0 1 * * ?"         # Daily at 01:00 (default if omitted)
    dormancy-days: 365           # Days of inactivity before dormancy (default: 365)

# Token cleanup cron lives under security.jwt
security:
  auth:
    mode: jwt                    # Enables JWT-conditional schedulers
  jwt:
    cleanup-cron: "0 0 2 * * ?" # Daily at 02:00 (default if omitted)
```

**Cron format:** `second minute hour day-of-month month day-of-week`

Common cron examples:

| Expression | Meaning |
|---|---|
| `0 0 2 * * ?` | Daily at 02:00 |
| `0 0 1 * * ?` | Daily at 01:00 |
| `0 0 0 * * ?` | Daily at midnight |
| `0 0 3 * * MON` | Every Monday at 03:00 |
| `0 0/30 * * * ?` | Every 30 minutes |

**Property requirements summary:**

| Property | Required | Default |
|---|---|---|
| `scheduler.pswd.chg-cron` | Yes | None — app fails to start if missing |
| `scheduler.pswd.expiry-days` | Yes | None — app fails to start if missing |
| `scheduler.dormancy.cron` | No | `0 0 1 * * ?` |
| `scheduler.dormancy.dormancy-days` | No | `365` |
| `security.jwt.cleanup-cron` | No | `0 0 2 * * ?` |

---

## Error Handling Pattern

`TokenCleanupScheduler` and `PasswordChangeScheduler` wrap their logic in try/catch and log errors without rethrowing:

```java
try {
    // ... work ...
} catch (Exception e) {
    log.error("작업 중 오류 발생: {}", e.getMessage(), e);
}
```

`DormancyScheduler` has no try/catch — exceptions propagate to Spring's `TaskScheduler`, which logs them and continues scheduling future runs.

**Recommendation:** Add try/catch in new schedulers so a single failure does not disrupt the log with uncaught exception stack traces and makes monitoring cleaner.

---

## Adding a New Scheduler

**Step 1.** Create the class in `com.sqisoft.sef.infra.scheduler`:

```java
package com.sqisoft.sef.infra.scheduler;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

@Slf4j
@Component
@RequiredArgsConstructor
// Optional: only activate under a specific condition
// @ConditionalOnProperty(name = "security.auth.mode", havingValue = "jwt")
public class MyNewScheduler {

    @Value("${scheduler.my-task.cron}")
    private String cron; // or inject directly into @Scheduled via SpEL

    @Value("${scheduler.my-task.some-days:30}")
    private int someDays;

    private final SomeMapper someMapper; // inject required dependencies

    @Scheduled(cron = "${scheduler.my-task.cron}")
    public void runTask() {
        log.info("MyNewScheduler 시작 (기준: {}일)", someDays);
        try {
            int count = someMapper.doSomething(someDays);
            log.info("MyNewScheduler 완료: {}건 처리", count);
        } catch (Exception e) {
            log.error("MyNewScheduler 오류: {}", e.getMessage(), e);
        }
    }
}
```

**Step 2.** Add properties to `application.yml`:

```yaml
scheduler:
  my-task:
    cron: "0 0 3 * * ?"   # Daily at 03:00
    some-days: 30
```

**Step 3.** Write the mapper method and XML query in `src/main/resources/mybatis/mapper/{module}/`.

**Step 4.** No changes needed to `SchedulingConfig` — `@EnableScheduling` already picks up all `@Component` beans with `@Scheduled` methods.

**Step 5.** Verify startup: if using `@Value` without a default (`:fallback`), the app will fail to start with `IllegalArgumentException` if the property is missing. Add the property to all environment-specific property files under `src/main/resources/properties/`.
