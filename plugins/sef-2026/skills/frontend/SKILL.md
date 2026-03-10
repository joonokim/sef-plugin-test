---
name: frontend
version: 2.2.0
description: 민간/공공 공통 프론트엔드. Nuxt 4 + TypeScript 기반, 프로젝트 위치와 배포 방식만 다르며 동일한 소스 구조 유지. 파일 기반 라우팅, Pinia 상태 관리, shadcn-vue UI, API 클라이언트 패턴 제공.
tags: [nuxt4, vue3, typescript, shadcn-vue, pinia, tailwindcss, frontend, 공공, 민간]
---

# 공통 프론트엔드 (frontend)

## 개요

민간/공공 프로젝트 모두 **동일한 Nuxt 4 소스**를 사용하며, **프로젝트 위치와 배포 방식**만 다릅니다.

## Triggers

다음 상황에서 이 스킬을 사용합니다:
- 프론트엔드 페이지/컴포넌트 생성
- Nuxt 4 설정 관련 작업
- API 클라이언트 composable 작성
- Pinia 스토어 작성
- 공통 컴포넌트 패턴 적용
- 미들웨어/플러그인 작성
- TypeScript 타입 정의

## 프로젝트 타입별 차이

| 구분 | 민간 (Private) | 공공 (Public) |
|------|---------------|--------------|
| **위치** | `frontend/` (독립 프로젝트) | `frontend/` (백엔드 루트 내부) |
| **배포** | Docker 컨테이너 독립 배포 | Spring Boot WAR에 포함 |
| **빌드 출력** | `.output/` → Docker 이미지 | `../src/main/resources/static/` |
| **소스 구조** | ✅ 동일 | ✅ 동일 |
| **기술 스택** | Nuxt 4 (또는 React/Next.js 선택 가능) | Nuxt 4 고정 |

> **핵심**: 소스 코드는 동일하며, 위치와 빌드 프로세스만 다릅니다.

## 공통 기술 스택

### 필수 스택 (민간/공공 공통)

- **프레임워크**: Nuxt 4
- **언어**: TypeScript
- **UI 라이브러리**: shadcn-vue (Radix Vue + TailwindCSS 4)
- **상태 관리**: Pinia
- **폼 검증**: vee-validate + Zod
- **아이콘**: @nuxt/icon, Lucide Vue Next
- **토스트**: vue-sonner
- **유틸**: @vueuse/core, @vueuse/nuxt

### 선택 스택 (민간 전용)

민간 프로젝트는 추가로 선택 가능:
- React + Vite
- Next.js

## 공통 폴더 구조

**민간/공공 모두 동일한 flat 구조 사용** (app/ 서브디렉토리 없음):

```
frontend/
├── assets/
│   └── css/
│       └── tailwind.css          # TailwindCSS 4 설정
├── components/
│   ├── ui/                       # shadcn-vue 자동 생성 컴포넌트
│   │   ├── button/
│   │   ├── card/
│   │   ├── input/
│   │   ├── dialog/
│   │   ├── table/
│   │   └── ...
│   ├── common/                   # 공통 커스텀 컴포넌트
│   │   ├── DataTable.vue         # 범용 데이터 테이블
│   │   ├── SearchForm.vue        # 검색 폼 래퍼
│   │   ├── FormField.vue         # 폼 필드 래퍼
│   │   ├── PageHeader.vue        # 페이지 상단 헤더
│   │   ├── EmptyState.vue        # 빈 상태 표시
│   │   ├── ConfirmDialog.vue     # 확인 다이얼로그
│   │   ├── LoadingSpinner.vue    # 로딩 스피너
│   │   ├── SidebarMenu.vue       # 사이드바 메뉴
│   │   └── SidebarMenuItem.vue   # 사이드바 메뉴 아이템
│   ├── admin/                    # 관리자 전용 컴포넌트
│   │   ├── AdminHeader.vue
│   │   ├── AdminSidebar.vue
│   │   ├── AdminBreadcrumb.vue
│   │   ├── AuditReasonModal.vue
│   │   ├── MenuRolePermissionNode.vue
│   │   ├── MenuTreeNode.vue
│   │   └── StatisticsTabs.vue
│   ├── board/                    # 게시판 관련 컴포넌트
│   └── features/                 # 기능별 컴포넌트 (선택)
├── composables/                  # 조합 함수 (hooks)
│   ├── useApi.ts                 # 기본 API 클라이언트
│   ├── useAuth.ts                # 인증 관련
│   ├── useBoard.ts               # 게시판 관련
│   └── useToast.ts               # 토스트 알림
├── layouts/                      # 레이아웃 컴포넌트
│   ├── default.vue               # 기본 레이아웃 (사이드바 + 헤더)
│   ├── admin.vue                 # 관리자 레이아웃
│   └── auth.vue                  # 인증 페이지 레이아웃 (로그인 등)
├── lib/
│   └── utils.ts                  # shadcn-vue cn() 유틸 함수
├── middleware/                   # 라우트 미들웨어
│   ├── admin.global.ts           # 글로벌 미들웨어 (admin 경로 자동 적용)
│   ├── auth.ts                   # 인증 필요 페이지 보호
│   └── guest.ts                  # 비인증 사용자 전용 (로그인 페이지)
├── pages/                        # 페이지 (파일 기반 자동 라우팅)
│   ├── index.vue                 → /
│   ├── auth/
│   │   ├── login.vue             → /auth/login
│   │   └── logout.vue            → /auth/logout
│   ├── board/
│   │   ├── index.vue             → /board
│   │   ├── [id].vue              → /board/:id
│   │   └── create.vue            → /board/create
│   └── admin/
│       ├── index.vue             → /admin
│       ├── users/
│       │   ├── index.vue         → /admin/users
│       │   └── [id].vue          → /admin/users/:id
│       └── board/
│           └── index.vue         → /admin/board
├── plugins/                      # Nuxt 플러그인
│   ├── auth-refresh.client.ts    # 토큰 자동 갱신 (클라이언트 전용)
│   └── visitTracker.client.ts    # 방문자 추적 (클라이언트 전용)
├── scripts/                      # 빌드/유틸리티 스크립트
├── server/                       # 서버 미들웨어 (선택사항)
├── stores/                       # Pinia 스토어
│   ├── auth.ts
│   ├── board.ts
│   └── user.ts
├── types/                        # TypeScript 타입 정의
│   └── api/                      # API 관련 타입 (파일별 분리)
│       ├── common.ts             # 공통 타입 (PageRequest, PageResponse 등)
│       ├── auth.ts               # 인증 타입
│       ├── board.ts              # 게시판 타입
│       ├── user.ts               # 사용자 타입
│       └── index.ts              # 타입 re-export
├── utils/                        # 유틸리티 함수
│   ├── constants.ts              # 상수 정의
│   ├── formatter.ts              # 날짜/숫자 포맷터
│   └── validation.ts             # 유효성 검사 유틸
├── app.vue                       # 루트 컴포넌트
├── public/                       # 정적 파일
│   ├── favicon.ico
│   └── images/
├── .env                          # 환경변수
├── .env.example                  # 환경변수 예제
├── nuxt.config.ts                # Nuxt 설정
├── package.json
├── tsconfig.json
└── components.json               # shadcn-vue 설정
```

> **주의**: Nuxt 4는 `app/` 서브디렉토리 구조를 지원하지만, 이 프로젝트는 **flat 구조**(루트 직하)를 사용합니다.

## Nuxt 4 설정 (nuxt.config.ts)

**민간/공공 공통 기본 설정** (상세 내용은 `references/nuxt-setup.md` 참조):

```typescript
import tailwindcss from '@tailwindcss/postcss'

export default defineNuxtConfig({
  compatibilityDate: '2024-04-03',
  devtools: { enabled: true },

  // 모듈
  modules: ['@pinia/nuxt', 'shadcn-nuxt', '@vueuse/nuxt', '@nuxt/icon'],

  // shadcn-vue 설정
  shadcn: {
    prefix: '',
    componentDir: './components/ui',
  },

  // TypeScript
  typescript: {
    strict: true,
    typeCheck: false,
    shim: false,
  },

  // SPA 모드 (공공 WAR 배포 시 정적 파일 생성)
  ssr: false,

  // Nitro 서버 설정 (공공: 정적 파일을 Spring Boot static 폴더로 출력)
  nitro: {
    preset: 'static',
    output: {
      dir: '../src/main/resources/static',
      publicDir: '../src/main/resources/static',
    },
  },

  app: {
    baseURL: '/gbadm/',  // 해당 프로젝트 코드 
  },

  // CSS (TailwindCSS 4 방식)
  css: ['~/assets/css/tailwind.css'],

  // 컴포넌트 자동 import
  components: [
    { path: '~/components', pathPrefix: false, extensions: ['.vue'] },
  ],

  // 환경변수
  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || '',
    },
  },

  // 개발 환경 프록시 (GET, POST만 사용)
  vite: {
    server: {
      proxy: {
        '/api': { target: 'http://localhost:7171', changeOrigin: true },
        '^/adm/': { target: 'http://localhost:7171', changeOrigin: true },
      },
    },
    css: {
      postcss: { plugins: [tailwindcss] },
    },
  },
})
```

## API 클라이언트 패턴

> **중요**: 공공 네트워크 정책상 **GET과 POST만 허용**됩니다. PUT/DELETE 사용 금지.
> - 수정: `POST /api/v1/{resource}/{id}/update`
> - 삭제: `POST /api/v1/{resource}/{id}/delete`

### 기본 API 클라이언트 (useApi.ts)

```typescript
// composables/useApi.ts
export const useApi = () => {
  const config = useRuntimeConfig()
  const baseURL = config.public.apiBase

  const apiFetch = async <T>(
    endpoint: string,
    options?: RequestInit & { params?: Record<string, any> }
  ): Promise<T> => {
    const token = useCookie('auth-token')
    const { params, ...fetchOptions } = options || {}

    const url = params
      ? `${endpoint}?${new URLSearchParams(params)}`
      : endpoint

    try {
      return await $fetch<T>(`${baseURL}${url}`, {
        ...fetchOptions,
        headers: {
          'Content-Type': 'application/json',
          ...(token.value && { Authorization: `Bearer ${token.value}` }),
          ...fetchOptions?.headers,
        },
      })
    } catch (error: any) {
      if (error.response?.status === 401) {
        token.value = null
        navigateTo('/auth/login')
      }
      throw error
    }
  }

  return { apiFetch }
}
```

### 기능별 Composable (POST-only 패턴)

```typescript
// composables/useBoard.ts
import type { Board, BoardCreateRequest, BoardUpdateRequest } from '@/types/api'
import type { PageResponse } from '@/types/api/common'

export const useBoard = () => {
  const { apiFetch } = useApi()

  const getBoards = async (page = 1, size = 10) => {
    return await apiFetch<PageResponse<Board>>('/api/v1/boards', {
      params: { currentPage: page, pageSize: size },
    })
  }

  const getBoard = async (id: number) => {
    return await apiFetch<Board>(`/api/v1/boards/${id}`)
  }

  const createBoard = async (data: BoardCreateRequest) => {
    return await apiFetch<Board>('/api/v1/boards', {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  // ✅ PUT 대신 POST /{id}/update 사용 (공공 네트워크 정책)
  const updateBoard = async (id: number, data: BoardUpdateRequest) => {
    return await apiFetch<Board>(`/api/v1/boards/${id}/update`, {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  // ✅ DELETE 대신 POST /{id}/delete 사용 (공공 네트워크 정책)
  const deleteBoard = async (id: number) => {
    return await apiFetch<void>(`/api/v1/boards/${id}/delete`, {
      method: 'POST',
    })
  }

  return { getBoards, getBoard, createBoard, updateBoard, deleteBoard }
}
```

## 상태 관리 (Pinia)

**민간/공공 동일 코드**:

```typescript
// stores/auth.ts
import { defineStore } from 'pinia'
import type { User } from '@/types/api/auth'

export const useAuthStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const token = useCookie('auth-token')

  const setAuth = (newToken: string, newUser: User) => {
    token.value = newToken
    user.value = newUser
  }

  const clearAuth = () => {
    token.value = null
    user.value = null
  }

  const login = async (credentials: LoginRequest) => {
    const { apiFetch } = useApi()
    const response = await apiFetch<{ token: string; user: User }>('/api/v1/auth/login', {
      method: 'POST',
      body: JSON.stringify(credentials),
    })
    setAuth(response.token, response.user)
  }

  const logout = async () => {
    const { apiFetch } = useApi()
    await apiFetch('/api/v1/auth/logout', { method: 'POST' })
    clearAuth()
    navigateTo('/auth/login')
  }

  const isAuthenticated = computed(() => !!token.value)

  return { user, token, login, logout, setAuth, clearAuth, isAuthenticated }
})
```

## 파일 기반 라우팅

Nuxt 4는 `pages/` 디렉토리 구조로 자동 라우팅:

```
pages/
├── index.vue                 → /
├── auth/
│   ├── login.vue             → /auth/login
│   └── logout.vue            → /auth/logout
├── board/
│   ├── index.vue             → /board
│   ├── [id].vue              → /board/:id
│   └── create.vue            → /board/create
└── admin/
    ├── index.vue             → /admin
    └── users/
        ├── index.vue         → /admin/users
        └── [id].vue          → /admin/users/:id
```

### 동적 라우트 예시

```vue
<!-- pages/board/[id].vue -->
<script setup lang="ts">
const route = useRoute()
const id = computed(() => Number(route.params.id))

const { getBoard } = useBoard()
const { data: board, pending } = await useAsyncData(
  `board-${id.value}`,
  () => getBoard(id.value)
)
</script>

<template>
  <div v-if="pending"><LoadingSpinner /></div>
  <div v-else-if="board">
    <PageHeader :title="board.title" />
    <p>{{ board.content }}</p>
  </div>
  <EmptyState v-else message="게시글을 찾을 수 없습니다." />
</template>
```

## 레이아웃

레이아웃은 `layouts/` 디렉토리에 3종 존재합니다:

| 파일 | 용도 | 적용 대상 |
|------|------|---------|
| `default.vue` | 기본 레이아웃 (사이드바 + 헤더) | 일반 페이지 |
| `admin.vue` | 관리자 레이아웃 | `/admin/**` 경로 |
| `auth.vue` | 인증 레이아웃 (로그인/로그아웃) | `/auth/**` 경로 |

레이아웃 자동 설정은 `nuxt.config.ts`의 `hooks.pages:extend`로 처리:

```typescript
hooks: {
  'pages:extend'(pages) {
    pages.forEach((page) => {
      if (page.path.startsWith('/auth')) {
        page.meta ||= {}
        page.meta.layout = 'auth'
      }
    })
  },
},
```

## 미들웨어

```
middleware/
├── admin.global.ts   # 글로벌 미들웨어: /admin 경로 → 관리자 권한 검증 자동 적용
├── auth.ts           # 인증 필요 페이지 보호 (definePageMeta로 수동 적용)
└── guest.ts          # 비인증 사용자 전용 페이지 (로그인 페이지 등)
```

```typescript
// middleware/auth.ts
export default defineNuxtRouteMiddleware(() => {
  const authStore = useAuthStore()
  if (!authStore.isAuthenticated) {
    return navigateTo('/auth/login')
  }
})

// 사용 예시 (페이지에서)
definePageMeta({ middleware: 'auth' })
```

```typescript
// middleware/admin.global.ts — 글로벌 미들웨어 (자동 적용)
export default defineNuxtRouteMiddleware((to) => {
  if (to.path.startsWith('/admin')) {
    const authStore = useAuthStore()
    if (!authStore.isAuthenticated) {
      return navigateTo('/auth/login')
    }
    // 관리자 권한 추가 검증 가능
  }
})
```

## 플러그인

```
plugins/
├── auth-refresh.client.ts    # 앱 시작 시 토큰 유효성 확인 및 자동 갱신
└── visitTracker.client.ts    # 페이지 방문 기록 추적
```

```typescript
// plugins/auth-refresh.client.ts
export default defineNuxtPlugin(async () => {
  const authStore = useAuthStore()
  const token = useCookie('auth-token')

  if (token.value) {
    try {
      // 토큰 유효성 확인
      const { apiFetch } = useApi()
      const user = await apiFetch<User>('/api/v1/auth/me')
      authStore.setAuth(token.value, user)
    } catch {
      authStore.clearAuth()
    }
  }
})
```

## 공통 컴포넌트 (components/common/)

자주 사용되는 공통 컴포넌트 목록 (상세 패턴은 `references/common-components.md` 참조):

| 컴포넌트 | 설명 | 주요 Props |
|---------|------|-----------|
| `DataTable.vue` | 제네릭 데이터 테이블 | `data`, `columns`, `loading`, `pagination` |
| `SearchForm.vue` | 슬롯 기반 검색 폼 | `@search`, `@reset` 이벤트 |
| `FormField.vue` | 레이블+입력+에러 래퍼 | `label`, `name`, `required` |
| `PageHeader.vue` | 페이지 상단 헤더 | `title`, `description`, `actions` 슬롯 |
| `EmptyState.vue` | 빈 상태 표시 | `message`, `icon` |
| `ConfirmDialog.vue` | 확인/취소 다이얼로그 | `title`, `description`, `@confirm` |
| `LoadingSpinner.vue` | 로딩 스피너 | `size`, `class` |

### DataTable 사용 예시

```vue
<script setup lang="ts">
const { getBoards } = useBoard()
const { data, pending } = await useAsyncData('boards', () => getBoards())
</script>

<template>
  <DataTable
    :data="data?.resultList ?? []"
    :loading="pending"
    :pagination="{
      currentPage: data?.currentPage ?? 1,
      totalCnt: data?.totalCnt ?? 0,
      pageSize: data?.pageSize ?? 10,
    }"
    @page-change="handlePageChange"
  />
</template>
```

## TypeScript 타입 구조

타입은 `types/api/` 하위에 도메인별로 분리합니다 (상세는 `references/types-structure.md` 참조):

```
types/
└── api/
    ├── common.ts      # PageRequest, PageResponse, ApiResponse
    ├── auth.ts        # User, LoginRequest, LoginResponse
    ├── board.ts       # Board, BoardCreateRequest, BoardUpdateRequest
    ├── user.ts        # UserDetail, UserUpdateRequest
    └── index.ts       # 전체 re-export
```

```typescript
// types/api/common.ts
export interface PageResponse<T> {
  totalCnt: number
  pageSize: number
  currentPage: number
  resultList: T[]
}

export interface PageRequest {
  currentPage: number
  pageSize: number
}
```

## 유틸리티 (utils/)

```typescript
// utils/formatter.ts
export const formatDate = (date: string | Date, format = 'YYYY-MM-DD') => {
  // 날짜 포맷 변환
}

export const formatNumber = (num: number) => {
  return num.toLocaleString('ko-KR')
}
```

```typescript
// utils/constants.ts
export const PAGE_SIZE = 10
export const MAX_FILE_SIZE = 10 * 1024 * 1024  // 10MB
```

```typescript
// lib/utils.ts — shadcn-vue cn() 함수
import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

## 컴포넌트 예시

### 폼 컴포넌트

```vue
<!-- components/features/auth/LoginForm.vue -->
<script setup lang="ts">
import { useForm } from 'vee-validate'
import { toTypedSchema } from '@vee-validate/zod'
import { z } from 'zod'
import { toast } from 'vue-sonner'

const authStore = useAuthStore()

const formSchema = toTypedSchema(
  z.object({
    username: z.string().min(1, '아이디를 입력하세요'),
    password: z.string().min(1, '비밀번호를 입력하세요'),
  })
)

const { handleSubmit, isSubmitting } = useForm({ validationSchema: formSchema })

const onSubmit = handleSubmit(async (values) => {
  try {
    await authStore.login(values)
    toast.success('로그인 성공')
    navigateTo('/')
  } catch (error: any) {
    toast.error('로그인 실패', { description: error.message })
  }
})
</script>

<template>
  <form @submit="onSubmit" class="space-y-6">
    <FormField label="아이디" name="username" required />
    <FormField label="비밀번호" name="password" type="password" required />
    <Button type="submit" :disabled="isSubmitting" class="w-full">
      로그인
    </Button>
  </form>
</template>
```

### 관리자 컴포넌트 사용 예시

```vue
<!-- pages/admin/board/index.vue -->
<script setup lang="ts">
definePageMeta({ layout: 'admin' })

const { getBoards } = useBoard()
const page = ref(1)
const { data, pending, refresh } = await useAsyncData(
  'admin-boards',
  () => getBoards(page.value)
)
</script>

<template>
  <div>
    <PageHeader title="게시글 관리">
      <template #actions>
        <Button @click="navigateTo('/admin/board/create')">등록</Button>
      </template>
    </PageHeader>

    <SearchForm @search="refresh" @reset="page = 1; refresh()">
      <!-- 검색 필드 슬롯 -->
    </SearchForm>

    <DataTable :data="data?.resultList ?? []" :loading="pending" />
  </div>
</template>
```

## 빌드 및 배포

### 민간 프로젝트 (Docker)

```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
RUN corepack enable && corepack prepare pnpm@latest --activate
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/.output ./
EXPOSE 3000
ENV NUXT_HOST=0.0.0.0
ENV NUXT_PORT=3000
CMD ["node", "server/index.mjs"]
```

### 공공 프로젝트 (WAR 포함)

**빌드 스크립트** (`build-frontend.sh`):

```bash
#!/bin/bash
set -e

echo "=== Nuxt 프론트엔드 빌드 시작 ==="
cd frontend

# 의존성 설치
pnpm install --frozen-lockfile

# 프로덕션 빌드 (정적 파일을 ../src/main/resources/static/ 으로 출력)
pnpm build

echo "=== 프론트엔드 빌드 완료 ==="
```

**전체 빌드** (nuxt.config.ts의 nitro.output 설정으로 자동 복사):

```bash
# 프론트엔드 빌드 (static 폴더로 자동 출력)
cd frontend && pnpm build

# Spring Boot WAR 패키징
./gradlew clean bootWar

# 결과: build/libs/app.war (프론트엔드 포함)
```

## 개발 워크플로우

### 로컬 개발

**공공**:
```bash
# 프론트엔드 (frontend/ 디렉토리에서)
cd frontend
pnpm dev  # http://localhost:3000

# 백엔드 (별도 터미널, 프로젝트 루트에서)
./gradlew bootRun  # http://localhost:7171
```

**민간**:
```bash
cd frontend
pnpm dev  # http://localhost:3000
```

### 주요 스크립트

```bash
pnpm dev          # 개발 서버
pnpm build        # 프로덕션 빌드
pnpm generate     # 정적 파일 생성
pnpm typecheck    # TypeScript 타입 검사
pnpm lint         # ESLint 검사
pnpm lint:fix     # ESLint 자동 수정
pnpm format       # Prettier 포맷
```

## 참고 자료

- `references/nuxt-setup.md`: Nuxt 4 프로젝트 초기 설정 (의존성, nuxt.config.ts 상세)
- `references/api-client.md`: API 클라이언트 패턴 (GET/POST-only 규칙)
- `references/state-management.md`: Pinia 상태 관리
- `references/routing.md`: 파일 기반 라우팅 가이드
- `references/common-components.md`: 공통 컴포넌트 패턴 (DataTable, SearchForm 등)
- `references/types-structure.md`: TypeScript 타입 정의 구조
- `references/deployment-private.md`: 민간 Docker 배포
- `references/deployment-public.md`: 공공 WAR 배포

## 관련 스킬

### 공통 (sef-2026 플러그인)
- `sef-2026:tech-stack`: 기술 스택 선택 가이드
- `sef-2026:frontend-init`: 프론트엔드 초기 구조 생성 (package.json, nuxt.config.ts, 기본 파일 scaffolding)
- `sef-2026:page-generator`: 목록/상세/폼 페이지 생성
- `sef-2026:module-generator`: types + composable + store 도메인 모듈 세트 생성

### 민간 (sef-2026-private 플러그인)
- `sef-2026-private:project-init`: 민간 프로젝트 초기화
- `sef-2026-private:backend`: 민간 백엔드 (Spring Boot + JPA)
- `sef-2026-private:deployment`: 민간 배포 (Docker, Kubernetes)

### 공공 (sef-2026-public 플러그인)
- `sef-2026-public:project-init`: 공공 프로젝트 초기화
- `sef-2026-public:backend`: 공공 백엔드 (Spring Boot + MyBatis)
- `sef-2026-public:deployment`: 공공 배포 (WAR, JEUS/WebLogic)
