# TypeScript 코딩 스타일 가이드

## 개요

일관된 TypeScript 코드 작성을 위한 스타일 가이드입니다.

## 네이밍 컨벤션

### 변수 및 함수: camelCase

```typescript
// ✅ Good
const userName = 'John';
const isActive = true;
function getUserById(id: string) { }
async function fetchUserData() { }

// ❌ Bad
const UserName = 'John';
const is_active = true;
function GetUserById(id: string) { }
```

### 클래스 및 인터페이스: PascalCase

```typescript
// ✅ Good
class UserService { }
interface UserData { }
type ApiResponse<T> = { }

// ❌ Bad
class userService { }
interface userData { }
```

### 상수: UPPER_SNAKE_CASE

```typescript
// ✅ Good
const API_BASE_URL = 'https://api.example.com';
const MAX_RETRY_COUNT = 3;

// ❌ Bad
const apiBaseUrl = 'https://api.example.com';
const maxRetryCount = 3;
```

### Private 멤버: _prefix (선택사항)

```typescript
class User {
  private _id: string;
  private _password: string;

  public get id() {
    return this._id;
  }
}
```

### 타입 파라미터: 단일 대문자 또는 PascalCase

```typescript
// ✅ Good
type Box<T> = { value: T };
type Result<TData, TError> = { };

// ❌ Bad
type Box<t> = { value: t };
```

## 타입 정의

### 명시적 타입 선언

```typescript
// ✅ Good - 타입이 명확하지 않을 때
const users: User[] = [];
const config: AppConfig = loadConfig();

// ✅ Good - 타입 추론 가능
const count = 0;
const name = 'John';
const isActive = true;

// ❌ Bad - 불필요한 타입 선언
const count: number = 0;
```

### Interface vs Type

**Interface 사용** (객체 구조 정의)
```typescript
interface User {
  id: string;
  name: string;
  email: string;
}

interface UserRepository {
  findById(id: string): Promise<User | null>;
  save(user: User): Promise<void>;
}
```

**Type 사용** (유니온, 인터섹션, 유틸리티 타입)
```typescript
type Status = 'pending' | 'approved' | 'rejected';
type Result<T> = { success: true; data: T } | { success: false; error: string };
type UserWithTimestamps = User & { createdAt: Date; updatedAt: Date };
```

### 유틸리티 타입 활용

```typescript
interface User {
  id: string;
  name: string;
  email: string;
  password: string;
}

// Partial - 모든 속성을 선택적으로
type UserUpdate = Partial<User>;

// Pick - 특정 속성만 선택
type UserPublic = Pick<User, 'id' | 'name' | 'email'>;

// Omit - 특정 속성 제외
type UserCreate = Omit<User, 'id'>;

// Readonly - 읽기 전용
type UserReadonly = Readonly<User>;
```

## 함수

### 화살표 함수 vs 함수 선언

```typescript
// ✅ Good - 일반 함수 선언 (호이스팅 필요)
function calculateTotal(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price, 0);
}

// ✅ Good - 화살표 함수 (콜백, 짧은 함수)
const doubled = numbers.map(n => n * 2);
const handleClick = () => console.log('clicked');

// ✅ Good - async/await
async function fetchUser(id: string): Promise<User> {
  const response = await fetch(`/api/users/${id}`);
  return response.json();
}
```

### 함수 시그니처

```typescript
// ✅ Good - 명확한 타입
function createUser(data: UserCreateDTO): Promise<User> { }

// ✅ Good - 옵셔널 파라미터
function findUsers(filter?: UserFilter): Promise<User[]> { }

// ✅ Good - 기본값
function paginate(page = 1, limit = 10) { }

// ❌ Bad - any 타입
function processData(data: any) { }
```

### 제네릭 함수

```typescript
// ✅ Good
function firstElement<T>(arr: T[]): T | undefined {
  return arr[0];
}

async function fetchData<T>(url: string): Promise<T> {
  const response = await fetch(url);
  return response.json();
}

// 타입 제약
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}
```

## 클래스

### 클래스 구조

```typescript
class UserService {
  // 1. 정적 멤버
  static readonly DEFAULT_LIMIT = 10;

  // 2. 인스턴스 멤버 (private → public)
  private readonly repository: UserRepository;
  private cache: Map<string, User>;
  public config: ServiceConfig;

  // 3. 생성자
  constructor(repository: UserRepository, config?: ServiceConfig) {
    this.repository = repository;
    this.cache = new Map();
    this.config = config ?? DEFAULT_CONFIG;
  }

  // 4. 정적 메서드
  static create(repository: UserRepository): UserService {
    return new UserService(repository);
  }

  // 5. Public 메서드
  async findById(id: string): Promise<User | null> {
    return this.getCachedUser(id) ?? await this.repository.findById(id);
  }

  // 6. Private 메서드
  private getCachedUser(id: string): User | null {
    return this.cache.get(id) ?? null;
  }
}
```

### 추상 클래스와 인터페이스

```typescript
// 추상 클래스 (공통 구현 + 추상 메서드)
abstract class BaseRepository<T> {
  protected abstract tableName: string;

  async findAll(): Promise<T[]> {
    // 공통 구현
    return db.query(`SELECT * FROM ${this.tableName}`);
  }

  abstract validate(data: T): boolean;
}

// 인터페이스 (계약만 정의)
interface Repository<T> {
  findById(id: string): Promise<T | null>;
  save(data: T): Promise<void>;
  delete(id: string): Promise<void>;
}
```

## 모듈 및 임포트

### 임포트 순서

```typescript
// 1. 외부 라이브러리
import { useState, useEffect } from 'react';
import axios from 'axios';

// 2. 내부 모듈 (절대 경로)
import { UserService } from '@/services/user';
import { API_BASE_URL } from '@/config';

// 3. 상대 경로
import { Button } from '../components/Button';
import { formatDate } from './utils';

// 4. 타입 임포트 (분리)
import type { User, UserCreateDTO } from '@/types';
```

### Named Export vs Default Export

```typescript
// ✅ Good - Named Export (권장)
// user-service.ts
export class UserService { }
export function createUserService() { }

// main.ts
import { UserService, createUserService } from './user-service';

// ✅ Good - Default Export (컴포넌트)
// Button.tsx
export default function Button() { }

// App.tsx
import Button from './Button';
```

## 에러 처리

### Try-Catch

```typescript
// ✅ Good
async function fetchUser(id: string): Promise<User> {
  try {
    const response = await fetch(`/api/users/${id}`);
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    return response.json();
  } catch (error) {
    if (error instanceof Error) {
      console.error('Failed to fetch user:', error.message);
    }
    throw error;
  }
}

// ✅ Good - 커스텀 에러
class UserNotFoundError extends Error {
  constructor(id: string) {
    super(`User not found: ${id}`);
    this.name = 'UserNotFoundError';
  }
}
```

### Result 타입 패턴

```typescript
type Result<T, E = Error> =
  | { success: true; data: T }
  | { success: false; error: E };

async function fetchUser(id: string): Promise<Result<User>> {
  try {
    const user = await userRepo.findById(id);
    return { success: true, data: user };
  } catch (error) {
    return { success: false, error: error as Error };
  }
}

// 사용
const result = await fetchUser('123');
if (result.success) {
  console.log(result.data.name);
} else {
  console.error(result.error.message);
}
```

## 비동기 처리

### Async/Await (권장)

```typescript
// ✅ Good
async function loadUserData(id: string) {
  const user = await userService.findById(id);
  const orders = await orderService.findByUserId(id);
  return { user, orders };
}

// 병렬 처리
async function loadDashboard(userId: string) {
  const [user, orders, notifications] = await Promise.all([
    userService.findById(userId),
    orderService.findByUserId(userId),
    notificationService.findByUserId(userId),
  ]);
  return { user, orders, notifications };
}
```

### Promise Chaining (필요시)

```typescript
// ✅ Good - 순차적 의존성
fetch('/api/user')
  .then(res => res.json())
  .then(user => fetch(`/api/orders?userId=${user.id}`))
  .then(res => res.json())
  .catch(error => console.error(error));
```

## Null 안전성

### Optional Chaining과 Nullish Coalescing

```typescript
// ✅ Good
const userName = user?.profile?.name ?? 'Anonymous';
const port = config.server?.port ?? 3000;

// ✅ Good - 안전한 배열 접근
const firstUser = users?.[0];

// ❌ Bad
const userName = user && user.profile && user.profile.name || 'Anonymous';
```

### Non-null Assertion (신중하게 사용)

```typescript
// ✅ Good - 타입 좁히기
if (user) {
  console.log(user.name); // user는 확실히 존재
}

// ⚠️ 주의 - Non-null assertion (확실할 때만)
const element = document.getElementById('app')!;
```

## 코드 포매팅

### 들여쓰기 및 줄바꿈

```typescript
// ✅ Good - 2 spaces
function example() {
  if (condition) {
    doSomething();
  }
}

// 긴 파라미터 목록
function createUser(
  name: string,
  email: string,
  password: string,
  options?: UserOptions
): Promise<User> {
  // ...
}

// 객체 구조분해
const {
  id,
  name,
  email,
} = user;
```

### 세미콜론

```typescript
// ✅ Good - 세미콜론 사용 (권장)
const x = 1;
const y = 2;

function example() {
  return 42;
}
```

### 따옴표

```typescript
// ✅ Good - 작은따옴표 (일관성)
const name = 'John';
const message = `Hello, ${name}`;

// Template literal (동적 문자열)
const url = `https://api.example.com/users/${userId}`;
```

## 주석

### JSDoc

```typescript
/**
 * 사용자 정보를 조회합니다.
 *
 * @param id - 사용자 ID
 * @returns 사용자 객체 또는 null
 * @throws {UserNotFoundError} 사용자를 찾을 수 없을 때
 *
 * @example
 * const user = await findUserById('123');
 */
async function findUserById(id: string): Promise<User | null> {
  // ...
}
```

### 인라인 주석

```typescript
// ✅ Good - 복잡한 로직 설명
// Fisher-Yates 알고리즘을 사용한 배열 셔플
function shuffle<T>(array: T[]): T[] {
  const result = [...array];
  for (let i = result.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [result[i], result[j]] = [result[j], result[i]];
  }
  return result;
}

// ❌ Bad - 자명한 코드에 불필요한 주석
// x를 1 증가시킴
x = x + 1;
```

## ESLint 및 Prettier 설정

### .eslintrc.json

```json
{
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended"
  ],
  "rules": {
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/explicit-function-return-type": "warn",
    "no-console": ["warn", { "allow": ["warn", "error"] }]
  }
}
```

### .prettierrc

```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100
}
```

## 관련 문서

- `java-style.md`: Java 코딩 스타일
- `git-conventions.md`: Git 커밋 메시지 규칙
- `../security/`: 보안 가이드라인
