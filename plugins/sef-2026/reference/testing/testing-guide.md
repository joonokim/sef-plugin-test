# 테스팅 가이드

## 개요

효과적인 테스트 작성을 위한 가이드입니다.

## 테스트 피라미드

```
        /\
       /  \
      / E2E\        10% - End-to-End Tests
     /______\
    /        \
   /Integration\ 30% - Integration Tests
  /____________\
 /              \
/  Unit Tests    \ 60% - Unit Tests
/________________\
```

### 1. Unit Tests (단위 테스트) - 60%

**목적**: 개별 함수/클래스의 로직 검증

**특징**:
- 빠른 실행 속도
- 독립적 실행
- Mock/Stub 사용

**예시**:
```typescript
// user.service.test.ts
import { UserService } from './user.service';
import { UserRepository } from './user.repository';

describe('UserService', () => {
  let service: UserService;
  let repository: jest.Mocked<UserRepository>;

  beforeEach(() => {
    repository = {
      findById: jest.fn(),
      save: jest.fn(),
    } as any;
    service = new UserService(repository);
  });

  describe('findById', () => {
    it('should return user when found', async () => {
      // Arrange
      const userId = '123';
      const mockUser = { id: userId, name: 'John' };
      repository.findById.mockResolvedValue(mockUser);

      // Act
      const result = await service.findById(userId);

      // Assert
      expect(result).toEqual(mockUser);
      expect(repository.findById).toHaveBeenCalledWith(userId);
    });

    it('should return null when user not found', async () => {
      repository.findById.mockResolvedValue(null);

      const result = await service.findById('999');

      expect(result).toBeNull();
    });

    it('should throw error when repository fails', async () => {
      repository.findById.mockRejectedValue(new Error('DB error'));

      await expect(service.findById('123')).rejects.toThrow('DB error');
    });
  });
});
```

### 2. Integration Tests (통합 테스트) - 30%

**목적**: 여러 컴포넌트가 함께 동작하는지 검증

**특징**:
- 실제 데이터베이스 사용 (테스트 DB)
- API 엔드포인트 테스트
- 중간 속도

**예시**:
```typescript
// user.api.test.ts
import request from 'supertest';
import { app } from '../app';
import { db } from '../db';

describe('User API', () => {
  beforeAll(async () => {
    await db.migrate.latest();
  });

  afterAll(async () => {
    await db.destroy();
  });

  beforeEach(async () => {
    await db('users').truncate();
  });

  describe('POST /api/users', () => {
    it('should create a new user', async () => {
      const userData = {
        name: 'John Doe',
        email: 'john@example.com',
        password: 'password123',
      };

      const response = await request(app)
        .post('/api/users')
        .send(userData)
        .expect(201);

      expect(response.body).toMatchObject({
        name: userData.name,
        email: userData.email,
      });
      expect(response.body).not.toHaveProperty('password');

      // 데이터베이스 검증
      const user = await db('users').where({ email: userData.email }).first();
      expect(user).toBeDefined();
    });

    it('should return 400 for invalid email', async () => {
      const response = await request(app)
        .post('/api/users')
        .send({ name: 'John', email: 'invalid-email', password: 'password123' })
        .expect(400);

      expect(response.body.error).toContain('email');
    });

    it('should return 409 for duplicate email', async () => {
      const userData = { name: 'John', email: 'john@example.com', password: 'password123' };

      await request(app).post('/api/users').send(userData).expect(201);

      const response = await request(app).post('/api/users').send(userData).expect(409);

      expect(response.body.error).toContain('already exists');
    });
  });
});
```

### 3. E2E Tests (End-to-End 테스트) - 10%

**목적**: 실제 사용자 시나리오 검증

**특징**:
- 브라우저 자동화 (Playwright, Cypress)
- 느린 실행 속도
- 전체 시스템 테스트

**예시**:
```typescript
// login.e2e.test.ts
import { test, expect } from '@playwright/test';

test.describe('Login Flow', () => {
  test('should login successfully with valid credentials', async ({ page }) => {
    // 로그인 페이지로 이동
    await page.goto('http://localhost:3000/login');

    // 폼 입력
    await page.fill('input[name="email"]', 'test@example.com');
    await page.fill('input[name="password"]', 'password123');

    // 로그인 버튼 클릭
    await page.click('button[type="submit"]');

    // 대시보드로 리디렉션 확인
    await expect(page).toHaveURL('http://localhost:3000/dashboard');

    // 사용자 이름 표시 확인
    await expect(page.locator('[data-testid="user-name"]')).toContainText('Test User');
  });

  test('should show error for invalid credentials', async ({ page }) => {
    await page.goto('http://localhost:3000/login');

    await page.fill('input[name="email"]', 'wrong@example.com');
    await page.fill('input[name="password"]', 'wrongpassword');
    await page.click('button[type="submit"]');

    // 에러 메시지 확인
    await expect(page.locator('[role="alert"]')).toContainText('Invalid email or password');

    // 여전히 로그인 페이지에 있는지 확인
    await expect(page).toHaveURL('http://localhost:3000/login');
  });
});
```

## AAA 패턴

모든 테스트는 AAA 패턴을 따릅니다:

```typescript
it('should calculate total price correctly', () => {
  // Arrange (준비)
  const items = [
    { price: 100, quantity: 2 },
    { price: 50, quantity: 3 },
  ];

  // Act (실행)
  const total = calculateTotal(items);

  // Assert (검증)
  expect(total).toBe(350);
});
```

## 테스트 명명 규칙

### 패턴

```
should [expected behavior] when [condition]
```

### 예시

```typescript
describe('UserService', () => {
  it('should return user when user exists');
  it('should return null when user not found');
  it('should throw error when user id is invalid');
});

describe('calculateDiscount', () => {
  it('should apply 10% discount when user is premium');
  it('should apply 5% discount when user is regular');
  it('should not apply discount when cart is empty');
});
```

## Mock vs Stub vs Spy

### Mock

전체 객체를 가짜로 대체

```typescript
const mockRepository = {
  findById: jest.fn(),
  save: jest.fn(),
  delete: jest.fn(),
} as jest.Mocked<UserRepository>;
```

### Stub

특정 메서드만 가짜 응답 반환

```typescript
jest.spyOn(repository, 'findById').mockResolvedValue(mockUser);
```

### Spy

실제 구현을 호출하되, 호출 내역 추적

```typescript
const spy = jest.spyOn(emailService, 'send');
await userService.register(userData);
expect(spy).toHaveBeenCalledWith('welcome@example.com', expect.any(String));
```

## 테스트 커버리지

### 목표

- **전체**: 80% 이상
- **핵심 비즈니스 로직**: 100%
- **유틸리티 함수**: 90% 이상

### 커버리지 확인

```bash
pnpm test --coverage
```

### 커버리지 리포트

```
---------------------------|---------|----------|---------|---------|
File                       | % Stmts | % Branch | % Funcs | % Lines |
---------------------------|---------|----------|---------|---------|
All files                  |   85.32 |    78.56 |   89.12 |   84.89 |
 src/auth                  |   92.15 |    86.34 |   95.00 |   91.88 |
  auth.service.ts          |   95.00 |    90.00 |  100.00 |   94.50 |
  jwt.service.ts           |   89.30 |    82.68 |   90.00 |   89.10 |
 src/user                  |   78.50 |    70.22 |   83.24 |   77.99 |
  user.service.ts          |   80.00 |    72.00 |   85.00 |   79.50 |
---------------------------|---------|----------|---------|---------|
```

## 테스트 데이터 관리

### Fixtures (고정 데이터)

```typescript
// fixtures/users.ts
export const mockUsers = {
  john: {
    id: '1',
    name: 'John Doe',
    email: 'john@example.com',
    role: 'user',
  },
  admin: {
    id: '2',
    name: 'Admin User',
    email: 'admin@example.com',
    role: 'admin',
  },
};
```

### Factories (동적 생성)

```typescript
// factories/user.factory.ts
export function createUser(overrides?: Partial<User>): User {
  return {
    id: Math.random().toString(36),
    name: 'Test User',
    email: `test${Date.now()}@example.com`,
    createdAt: new Date(),
    ...overrides,
  };
}

// 사용
const user1 = createUser();
const user2 = createUser({ name: 'John' });
```

## 비동기 테스트

### async/await

```typescript
it('should fetch user data', async () => {
  const user = await userService.findById('123');
  expect(user.name).toBe('John');
});
```

### 에러 처리

```typescript
it('should throw error when user not found', async () => {
  await expect(userService.findById('999')).rejects.toThrow('User not found');
});
```

### Timeout

```typescript
it('should complete within 5 seconds', async () => {
  // 기본 5초 타임아웃
}, 5000);
```

## 테스트 격리

### beforeEach / afterEach

```typescript
describe('UserService', () => {
  let service: UserService;

  beforeEach(() => {
    service = new UserService();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('test 1', () => {
    // 매 테스트마다 새로운 service 인스턴스
  });

  it('test 2', () => {
    // 격리된 환경에서 테스트
  });
});
```

### 데이터베이스 격리

```typescript
beforeEach(async () => {
  await db('users').truncate(); // 테이블 비우기
});
```

## Snapshot Testing

### 컴포넌트 스냅샷

```typescript
import { render } from '@testing-library/react';
import { UserCard } from './UserCard';

it('should match snapshot', () => {
  const { container } = render(<UserCard user={mockUser} />);
  expect(container).toMatchSnapshot();
});
```

### API 응답 스냅샷

```typescript
it('should return expected user structure', async () => {
  const response = await request(app).get('/api/users/123');
  expect(response.body).toMatchSnapshot({
    id: expect.any(String),
    createdAt: expect.any(String),
  });
});
```

## 모범 사례

### ✅ Do

1. **테스트는 독립적이어야 함**
   ```typescript
   // Good
   it('test 1', () => { /* 독립적 */ });
   it('test 2', () => { /* 독립적 */ });
   ```

2. **한 테스트에 하나의 검증**
   ```typescript
   // Good
   it('should validate email format', () => {
     expect(validateEmail('test@example.com')).toBe(true);
   });
   ```

3. **의미 있는 테스트 이름**
   ```typescript
   // Good
   it('should return 400 when email is invalid', () => {});

   // Bad
   it('test1', () => {});
   ```

4. **엣지 케이스 테스트**
   ```typescript
   describe('divide', () => {
     it('should divide two numbers', () => {});
     it('should throw error when dividing by zero', () => {});
     it('should handle negative numbers', () => {});
     it('should handle decimal numbers', () => {});
   });
   ```

### ❌ Don't

1. **테스트 간 의존성**
   ```typescript
   // Bad
   let userId: string;
   it('should create user', () => {
     userId = '123'; // 다음 테스트가 이 값에 의존
   });
   it('should get user', () => {
     expect(getUser(userId)).toBeDefined();
   });
   ```

2. **실제 외부 서비스 호출**
   ```typescript
   // Bad
   it('should send email', async () => {
     await emailService.send('real@example.com', 'test'); // 실제 이메일 전송!
   });

   // Good
   it('should send email', async () => {
     jest.spyOn(emailService, 'send').mockResolvedValue(true);
   });
   ```

3. **타임아웃에 의존하는 테스트**
   ```typescript
   // Bad
   it('should update after delay', async () => {
     setTimeout(() => updateValue(), 1000);
     await sleep(1500);
     expect(value).toBe(10);
   });
   ```

## TDD (Test-Driven Development)

### Red-Green-Refactor 사이클

```
1. Red: 실패하는 테스트 작성
   ↓
2. Green: 테스트를 통과하는 최소한의 코드 작성
   ↓
3. Refactor: 코드 개선
   ↓
반복
```

### 예시

```typescript
// 1. Red - 실패하는 테스트 작성
it('should calculate sum of two numbers', () => {
  expect(add(2, 3)).toBe(5);
});

// 2. Green - 테스트 통과하는 코드
function add(a: number, b: number): number {
  return a + b;
}

// 3. Refactor - 더 많은 케이스 추가
it('should handle negative numbers', () => {
  expect(add(-2, 3)).toBe(1);
});
```

## CI/CD 통합

### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '20'
      - run: pnpm install
      - run: pnpm test --coverage
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

## 관련 도구

- **Jest**: JavaScript 테스팅 프레임워크
- **Vitest**: Vite 기반 테스트 러너
- **Playwright**: E2E 테스팅
- **Cypress**: E2E 테스팅
- **Testing Library**: React/Vue 컴포넌트 테스팅
- **Supertest**: API 테스팅
- **MSW**: API Mocking

## 관련 문서

- `../conventions/typescript-style.md`: TypeScript 코딩 스타일
- `../workflows/pull-request.md`: PR 워크플로우
- `../security/`: 보안 테스팅
