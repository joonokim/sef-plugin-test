# OTP System Reference

## Overview

The OTP system provides email-based one-time password verification for user lifecycle events: signup email verification, temporary password issuance, dormancy reactivation, and account unlock. It uses two cooperating in-memory components:

- `OtpProvider` — generates, stores, validates, and rate-limits 6-digit OTPs
- `VerifyTokenProvider` — issues a short-lived UUID token after successful OTP validation, which authorizes the follow-up action

Both components use in-memory `ConcurrentHashMap` storage (no DB persistence). State is lost on application restart.

---

## OtpProvider

**Package:** `com.sqisoft.sef.infra.otp`

### Constants

| Constant | Value | Description |
|---|---|---|
| `OTP_LENGTH` | 6 | Digits per OTP |
| `OTP_EXPIRY_MINUTES` | 5 | Minutes until OTP auto-expires |
| `MAX_OTP_REQUESTS_PER_HOUR` | 30 | Max OTP sends per user+purpose per sliding hour window |
| `MAX_OTP_FAILURES` | 5 | Max wrong attempts before OTP is invalidated |
| `REQUEST_WINDOW_MILLIS` | 3,600,000 ms | Sliding window size for rate limiting |

### Storage

```java
Map<String, String>         otpStore              // key -> otp value
Map<String, Queue<Long>>    requestTimestampStore // key -> sliding window timestamps
Map<String, Integer>        failureCountStore     // key -> failure count
```

Key format: `"{userId}:{purpose.name()}"` e.g. `"user@example.com:TEMP_PASSWORD"`

### Generation

```java
public String createAndSave(String userId, OtpPurpose purpose)
```

1. Builds the store key from `userId` and `purpose`.
2. Applies sliding window rate limiting — drops timestamps older than 1 hour, then checks the count.
3. Throws `BusinessException(BAD_REQUEST)` if `>= 30` requests in the window.
4. Generates a 6-digit OTP using `SecureRandom`.
5. Stores OTP in `otpStore`.
6. Schedules auto-removal from `otpStore` after 5 minutes via `ScheduledExecutorService`.
7. Returns the plaintext OTP (caller sends it via email).

### Validation

```java
public void validate(String userId, OtpPurpose purpose, String inputOtp)
```

1. Looks up stored OTP by key.
2. If absent — throws `BusinessException`: "OTP가 만료되었습니다."
3. Compares using `MessageDigest.isEqual()` (constant-time, timing-attack safe).
4. On mismatch — increments failure counter; if `>= 5`, removes OTP and counter, then throws "OTP 시도 횟수를 초과했습니다." Otherwise throws "OTP가 일치하지 않습니다."
5. On match — removes OTP and failure counter (OTP is single-use).

### Cleanup

- Expired OTPs are removed by the scheduled task (5 min after creation).
- On application shutdown `@PreDestroy` calls `scheduler.shutdownNow()`.
- Empty request timestamp queues are cleaned up during the expiry callback.

---

## OtpPurpose Enum

**Package:** `com.sqisoft.sef.modules.user.domain`

```java
public enum OtpPurpose {
    SIGNUP("회원가입"),
    TEMP_PASSWORD("임시비밀번호"),
    DORMANCY("휴면해제"),
    ACCOUNT_UNLOCK("계정잠금해제");
}
```

| Value | Use Case | Required User Status |
|---|---|---|
| `SIGNUP` | Email verification before registration | User must NOT exist |
| `TEMP_PASSWORD` | Forgot password — triggers temp password email | `ACTIVE` |
| `DORMANCY` | Reactivate a dormant account | `INACTIVE` |
| `ACCOUNT_UNLOCK` | Unlock a locked account | `LOCKED` |

User status is validated in `UserServiceImpl.validateStatusForPurpose()` before OTP is generated.

---

## VerifyTokenProvider

**Package:** `com.sqisoft.sef.infra.otp`

Issues a short-lived UUID token immediately after a successful OTP validation. The token authorizes one follow-up action (temp password issuance, dormancy activation, account unlock). It is consumed (removed) on use.

### Constants

| Constant | Value |
|---|---|
| `TOKEN_EXPIRY_MINUTES` | 10 |

### Issuance

```java
public String createAndSave(String userId, OtpPurpose purpose)
```

- Generates `UUID.randomUUID().toString()`.
- Stores it under `"{userId}:{purpose.name()}"`.
- Schedules auto-removal after 10 minutes.
- Returns the token to be included in the `OtpVerifyResponse`.

### Validation

```java
public void validateAndRemove(String userId, OtpPurpose purpose, String inputToken)
```

- If absent — throws `BusinessException(BAD_REQUEST)`: "인증이 만료되었습니다."
- Compares using `MessageDigest.isEqual()` (constant-time).
- On mismatch — throws "유효하지 않은 인증 토큰입니다."
- On match — removes token immediately (single-use).

---

## OTP Flow

### Flow: SIGNUP (email verification only, no verifyToken)

```
POST /api/v1/users/otp          { userId, purpose: "SIGNUP" }
  -> UserService.sendOtp()
     -> assert user does NOT exist
     -> OtpProvider.createAndSave()  // generates OTP
     -> mailAdapter.sendOtp()        // emails OTP
  <- 200 OK

POST /api/v1/users/otp/verify   { userId, otp, purpose: "SIGNUP" }
  -> OtpProvider.validate()
  -> VerifyTokenProvider.createAndSave()  // token issued even for SIGNUP
  <- 200 OK { verifyToken: "..." }

POST /api/v1/users/register     { userId, userNm, userPswd, roleId, termsConsents }
  <- 201 Created
```

> Note: SIGNUP issues a verifyToken, but registration does not require it — the current `saveUser()` does not consume it.

### Flow: TEMP_PASSWORD

```
POST /api/v1/users/otp          { userId, purpose: "TEMP_PASSWORD" }
  -> assert user is ACTIVE
  -> OtpProvider.createAndSave() + mailAdapter.sendOtp()
  <- 200 OK

POST /api/v1/users/otp/verify   { userId, otp, purpose: "TEMP_PASSWORD" }
  -> OtpProvider.validate()
  -> VerifyTokenProvider.createAndSave()
  <- 200 OK { verifyToken: "uuid" }

POST /api/v1/users/temp-password  { userId, verifyToken }
  -> VerifyTokenProvider.validateAndRemove(userId, TEMP_PASSWORD, verifyToken)
  -> assert user is ACTIVE
  -> PasswordUtils.generateTempPassword()
  -> userMapper.saveTempPswd() + mailAdapter.sendTempPswd()
  <- 200 OK
```

### Flow: DORMANCY (reactivate dormant account)

```
POST /api/v1/users/otp          { userId, purpose: "DORMANCY" }
  -> assert user is INACTIVE
  -> OtpProvider.createAndSave() + mailAdapter.sendOtp()
  <- 200 OK

POST /api/v1/users/otp/verify   { userId, otp, purpose: "DORMANCY" }
  -> OtpProvider.validate()
  -> VerifyTokenProvider.createAndSave()
  <- 200 OK { verifyToken: "uuid" }

POST /api/v1/users/account/activate  { userId, verifyToken }
  -> VerifyTokenProvider.validateAndRemove(userId, DORMANCY, verifyToken)
  -> userMapper.updateStatus(ACTIVE)
  <- 200 OK
```

### Flow: ACCOUNT_UNLOCK

```
POST /api/v1/users/otp          { userId, purpose: "ACCOUNT_UNLOCK" }
  -> assert user is LOCKED
  -> OtpProvider.createAndSave() + mailAdapter.sendOtp()
  <- 200 OK

POST /api/v1/users/otp/verify   { userId, otp, purpose: "ACCOUNT_UNLOCK" }
  -> OtpProvider.validate()
  -> VerifyTokenProvider.createAndSave()
  <- 200 OK { verifyToken: "uuid" }

POST /api/v1/users/account/unlock  { userId, verifyToken }
  -> VerifyTokenProvider.validateAndRemove(userId, ACCOUNT_UNLOCK, verifyToken)
  -> userMapper.updateStatus(ACTIVE)
  -> userMapper.resetLoginFailCount()
  <- 200 OK
```

---

## Rate Limiting Rules

| Rule | Limit | Scope |
|---|---|---|
| Max OTP requests | 30 per hour | Per `userId + purpose` pair |
| Window type | Sliding window | Timestamps tracked in `ConcurrentLinkedQueue` |
| Max verify failures | 5 attempts | Per active OTP; OTP is destroyed on 5th failure |

The sliding window is maintained lazily: old timestamps are evicted from the queue head on each new `createAndSave()` call. No background cleanup runs for the timestamp store; empty queues are cleaned up only during OTP expiry callbacks.

---

## Security Measures

### Constant-Time Comparison

Both `OtpProvider` and `VerifyTokenProvider` use `MessageDigest.isEqual()` for all string comparisons, preventing timing-based side-channel attacks:

```java
// OtpProvider.validate()
if (!MessageDigest.isEqual(
        storedOtp.getBytes(StandardCharsets.UTF_8),
        inputOtp.getBytes(StandardCharsets.UTF_8))) { ... }

// VerifyTokenProvider.validateAndRemove()
if (!MessageDigest.isEqual(
        storedToken.getBytes(StandardCharsets.UTF_8),
        inputToken.getBytes(StandardCharsets.UTF_8))) { ... }
```

### Single-Use Tokens

- OTP is deleted from `otpStore` immediately after successful validation.
- `verifyToken` is deleted from `tokenStore` immediately after `validateAndRemove()`.

### Cryptographic Randomness

OTPs are generated with `java.security.SecureRandom`, not `java.util.Random`.

### Brute-Force Protection

After 5 failed OTP attempts the OTP is invalidated and a new one must be requested. Rate limiting (30/hour) prevents automated re-request loops.

---

## Configuration

No external configuration properties. All limits are defined as compile-time constants in `OtpProvider` and `VerifyTokenProvider`. To change limits, edit the constants directly:

```java
// OtpProvider.java
private static final int OTP_LENGTH = 6;
private static final long OTP_EXPIRY_MINUTES = 5;
private static final int MAX_OTP_REQUESTS_PER_HOUR = 30;
private static final int MAX_OTP_FAILURES = 5;

// VerifyTokenProvider.java
private static final long TOKEN_EXPIRY_MINUTES = 10;
```

Both beans are Spring `@Component`s, auto-detected by component scan.

---

## Usage Examples

### Sending OTP (Service layer)

```java
// UserServiceImpl.sendOtp()
String otp = otpProvider.createAndSave(request.getUserId(), request.getPurpose());
mailAdapter.sendOtp(request.getUserId(), otp);
```

### Verifying OTP and issuing verifyToken

```java
// UserServiceImpl.verifyOtp()
otpProvider.validate(request.getUserId(), request.getPurpose(), request.getOtp());
String token = verifyTokenProvider.createAndSave(request.getUserId(), request.getPurpose());
return OtpVerifyResponse.of(token);
```

### Consuming verifyToken for a follow-up action

```java
// UserServiceImpl.issueTempPswd()
verifyTokenProvider.validateAndRemove(request.getUserId(), OtpPurpose.TEMP_PASSWORD, request.getVerifyToken());
// ... proceed with temp password generation

// UserServiceImpl.activateDormantAccount()
verifyTokenProvider.validateAndRemove(userId, OtpPurpose.DORMANCY, verifyToken);
// ... proceed with status update

// UserServiceImpl.unlockAccount()
verifyTokenProvider.validateAndRemove(userId, OtpPurpose.ACCOUNT_UNLOCK, verifyToken);
// ... proceed with unlock + reset login fail count
```

### Controller endpoints (all under `/api/v1/users`, no auth required)

| Method | Path | Request Body | Response |
|---|---|---|---|
| POST | `/otp` | `{ userId, purpose }` | `200 OK` |
| POST | `/otp/verify` | `{ userId, otp, purpose }` | `{ verifyToken }` |
| POST | `/temp-password` | `{ userId, verifyToken }` | `200 OK` |
| POST | `/account/activate` | `{ userId, verifyToken }` | `200 OK` |
| POST | `/account/unlock` | `{ userId, verifyToken }` | `200 OK` |
