# 인증 보안 가이드

## 개요

안전한 인증 시스템 구현을 위한 보안 가이드입니다.

## 비밀번호 보안

### 비밀번호 해싱

**절대 평문으로 저장하지 마세요!**

```typescript
import bcrypt from 'bcrypt';

// ✅ Good - bcrypt로 해싱
async function hashPassword(password: string): Promise<string> {
  const saltRounds = 12; // 충분히 높은 cost factor
  return bcrypt.hash(password, saltRounds);
}

async function verifyPassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

// ❌ Bad - 평문 저장
const user = {
  email: 'user@example.com',
  password: 'password123', // 절대 안 됨!
};

// ❌ Bad - 약한 해싱 (MD5, SHA1)
const weakHash = crypto.createHash('md5').update(password).digest('hex');
```

### 비밀번호 정책

```typescript
function validatePassword(password: string): boolean {
  const requirements = [
    password.length >= 8, // 최소 8자
    /[a-z]/.test(password), // 소문자
    /[A-Z]/.test(password), // 대문자
    /[0-9]/.test(password), // 숫자
    /[!@#$%^&*]/.test(password), // 특수문자
  ];

  return requirements.every(Boolean);
}
```

### 비밀번호 재설정

```typescript
// ✅ Good - 안전한 토큰 생성
import crypto from 'crypto';

function generateResetToken(): string {
  return crypto.randomBytes(32).toString('hex');
}

async function createPasswordResetToken(userId: string): Promise<string> {
  const token = generateResetToken();
  const expiresAt = new Date(Date.now() + 3600000); // 1시간

  await db.passwordResetToken.create({
    data: {
      userId,
      token: await bcrypt.hash(token, 10), // 토큰도 해싱
      expiresAt,
    },
  });

  return token;
}

// ❌ Bad - 예측 가능한 토큰
const token = userId + Date.now(); // 취약!
```

## JWT (JSON Web Token)

### JWT 생성 및 검증

```typescript
import jwt from 'jsonwebtoken';

interface JWTPayload {
  userId: string;
  email: string;
  role: string;
}

// ✅ Good - 안전한 JWT 생성
function generateAccessToken(payload: JWTPayload): string {
  return jwt.sign(payload, process.env.JWT_SECRET!, {
    expiresIn: '15m', // 짧은 만료 시간
    algorithm: 'HS256',
    issuer: 'myapp',
    audience: 'myapp-api',
  });
}

function generateRefreshToken(userId: string): string {
  return jwt.sign({ userId }, process.env.JWT_REFRESH_SECRET!, {
    expiresIn: '7d',
    algorithm: 'HS256',
  });
}

// 검증
function verifyAccessToken(token: string): JWTPayload {
  return jwt.verify(token, process.env.JWT_SECRET!, {
    algorithms: ['HS256'],
    issuer: 'myapp',
    audience: 'myapp-api',
  }) as JWTPayload;
}

// ❌ Bad - 약한 시크릿
const JWT_SECRET = '123456'; // 절대 안 됨!

// ❌ Bad - 만료 시간 없음
jwt.sign(payload, secret); // 영원히 유효한 토큰!
```

### Refresh Token 관리

```typescript
// ✅ Good - Redis에 Refresh Token 저장
import Redis from 'ioredis';
const redis = new Redis();

async function storeRefreshToken(userId: string, token: string): Promise<void> {
  const key = `refresh_token:${userId}`;
  await redis.set(key, token, 'EX', 7 * 24 * 60 * 60); // 7일
}

async function validateRefreshToken(userId: string, token: string): Promise<boolean> {
  const stored = await redis.get(`refresh_token:${userId}`);
  return stored === token;
}

async function revokeRefreshToken(userId: string): Promise<void> {
  await redis.del(`refresh_token:${userId}`);
}

// ❌ Bad - Refresh Token을 JWT에만 의존
// 로그아웃 시 토큰을 무효화할 방법이 없음!
```

### JWT 미들웨어

```typescript
import { Request, Response, NextFunction } from 'express';

// ✅ Good - Express 미들웨어
async function authenticateJWT(req: Request, res: Response, next: NextFunction) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Missing token' });
    }

    const token = authHeader.substring(7);
    const payload = verifyAccessToken(token);

    // 블랙리스트 확인 (로그아웃된 토큰)
    const isBlacklisted = await redis.get(`blacklist:${token}`);
    if (isBlacklisted) {
      return res.status(401).json({ error: 'Token revoked' });
    }

    req.user = payload;
    next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      return res.status(401).json({ error: 'Token expired' });
    }
    return res.status(401).json({ error: 'Invalid token' });
  }
}
```

## OAuth 2.0

### OAuth 구현

```typescript
import passport from 'passport';
import { Strategy as GoogleStrategy } from 'passport-google-oauth20';

// ✅ Good - Google OAuth
passport.use(
  new GoogleStrategy(
    {
      clientID: process.env.GOOGLE_CLIENT_ID!,
      clientSecret: process.env.GOOGLE_CLIENT_SECRET!,
      callbackURL: '/auth/google/callback',
    },
    async (accessToken, refreshToken, profile, done) => {
      try {
        // 사용자 찾기 또는 생성
        let user = await db.user.findUnique({
          where: { email: profile.emails?.[0].value },
        });

        if (!user) {
          user = await db.user.create({
            data: {
              email: profile.emails?.[0].value!,
              name: profile.displayName,
              provider: 'google',
              providerId: profile.id,
            },
          });
        }

        return done(null, user);
      } catch (error) {
        return done(error);
      }
    }
  )
);

// ❌ Bad - 클라이언트 시크릿을 코드에 하드코딩
const CLIENT_SECRET = 'abc123xyz'; // 절대 안 됨!
```

### State 파라미터 (CSRF 방지)

```typescript
// ✅ Good - State 파라미터로 CSRF 방지
app.get('/auth/google', (req, res) => {
  const state = crypto.randomBytes(32).toString('hex');
  req.session.oauthState = state;

  const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  authUrl.searchParams.set('client_id', process.env.GOOGLE_CLIENT_ID!);
  authUrl.searchParams.set('redirect_uri', 'http://localhost:3000/auth/google/callback');
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('scope', 'email profile');
  authUrl.searchParams.set('state', state); // CSRF 토큰

  res.redirect(authUrl.toString());
});

app.get('/auth/google/callback', (req, res) => {
  const { state, code } = req.query;

  // State 검증
  if (state !== req.session.oauthState) {
    return res.status(403).json({ error: 'Invalid state' });
  }

  // 인증 코드 처리...
});
```

## 세션 보안

### 세션 설정

```typescript
import session from 'express-session';
import RedisStore from 'connect-redis';
import Redis from 'ioredis';

const redis = new Redis();

// ✅ Good - 안전한 세션 설정
app.use(
  session({
    store: new RedisStore({ client: redis }),
    secret: process.env.SESSION_SECRET!,
    resave: false,
    saveUninitialized: false,
    name: 'sessionId', // 기본 'connect.sid' 대신 커스텀 이름
    cookie: {
      httpOnly: true, // JavaScript 접근 차단
      secure: process.env.NODE_ENV === 'production', // HTTPS only
      sameSite: 'strict', // CSRF 방지
      maxAge: 24 * 60 * 60 * 1000, // 24시간
    },
  })
);

// ❌ Bad - 취약한 세션 설정
app.use(
  session({
    secret: '123', // 약한 시크릿
    cookie: {
      httpOnly: false, // XSS 취약
      secure: false, // HTTP에서도 전송
    },
  })
);
```

## 다중 인증 (Multi-Factor Authentication)

### TOTP 구현

```typescript
import speakeasy from 'speakeasy';
import QRCode from 'qrcode';

// ✅ Good - TOTP 설정
async function setupTOTP(userId: string, email: string) {
  const secret = speakeasy.generateSecret({
    name: `MyApp (${email})`,
    issuer: 'MyApp',
  });

  // QR 코드 생성
  const qrCode = await QRCode.toDataURL(secret.otpauth_url!);

  // 시크릿 저장 (암호화 필요!)
  await db.user.update({
    where: { id: userId },
    data: { totpSecret: encryptSecret(secret.base32) },
  });

  return { qrCode, secret: secret.base32 };
}

function verifyTOTP(secret: string, token: string): boolean {
  return speakeasy.totp.verify({
    secret,
    encoding: 'base32',
    token,
    window: 1, // 시간 오차 허용
  });
}
```

## 보안 체크리스트

### 필수 사항

- [ ] 비밀번호 해싱 (bcrypt, argon2)
- [ ] JWT 시크릿 강력하게 설정
- [ ] HTTPS 사용 (프로덕션)
- [ ] CORS 설정
- [ ] Rate Limiting
- [ ] SQL Injection 방지
- [ ] XSS 방지
- [ ] CSRF 방지
- [ ] 환경 변수로 시크릿 관리
- [ ] 로그아웃 시 토큰 무효화
- [ ] 비밀번호 재설정 토큰 만료 시간 설정
- [ ] 세션 고정 공격 방지

### 권장 사항

- [ ] 2FA/MFA 지원
- [ ] Refresh Token Rotation
- [ ] IP 기반 제한
- [ ] 이메일 인증
- [ ] 로그인 시도 제한
- [ ] 보안 헤더 설정 (Helmet.js)
- [ ] 감사 로그 (Audit Log)

## 보안 헤더

```typescript
import helmet from 'helmet';

// ✅ Good - Helmet으로 보안 헤더 설정
app.use(helmet());

// 또는 커스텀 설정
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'https:'],
      },
    },
    hsts: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: true,
    },
  })
);
```

## Rate Limiting

```typescript
import rateLimit from 'express-rate-limit';

// ✅ Good - 로그인 엔드포인트 Rate Limiting
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15분
  max: 5, // 최대 5회 시도
  message: 'Too many login attempts, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

app.post('/auth/login', loginLimiter, async (req, res) => {
  // 로그인 로직
});
```

## 관련 문서

- `xss-csrf.md`: XSS 및 CSRF 방지
- `sql-injection.md`: SQL Injection 방지
- `../conventions/api-design.md`: API 보안 설계
