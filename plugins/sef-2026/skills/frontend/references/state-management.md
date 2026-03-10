# 프론트엔드 상태 관리 패턴 비교

민간 섹터 프로젝트에서 사용하는 주요 상태 관리 라이브러리의 비교 및 사용 가이드입니다.

## 개요

프론트엔드 프레임워크별 주요 상태 관리 솔루션:

- **Vue/Nuxt**: Pinia (권장), Vuex (레거시)
- **React/Next.js**: Zustand (권장), Redux, Jotai, Recoil
- **공통**: Context API, Composables/Hooks

## Pinia (Vue/Nuxt)

### 특징

- Vue 3 공식 상태 관리 라이브러리
- TypeScript 완벽 지원
- 직관적인 API
- Devtools 지원
- Composition API 스타일
- 모듈별 자동 코드 스플리팅

### 설치

```bash
# Nuxt
pnpm add @pinia/nuxt

# Vue
pnpm add pinia
```

### 기본 사용법

#### stores/auth.ts

```typescript
import { defineStore } from 'pinia'
import type { User, LoginRequest } from '@/types/auth'

export const useAuthStore = defineStore('auth', () => {
  // State
  const user = ref<User | null>(null)
  const token = useCookie('auth-token', {
    maxAge: 60 * 60 * 24 * 7, // 7일
  })
  const loading = ref(false)

  // Getters (Computed)
  const isAuthenticated = computed(() => !!token.value)
  const isAdmin = computed(() => user.value?.role === 'ADMIN')

  // Actions
  const login = async (credentials: LoginRequest) => {
    loading.value = true
    try {
      const { apiFetch } = useApi()
      const response = await apiFetch<{ token: string; user: User }>(
        '/auth/login',
        {
          method: 'POST',
          body: JSON.stringify(credentials),
        }
      )

      token.value = response.token
      user.value = response.user
    } finally {
      loading.value = false
    }
  }

  const logout = async () => {
    const { apiFetch } = useApi()
    await apiFetch('/auth/logout', { method: 'POST' })
    token.value = null
    user.value = null
    navigateTo('/login')
  }

  const fetchUser = async () => {
    if (!token.value) return

    const { apiFetch } = useApi()
    user.value = await apiFetch<User>('/auth/me')
  }

  return {
    // State
    user,
    token,
    loading,
    // Getters
    isAuthenticated,
    isAdmin,
    // Actions
    login,
    logout,
    fetchUser,
  }
})
```

#### 컴포넌트에서 사용

```vue
<template>
  <div>
    <div v-if="authStore.isAuthenticated">
      <p>Welcome, {{ authStore.user?.username }}!</p>
      <UButton @click="authStore.logout">Logout</UButton>
    </div>
    <div v-else>
      <UButton to="/login">Login</UButton>
    </div>
  </div>
</template>

<script setup lang="ts">
const authStore = useAuthStore()

// 초기화
onMounted(() => {
  authStore.fetchUser()
})
</script>
```

### 고급 패턴

#### 1. 다른 스토어 사용하기

```typescript
export const useBoardStore = defineStore('board', () => {
  const authStore = useAuthStore() // 다른 스토어 사용

  const createBoard = async (data: BoardCreateRequest) => {
    if (!authStore.isAuthenticated) {
      throw new Error('Unauthorized')
    }
    // ...
  }

  return { createBoard }
})
```

#### 2. 플러그인으로 초기화

```typescript
// plugins/pinia.ts
export default defineNuxtPlugin(({ $pinia }) => {
  return {
    provide: {
      store: () => {
        const authStore = useAuthStore($pinia)
        authStore.fetchUser()
      },
    },
  }
})
```

#### 3. 영속성 (Persistence)

```typescript
import { defineStore } from 'pinia'

export const useSettingsStore = defineStore('settings', () => {
  const theme = useLocalStorage('theme', 'light')
  const language = useLocalStorage('language', 'en')

  const setTheme = (newTheme: string) => {
    theme.value = newTheme
  }

  return { theme, language, setTheme }
})
```

## Zustand (React/Next.js)

### 특징

- 간단하고 가벼움 (1KB)
- Flux 패턴 기반
- React 18 지원
- 미들웨어 지원
- TypeScript 지원

### 설치

```bash
pnpm add zustand
```

### 기본 사용법

#### stores/authStore.ts

```typescript
import { create } from 'zustand'
import { authService } from '@/services/authService'
import type { User, LoginRequest } from '@/types/auth'

interface AuthState {
  user: User | null
  token: string | null
  loading: boolean
  isAuthenticated: boolean
  login: (credentials: LoginRequest) => Promise<void>
  logout: () => Promise<void>
  fetchUser: () => Promise<void>
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  token: localStorage.getItem('auth-token'),
  loading: false,
  isAuthenticated: !!localStorage.getItem('auth-token'),

  login: async (credentials) => {
    set({ loading: true })
    try {
      const response = await authService.login(credentials)
      localStorage.setItem('auth-token', response.token)
      set({
        token: response.token,
        user: response.user,
        isAuthenticated: true,
      })
    } finally {
      set({ loading: false })
    }
  },

  logout: async () => {
    await authService.logout()
    localStorage.removeItem('auth-token')
    set({
      token: null,
      user: null,
      isAuthenticated: false,
    })
  },

  fetchUser: async () => {
    if (!get().token) return

    try {
      const user = await authService.getCurrentUser()
      set({ user })
    } catch (error) {
      // 토큰이 유효하지 않으면 로그아웃
      get().logout()
    }
  },
}))
```

#### 컴포넌트에서 사용

```typescript
'use client'

import { useAuthStore } from '@/stores/authStore'

export default function Header() {
  // 전체 스토어 구독
  const authStore = useAuthStore()

  // 또는 특정 값만 구독 (최적화)
  const { user, isAuthenticated, logout } = useAuthStore((state) => ({
    user: state.user,
    isAuthenticated: state.isAuthenticated,
    logout: state.logout,
  }))

  return (
    <header>
      {isAuthenticated ? (
        <>
          <span>Welcome, {user?.username}!</span>
          <button onClick={logout}>Logout</button>
        </>
      ) : (
        <a href="/login">Login</a>
      )}
    </header>
  )
}
```

### 고급 패턴

#### 1. 미들웨어 사용 (Devtools, Persist)

```typescript
import { create } from 'zustand'
import { devtools, persist } from 'zustand/middleware'

interface SettingsState {
  theme: 'light' | 'dark'
  language: string
  setTheme: (theme: 'light' | 'dark') => void
  setLanguage: (language: string) => void
}

export const useSettingsStore = create<SettingsState>()(
  devtools(
    persist(
      (set) => ({
        theme: 'light',
        language: 'en',
        setTheme: (theme) => set({ theme }),
        setLanguage: (language) => set({ language }),
      }),
      {
        name: 'settings-storage',
      }
    )
  )
)
```

#### 2. Slice 패턴 (큰 스토어 분리)

```typescript
// stores/slices/authSlice.ts
import type { StateCreator } from 'zustand'

export interface AuthSlice {
  user: User | null
  token: string | null
  login: (credentials: LoginRequest) => Promise<void>
  logout: () => void
}

export const createAuthSlice: StateCreator<AuthSlice> = (set) => ({
  user: null,
  token: null,
  login: async (credentials) => {
    // ...
  },
  logout: () => {
    // ...
  },
})

// stores/slices/boardSlice.ts
export interface BoardSlice {
  boards: Board[]
  fetchBoards: () => Promise<void>
}

export const createBoardSlice: StateCreator<BoardSlice> = (set) => ({
  boards: [],
  fetchBoards: async () => {
    // ...
  },
})

// stores/index.ts
import { create } from 'zustand'
import { createAuthSlice, AuthSlice } from './slices/authSlice'
import { createBoardSlice, BoardSlice } from './slices/boardSlice'

type StoreState = AuthSlice & BoardSlice

export const useStore = create<StoreState>()((...a) => ({
  ...createAuthSlice(...a),
  ...createBoardSlice(...a),
}))
```

#### 3. 셀렉터 패턴 (리렌더링 최적화)

```typescript
// stores/selectors/authSelectors.ts
import { useAuthStore } from '@/stores/authStore'

export const useIsAuthenticated = () =>
  useAuthStore((state) => state.isAuthenticated)

export const useUser = () =>
  useAuthStore((state) => state.user)

export const useLogin = () =>
  useAuthStore((state) => state.login)

// 컴포넌트에서 사용
import { useIsAuthenticated, useUser } from '@/stores/selectors/authSelectors'

function Component() {
  const isAuthenticated = useIsAuthenticated()
  const user = useUser()
  // ...
}
```

## Redux Toolkit (React/Next.js)

### 특징

- Redux의 공식 도구 모음
- 보일러플레이트 감소
- Immer 내장 (불변성 자동 관리)
- Redux DevTools 지원
- RTK Query (데이터 페칭)

### 설치

```bash
pnpm add @reduxjs/toolkit react-redux
```

### 기본 사용법

#### stores/authSlice.ts

```typescript
import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit'
import { authService } from '@/services/authService'
import type { User, LoginRequest } from '@/types/auth'

interface AuthState {
  user: User | null
  token: string | null
  loading: boolean
  error: string | null
}

const initialState: AuthState = {
  user: null,
  token: localStorage.getItem('auth-token'),
  loading: false,
  error: null,
}

// Async Thunks
export const login = createAsyncThunk(
  'auth/login',
  async (credentials: LoginRequest) => {
    const response = await authService.login(credentials)
    localStorage.setItem('auth-token', response.token)
    return response
  }
)

export const logout = createAsyncThunk('auth/logout', async () => {
  await authService.logout()
  localStorage.removeItem('auth-token')
})

// Slice
const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    clearError: (state) => {
      state.error = null
    },
  },
  extraReducers: (builder) => {
    builder
      // Login
      .addCase(login.pending, (state) => {
        state.loading = true
        state.error = null
      })
      .addCase(login.fulfilled, (state, action) => {
        state.loading = false
        state.token = action.payload.token
        state.user = action.payload.user
      })
      .addCase(login.rejected, (state, action) => {
        state.loading = false
        state.error = action.error.message || 'Login failed'
      })
      // Logout
      .addCase(logout.fulfilled, (state) => {
        state.token = null
        state.user = null
      })
  },
})

export const { clearError } = authSlice.actions
export default authSlice.reducer
```

#### stores/index.ts

```typescript
import { configureStore } from '@reduxjs/toolkit'
import authReducer from './authSlice'
import boardReducer from './boardSlice'

export const store = configureStore({
  reducer: {
    auth: authReducer,
    board: boardReducer,
  },
})

export type RootState = ReturnType<typeof store.getState>
export type AppDispatch = typeof store.dispatch
```

#### 컴포넌트에서 사용

```typescript
'use client'

import { useDispatch, useSelector } from 'react-redux'
import { login, logout } from '@/stores/authSlice'
import type { RootState, AppDispatch } from '@/stores'

export default function LoginForm() {
  const dispatch = useDispatch<AppDispatch>()
  const { user, loading, error } = useSelector((state: RootState) => state.auth)

  const handleLogin = async (credentials: LoginRequest) => {
    await dispatch(login(credentials)).unwrap()
  }

  return (
    <form onSubmit={handleLogin}>
      {/* ... */}
    </form>
  )
}
```

## 상태 관리 비교표

| 특징 | Pinia | Zustand | Redux Toolkit |
|------|-------|---------|---------------|
| 번들 크기 | ~2KB | ~1KB | ~10KB |
| 학습 곡선 | 낮음 | 낮음 | 중간 |
| TypeScript | 완벽 | 좋음 | 완벽 |
| Devtools | ✅ | ✅ (미들웨어) | ✅ |
| 미들웨어 | ✅ | ✅ | ✅ |
| 영속성 | 수동 | 미들웨어 | 미들웨어 |
| SSR 지원 | ✅ | ⚠️ | ⚠️ |
| 코드 스플리팅 | 자동 | 수동 | 수동 |
| 생태계 | Vue | React | React |

## 선택 가이드

### Pinia를 선택하는 경우

- Vue 3 / Nuxt 4 프로젝트
- TypeScript 프로젝트
- 간단하고 직관적인 API 선호
- Composition API 스타일 선호

### Zustand를 선택하는 경우

- React / Next.js 프로젝트
- 작고 빠른 라이브러리 선호
- 간단한 상태 관리 필요
- Redux의 복잡함을 피하고 싶은 경우

### Redux Toolkit을 선택하는 경우

- 복잡한 상태 로직
- 큰 팀 프로젝트
- Redux 생태계 활용 필요
- 강력한 미들웨어 필요

## 모범 사례

### 1. 상태를 최소화하라

```typescript
// ❌ 나쁜 예 - 파생 상태를 저장
const authStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const isAuthenticated = ref(false) // 불필요!

  return { user, isAuthenticated }
})

// ✅ 좋은 예 - computed로 파생
const authStore = defineStore('auth', () => {
  const user = ref<User | null>(null)
  const isAuthenticated = computed(() => !!user.value)

  return { user, isAuthenticated }
})
```

### 2. 액션을 순수하게 유지하라

```typescript
// ❌ 나쁜 예 - 사이드 이펙트가 많음
const login = async (credentials: LoginRequest) => {
  const response = await apiFetch('/auth/login', { body: credentials })
  token.value = response.token
  user.value = response.user
  router.push('/dashboard') // 라우팅은 컴포넌트에서!
  showNotification('Login successful') // 알림도 컴포넌트에서!
}

// ✅ 좋은 예 - 순수한 상태 업데이트
const login = async (credentials: LoginRequest) => {
  const response = await apiFetch('/auth/login', { body: credentials })
  token.value = response.token
  user.value = response.user
  return response
}
```

### 3. 네임스페이스를 명확히 하라

```typescript
// ✅ 좋은 예
const useAuthStore = defineStore('auth', () => { /* ... */ })
const useBoardStore = defineStore('board', () => { /* ... */ })
const useUserStore = defineStore('user', () => { /* ... */ })
```

### 4. 로딩 및 에러 상태를 관리하라

```typescript
const useBoardStore = defineStore('board', () => {
  const boards = ref<Board[]>([])
  const loading = ref(false)
  const error = ref<string | null>(null)

  const fetchBoards = async () => {
    loading.value = true
    error.value = null
    try {
      const response = await apiFetch('/boards')
      boards.value = response.content
    } catch (err) {
      error.value = err.message
    } finally {
      loading.value = false
    }
  }

  return { boards, loading, error, fetchBoards }
})
```

## 참고 자료

- [Pinia 공식 문서](https://pinia.vuejs.org/)
- [Zustand 공식 문서](https://github.com/pmndrs/zustand)
- [Redux Toolkit 공식 문서](https://redux-toolkit.js.org/)
