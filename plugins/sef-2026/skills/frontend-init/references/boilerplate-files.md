# 공통 보일러플레이트 파일 템플릿

## app.vue

```vue
<template>
  <NuxtLayout>
    <NuxtPage />
  </NuxtLayout>
  <Toaster />
</template>

<script setup lang="ts">
import { Toaster } from 'vue-sonner'
</script>
```

---

## lib/utils.ts

```typescript
import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

---

## types/api/common.ts

```typescript
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

export interface ApiResponse<T = void> {
  success: boolean
  message?: string
  data?: T
}
```

## types/api/auth.ts

```typescript
export interface User {
  userId: string
  userNm: string
  email: string
  roleCode: string
}

export interface LoginRequest {
  username: string
  password: string
}

export interface LoginResponse {
  token: string
  refreshToken: string
  user: User
}
```

## types/api/index.ts

```typescript
export * from './common'
export * from './auth'
```

---

## composables/useApi.ts

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

    const url = params
      ? `${endpoint}?${new URLSearchParams(params)}`
      : endpoint

    try {
      return await $fetch<T>(`${baseURL}${url}`, {
        ...fetchOptions,
        headers: {
          'Content-Type': 'application/json',
          ...(token.value && { Authorization: `Bearer ${token.value}` }),
          ...(fetchOptions?.headers as Record<string, string> | undefined),
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

---

## stores/auth.ts

```typescript
import { defineStore } from 'pinia'
import type { User, LoginRequest } from '@/types/api'

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

---

## middleware/auth.ts

```typescript
export default defineNuxtRouteMiddleware(() => {
  const authStore = useAuthStore()
  if (!authStore.isAuthenticated) {
    return navigateTo('/auth/login')
  }
})
```

## middleware/guest.ts

```typescript
export default defineNuxtRouteMiddleware(() => {
  const authStore = useAuthStore()
  if (authStore.isAuthenticated) {
    return navigateTo('/')
  }
})
```

## middleware/admin.global.ts

```typescript
export default defineNuxtRouteMiddleware((to) => {
  if (to.path.startsWith('/admin')) {
    const authStore = useAuthStore()
    if (!authStore.isAuthenticated) {
      return navigateTo('/auth/login')
    }
  }
})
```

---

## layouts/auth.vue

```vue
<template>
  <div class="flex min-h-screen items-center justify-center bg-background">
    <slot />
  </div>
</template>
```

## layouts/default.vue

```vue
<template>
  <div class="flex min-h-screen">
    <SidebarMenu />
    <div class="flex flex-1 flex-col">
      <header class="border-b px-6 py-4">
        <slot name="header" />
      </header>
      <main class="flex-1 p-6">
        <slot />
      </main>
    </div>
  </div>
</template>
```

## layouts/admin.vue

```vue
<template>
  <div class="flex min-h-screen">
    <AdminSidebar />
    <div class="flex flex-1 flex-col">
      <AdminHeader />
      <main class="flex-1 p-6">
        <AdminBreadcrumb />
        <slot />
      </main>
    </div>
  </div>
</template>
```

---

## pages/index.vue

```vue
<script setup lang="ts">
definePageMeta({ middleware: 'auth' })
</script>

<template>
  <div>
    <PageHeader title="메인" />
    <!-- TODO: 메인 페이지 내용 -->
  </div>
</template>
```

## pages/auth/login.vue

```vue
<script setup lang="ts">
import { useForm } from 'vee-validate'
import { toTypedSchema } from '@vee-validate/zod'
import { z } from 'zod'
import { toast } from 'vue-sonner'

definePageMeta({ middleware: 'guest' })

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
    navigateTo('/')
  } catch (error: any) {
    toast.error('로그인 실패', { description: error.message })
  }
})
</script>

<template>
  <Card class="w-full max-w-sm">
    <CardHeader>
      <CardTitle>로그인</CardTitle>
    </CardHeader>
    <CardContent>
      <form @submit="onSubmit" class="space-y-4">
        <FormField name="username" v-slot="{ componentField }">
          <FormItem>
            <FormLabel>아이디</FormLabel>
            <FormControl>
              <Input v-bind="componentField" placeholder="아이디를 입력하세요" />
            </FormControl>
            <FormMessage />
          </FormItem>
        </FormField>
        <FormField name="password" v-slot="{ componentField }">
          <FormItem>
            <FormLabel>비밀번호</FormLabel>
            <FormControl>
              <Input v-bind="componentField" type="password" placeholder="비밀번호를 입력하세요" />
            </FormControl>
            <FormMessage />
          </FormItem>
        </FormField>
        <Button type="submit" :disabled="isSubmitting" class="w-full">
          로그인
        </Button>
      </form>
    </CardContent>
  </Card>
</template>
```

## pages/auth/logout.vue

```vue
<script setup lang="ts">
const authStore = useAuthStore()

onMounted(async () => {
  await authStore.logout()
})
</script>

<template>
  <div class="flex min-h-screen items-center justify-center">
    <p class="text-muted-foreground">로그아웃 중...</p>
  </div>
</template>
```
