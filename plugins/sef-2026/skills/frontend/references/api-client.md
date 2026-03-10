# API 클라이언트 패턴

## 개요

민간/공공 프로젝트 모두 **동일한 API 클라이언트 패턴**을 사용합니다. composable 패턴으로 API 호출을 표준화합니다.

## 기본 API 클라이언트 (useApi)

### composables/useApi.ts

```typescript
export const useApi = () => {
  const config = useRuntimeConfig()
  const baseURL = config.public.apiBase

  const apiFetch = async <T>(
    endpoint: string,
    options?: RequestInit & { params?: Record<string, any> }
  ): Promise<T> => {
    const token = useCookie('auth-token')
    const { params, ...fetchOptions } = options || {}

    // URL 파라미터 생성
    const url = params
      ? `${endpoint}?${new URLSearchParams(params)}`
      : endpoint

    try {
      const response = await $fetch<T>(`${baseURL}${url}`, {
        ...fetchOptions,
        headers: {
          'Content-Type': 'application/json',
          ...(token.value && { Authorization: `Bearer ${token.value}` }),
          ...fetchOptions?.headers,
        },
      })

      return response
    } catch (error: any) {
      // 에러 처리
      if (error.response?.status === 401) {
        // 인증 만료 시 로그인 페이지로
        token.value = null
        navigateTo('/login')
      }
      throw error
    }
  }

  return { apiFetch }
}
```

## 기능별 API Composable

### composables/useBoard.ts

```typescript
import type { Board, BoardCreateRequest, BoardUpdateRequest, PageResponse } from '@/types/api'

export const useBoard = () => {
  const { apiFetch } = useApi()

  const getBoards = async (page = 1, size = 10) => {
    return await apiFetch<PageResponse<Board>>('/boards', {
      params: { currentPage: page, pageSize: size },
    })
  }

  const getBoard = async (id: number) => {
    return await apiFetch<Board>(`/boards/${id}`)
  }

  const createBoard = async (data: BoardCreateRequest) => {
    return await apiFetch<Board>('/boards', {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  // 공공 프로젝트: PUT 대신 POST /{id}/update 사용 (정부 네트워크 방화벽 제약)
  const updateBoard = async (id: number, data: BoardUpdateRequest) => {
    return await apiFetch<Board>(`/boards/${id}/update`, {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  // 공공 프로젝트: DELETE 대신 POST /{id}/delete 사용 (정부 네트워크 방화벽 제약)
  const deleteBoard = async (id: number) => {
    return await apiFetch<void>(`/boards/${id}/delete`, {
      method: 'POST',
    })
  }

  return {
    getBoards,
    getBoard,
    createBoard,
    updateBoard,
    deleteBoard,
  }
}
```

### composables/useAuth.ts

```typescript
import type { LoginRequest, RegisterRequest, User } from '@/types/auth'

export const useAuth = () => {
  const { apiFetch } = useApi()
  const authStore = useAuthStore()

  const login = async (credentials: LoginRequest) => {
    const response = await apiFetch<{ token: string; user: User }>(
      '/auth/login',
      {
        method: 'POST',
        body: JSON.stringify(credentials),
      }
    )

    authStore.setAuth(response.token, response.user)
    return response
  }

  const register = async (data: RegisterRequest) => {
    return await apiFetch<User>('/auth/register', {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  const logout = async () => {
    await apiFetch('/auth/logout', { method: 'POST' })
    authStore.clearAuth()
    navigateTo('/login')
  }

  const getCurrentUser = async () => {
    return await apiFetch<User>('/auth/me')
  }

  return {
    login,
    register,
    logout,
    getCurrentUser,
  }
}
```

## TypeScript 타입 정의

### types/api.ts

```typescript
export interface PageResponse<T> {
  totalCnt: number
  pageSize: number
  currentPage: number
  resultList: T[]
}

export interface ApiError {
  status: number
  message: string
  code?: string
}

export interface Board {
  id: number
  title: string
  content: string
  author: string
  createdAt: string
  updatedAt: string
  status: 'published' | 'draft'
}

export interface BoardCreateRequest {
  title: string
  content: string
}

export interface BoardUpdateRequest {
  title: string
  content: string
  status?: 'published' | 'draft'
}
```

### types/auth.ts

```typescript
export interface User {
  id: number
  email: string
  username: string
  role: 'admin' | 'user'
}

export interface LoginRequest {
  username: string
  password: string
}

export interface RegisterRequest {
  email: string
  username: string
  password: string
  passwordConfirm: string
}

export interface LoginResponse {
  token: string
  user: User
}
```

## 페이지에서 사용

### useAsyncData 패턴 (권장)

```vue
<script setup lang="ts">
const route = useRoute()
const id = computed(() => Number(route.params.id))

const { getBoard } = useBoard()

// SSR 지원, 자동 캐싱
const { data: board, pending, error, refresh } = await useAsyncData(
  `board-${id.value}`,
  () => getBoard(id.value)
)
</script>

<template>
  <div v-if="pending">로딩 중...</div>
  <div v-else-if="error">에러 발생: {{ error.message }}</div>
  <div v-else-if="board">
    <h1>{{ board.title }}</h1>
    <p>{{ board.content }}</p>
  </div>
</template>
```

### 직접 호출 패턴

```vue
<script setup lang="ts">
import { toast } from 'vue-sonner'

const { createBoard } = useBoard()
const loading = ref(false)

const handleSubmit = async (data: BoardCreateRequest) => {
  loading.value = true
  try {
    const board = await createBoard(data)
    toast.success('게시글 생성 성공')
    navigateTo(`/boards/${board.id}`)
  } catch (error: any) {
    toast.error('게시글 생성 실패', {
      description: error.message
    })
  } finally {
    loading.value = false
  }
}
</script>
```

## 에러 처리

### 글로벌 에러 핸들러

```typescript
// composables/useApi.ts
const handleError = (error: any) => {
  const { toast } = useToast()

  if (error.response?.status === 401) {
    // 인증 에러
    token.value = null
    navigateTo('/login')
    toast.error('인증이 만료되었습니다', {
      description: '다시 로그인해주세요'
    })
  } else if (error.response?.status === 403) {
    // 권한 에러
    toast.error('권한이 없습니다')
  } else if (error.response?.status >= 500) {
    // 서버 에러
    toast.error('서버 오류가 발생했습니다', {
      description: '잠시 후 다시 시도해주세요'
    })
  } else {
    // 기타 에러
    toast.error('오류가 발생했습니다', {
      description: error.message
    })
  }

  throw error
}
```

## 파일 업로드

### composables/useFileUpload.ts

```typescript
export const useFileUpload = () => {
  const { apiFetch } = useApi()

  const uploadFile = async (file: File) => {
    const formData = new FormData()
    formData.append('file', file)

    const token = useCookie('auth-token')

    return await $fetch<{ url: string }>('/upload', {
      method: 'POST',
      body: formData,
      headers: {
        ...(token.value && { Authorization: `Bearer ${token.value}` }),
      },
    })
  }

  const uploadMultiple = async (files: File[]) => {
    const formData = new FormData()
    files.forEach((file) => {
      formData.append('files', file)
    })

    const token = useCookie('auth-token')

    return await $fetch<{ urls: string[] }>('/upload/multiple', {
      method: 'POST',
      body: formData,
      headers: {
        ...(token.value && { Authorization: `Bearer ${token.value}` }),
      },
    })
  }

  return { uploadFile, uploadMultiple }
}
```

## 요청 취소

### AbortController 사용

```typescript
export const useBoard = () => {
  const { apiFetch } = useApi()
  const abortController = ref<AbortController | null>(null)

  const getBoards = async (page = 0, size = 10) => {
    // 이전 요청 취소
    if (abortController.value) {
      abortController.value.abort()
    }

    abortController.value = new AbortController()

    return await apiFetch<PageResponse<Board>>('/boards', {
      params: { page, size },
      signal: abortController.value.signal,
    })
  }

  return { getBoards }
}
```

## 베스트 프랙티스

1. **Composable 패턴**: 기능별로 API composable 분리
2. **타입 안전성**: TypeScript 타입 정의 필수
3. **에러 처리**: 일관된 에러 처리 로직
4. **캐싱**: useAsyncData로 자동 캐싱
5. **토큰 관리**: Cookie 또는 localStorage 사용

## 참고 자료

- `state-management.md`: Pinia 상태 관리
- Nuxt $fetch 문서
- Nuxt useAsyncData 문서
