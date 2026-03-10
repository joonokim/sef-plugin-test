# 파일 기반 라우팅 가이드

## 개요

Nuxt 4는 `pages/` 디렉토리 구조에 따라 자동으로 라우팅을 생성합니다. 민간/공공 프로젝트 모두 동일한 라우팅 구조를 사용합니다.

## 실제 pages/ 구조

```
pages/
├── index.vue                       → /
├── dashboard.vue                   → /dashboard
├── auth/                           → auth 레이아웃 자동 적용 (nuxt.config.ts hooks)
│   ├── login.vue                   → /auth/login
│   ├── signup.vue                  → /auth/signup
│   ├── find-id.vue                 → /auth/find-id
│   ├── forgot-password.vue         → /auth/forgot-password
│   ├── reset-password.vue          → /auth/reset-password
│   └── profile.vue                 → /auth/profile
├── board/
│   ├── list.vue                    → /board/list
│   ├── create.vue                  → /board/create
│   ├── [id].vue                    → /board/:id
│   └── [id]/
│       └── edit.vue                → /board/:id/edit
└── admin/
    ├── dashboard.vue               → /admin/dashboard
    ├── bbs/
    │   ├── list.vue                → /admin/bbs/list
    │   └── statistics.vue          → /admin/bbs/statistics
    ├── member/
    │   ├── list.vue                → /admin/member/list
    │   ├── role.vue                → /admin/member/role
    │   ├── settings.vue            → /admin/member/settings
    │   └── statistics.vue          → /admin/member/statistics
    └── system/
        ├── codes.vue               → /admin/system/codes
        ├── menus.vue               → /admin/system/menus
        └── statistics.vue          → /admin/system/statistics
```

## 기본 라우팅

### index.vue (홈페이지)

```vue
<template>
  <div>
    <h1>Welcome</h1>
    <NuxtLink to="/auth/login">로그인</NuxtLink>
  </div>
</template>

<script setup lang="ts">
useHead({
  title: 'Home',
  meta: [
    { name: 'description', content: 'Welcome to our app' },
  ],
})
</script>
```

## 동적 라우팅

### 단일 파라미터

```
pages/
└── board/
    ├── list.vue              → /board/list
    └── [id].vue              → /board/:id
```

### [id].vue (게시글 상세)

```vue
<template>
  <div>
    <h1>{{ board?.title }}</h1>
    <p>{{ board?.content }}</p>
  </div>
</template>

<script setup lang="ts">
const route = useRoute()
const id = computed(() => Number(route.params.id))

const { getBoard } = useBoard()
const { data: board } = await useAsyncData(
  `board-${id.value}`,
  () => getBoard(id.value)
)
</script>
```

## 중첩 라우팅

### 레이아웃 기반 중첩

```
pages/
└── admin/
    ├── dashboard.vue         → /admin/dashboard
    ├── member/
    │   └── list.vue          → /admin/member/list
    └── system/
        └── menus.vue         → /admin/system/menus
```

### layouts/default.vue (관리자 레이아웃)

```vue
<!-- layouts/default.vue -->
<template>
  <div>
    <nav>
      <NuxtLink to="/admin/dashboard">대시보드</NuxtLink>
      <NuxtLink to="/admin/member/list">회원 관리</NuxtLink>
      <NuxtLink to="/admin/system/menus">메뉴 관리</NuxtLink>
    </nav>
    <main>
      <slot />
    </main>
  </div>
</template>
```

### 페이지에서 레이아웃 지정

```vue
<template>
  <!-- 내용 -->
</template>

<script setup lang="ts">
definePageMeta({
  layout: 'default'
})
</script>
```

## 레이아웃 자동 설정 (nuxt.config.ts hooks)

`/auth` 경로는 `nuxt.config.ts`의 `hooks`에서 자동으로 `auth` 레이아웃을 적용합니다:

```typescript
// nuxt.config.ts
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

따라서 `/auth` 페이지에서는 `definePageMeta({ layout: 'auth' })`를 생략할 수 있습니다.

## 프로그래매틱 네비게이션

### navigateTo 사용

```vue
<script setup lang="ts">
// 기본 이동
const goToBoard = () => {
  navigateTo('/board/list')
}

// 파라미터와 함께 이동
const goToBoardDetail = (id: number) => {
  navigateTo(`/board/${id}`)
}

// 쿼리 파라미터
const goToSearch = () => {
  navigateTo({
    path: '/board/list',
    query: { keyword: 'example', page: '1' }
  })
}

// replace (히스토리 추가 안 함)
const goToLogin = () => {
  navigateTo('/auth/login', { replace: true })
}
</script>
```

### 뒤로가기/앞으로가기

```typescript
const router = useRouter()

// 뒤로가기
router.back()

// 앞으로가기
router.forward()

// 특정 위치로
router.go(-2)  // 2단계 뒤로
router.go(1)   // 1단계 앞으로
```

## 라우트 파라미터 접근

### useRoute

```vue
<script setup lang="ts">
const route = useRoute()

// 파라미터
const id = route.params.id

// 쿼리
const page = route.query.page
const keyword = route.query.keyword

// 전체 경로
const fullPath = route.fullPath  // /board/1?page=2

// 경로명
const name = route.name  // 'board-id'
</script>
```

### Reactive 파라미터

```vue
<script setup lang="ts">
const route = useRoute()

// Reactive하게 사용
const id = computed(() => Number(route.params.id))

watch(id, (newId) => {
  console.log('ID changed:', newId)
})
</script>
```

## 라우트 메타데이터

### definePageMeta

```vue
<script setup lang="ts">
definePageMeta({
  // 레이아웃
  layout: 'default',

  // 미들웨어 (auth 또는 guest)
  middleware: ['auth'],
})
</script>
```

## 미들웨어

### middleware/auth.ts

인증이 필요한 페이지에 적용합니다. 미인증 시 `/auth/login`으로 리다이렉트하며 `redirect` 쿼리로 돌아갈 경로를 전달합니다:

```typescript
export default defineNuxtRouteMiddleware((to) => {
  const authStore = useAuthStore()

  // 인증되지 않은 경우 로그인 페이지로 리다이렉트
  if (!authStore.isAuthenticated) {
    return navigateTo({
      path: '/auth/login',
      query: {
        redirect: to.fullPath, // 로그인 후 돌아갈 페이지 저장
      },
    })
  }

  // 인증된 경우 통과
})
```

### middleware/guest.ts

로그인하지 않은 사용자만 접근 가능한 페이지에 적용합니다 (로그인, 회원가입 등). 인증된 사용자는 역할(`roleId`)에 따라 적절한 대시보드로 리다이렉트됩니다:

```typescript
export default defineNuxtRouteMiddleware(() => {
  const authStore = useAuthStore()

  // 이미 로그인된 경우 역할에 따라 대시보드로 리다이렉트
  if (authStore.isAuthenticated) {
    const dashboardPath = authStore.roleId === 'USER_ROLE_ADM' ? '/admin/dashboard' : '/dashboard'

    return navigateTo(dashboardPath)
  }

  // 로그인하지 않은 경우 통과
})
```

### 페이지에 미들웨어 적용

```vue
<!-- 인증 필요 페이지 -->
<script setup lang="ts">
definePageMeta({
  middleware: ['auth']
})
</script>

<!-- 게스트 전용 페이지 (로그인, 회원가입) -->
<script setup lang="ts">
definePageMeta({
  middleware: ['guest']
})
</script>
```

## NuxtLink 컴포넌트

### 기본 사용

```vue
<template>
  <!-- 내부 링크 -->
  <NuxtLink to="/board/list">게시판</NuxtLink>

  <!-- 동적 링크 -->
  <NuxtLink :to="`/board/${board.id}`">{{ board.title }}</NuxtLink>

  <!-- 객체 형태 -->
  <NuxtLink :to="{ path: '/board/list', query: { keyword: 'example' } }">
    검색
  </NuxtLink>

  <!-- 새 탭으로 열기 -->
  <NuxtLink to="/terms" target="_blank">
    이용약관
  </NuxtLink>
</template>
```

### 활성 링크 스타일

```vue
<template>
  <NuxtLink
    to="/admin/dashboard"
    active-class="text-blue-500"
    exact-active-class="font-bold text-blue-600"
  >
    대시보드
  </NuxtLink>
</template>
```

## 404 에러 페이지

### error.vue

```vue
<!-- error.vue -->
<template>
  <div class="error-page">
    <h1>{{ error.statusCode === 404 ? '페이지를 찾을 수 없습니다' : '오류 발생' }}</h1>
    <p>{{ error.message }}</p>
    <button @click="handleError">홈으로 돌아가기</button>
  </div>
</template>

<script setup lang="ts">
const props = defineProps<{
  error: { statusCode: number; message: string }
}>()

const handleError = () => clearError({ redirect: '/' })
</script>
```

## 라우팅 베스트 프랙티스

1. **명확한 구조**: 직관적인 파일 구조 유지 (실제 pages/ 구조 참고)
2. **미들웨어 활용**: 인증은 `auth`, 비인증 전용은 `guest` 미들웨어 사용
3. **레이아웃 재사용**: `nuxt.config.ts hooks`로 경로별 레이아웃 자동 적용
4. **타입 안전성**: `route.params`의 타입 변환 (`Number()`, `String()`)
5. **리다이렉트 쿼리**: 로그인 후 원래 페이지로 돌아갈 수 있도록 `redirect` 쿼리 활용

## 참고 자료

- Nuxt 라우팅 문서
- Vue Router 문서
