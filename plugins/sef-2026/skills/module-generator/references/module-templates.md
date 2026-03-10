# 모듈 코드 템플릿

치환 규칙: `{domain}` → 소문자, `{DomainPascal}` → PascalCase, `{DomainLabel}` → 한국어명

---

## types/api/{domain}.ts

```typescript
import type { PageRequest } from './common'

// {DomainLabel} 엔티티
export interface {DomainPascal} {
  id: number
  // TODO: 도메인별 필드 추가
  createdAt: string
  updatedAt: string
}

// 목록 검색 요청
export interface {DomainPascal}SearchRequest extends PageRequest {
  keyword?: string
  // TODO: 도메인별 검색 조건 추가
}

// 등록 요청
export interface {DomainPascal}CreateRequest {
  // TODO: 등록 필드 추가
}

// 수정 요청
export interface {DomainPascal}UpdateRequest {
  // TODO: 수정 필드 추가
}
```

---

## composables/use{DomainPascal}.ts

```typescript
import type {
  {DomainPascal},
  {DomainPascal}SearchRequest,
  {DomainPascal}CreateRequest,
  {DomainPascal}UpdateRequest,
} from '@/types/api/{domain}'
import type { PageResponse } from '@/types/api/common'

export const use{DomainPascal} = () => {
  const { apiFetch } = useApi()

  // 목록 조회 (GET)
  const get{DomainPascal}s = async (params?: Partial<{DomainPascal}SearchRequest>) => {
    return await apiFetch<PageResponse<{DomainPascal}>>('/api/v1/{domain}s', {
      params: { currentPage: 1, pageSize: 10, ...params },
    })
  }

  // 단건 조회 (GET)
  const get{DomainPascal} = async (id: number) => {
    return await apiFetch<{DomainPascal}>(`/api/v1/{domain}s/${id}`)
  }

  // 등록 (POST)
  const create{DomainPascal} = async (data: {DomainPascal}CreateRequest) => {
    return await apiFetch<{DomainPascal}>('/api/v1/{domain}s', {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  // 수정 (POST /{id}/update — PUT 금지)
  const update{DomainPascal} = async (id: number, data: {DomainPascal}UpdateRequest) => {
    return await apiFetch<{DomainPascal}>(`/api/v1/{domain}s/${id}/update`, {
      method: 'POST',
      body: JSON.stringify(data),
    })
  }

  // 삭제 (POST /{id}/delete — DELETE 금지)
  const delete{DomainPascal} = async (id: number) => {
    return await apiFetch<void>(`/api/v1/{domain}s/${id}/delete`, {
      method: 'POST',
    })
  }

  return { get{DomainPascal}s, get{DomainPascal}, create{DomainPascal}, update{DomainPascal}, delete{DomainPascal} }
}
```

### 관리자 API 변형 (`/adm/v1/` 사용 시)

위 composable에 아래 함수를 추가합니다:

```typescript
// 관리자 목록 조회
const getAdm{DomainPascal}s = async (params?: Partial<{DomainPascal}SearchRequest>) => {
  return await apiFetch<PageResponse<{DomainPascal}>>('/adm/v1/{domain}s', {
    params: { currentPage: 1, pageSize: 10, ...params },
  })
}

// 관리자 수정
const admUpdate{DomainPascal} = async (id: number, data: {DomainPascal}UpdateRequest) => {
  return await apiFetch<{DomainPascal}>(`/adm/v1/{domain}s/${id}/update`, {
    method: 'POST',
    body: JSON.stringify(data),
  })
}

// 관리자 삭제
const admDelete{DomainPascal} = async (id: number) => {
  return await apiFetch<void>(`/adm/v1/{domain}s/${id}/delete`, { method: 'POST' })
}
```

---

## stores/{domain}.ts (전역 상태 필요 시만 생성)

목록 검색 조건을 페이지 이동 후에도 유지해야 할 때만 생성합니다.
단순 CRUD는 composable만으로 충분합니다.

```typescript
import { defineStore } from 'pinia'
import type { {DomainPascal}, {DomainPascal}SearchRequest } from '@/types/api/{domain}'
import type { PageResponse } from '@/types/api/common'

export const use{DomainPascal}Store = defineStore('{domain}', () => {
  const list = ref<PageResponse<{DomainPascal}> | null>(null)
  const loading = ref(false)
  const searchParams = ref<Partial<{DomainPascal}SearchRequest>>({
    currentPage: 1,
    pageSize: 10,
  })

  const fetch{DomainPascal}s = async () => {
    const { get{DomainPascal}s } = use{DomainPascal}()
    loading.value = true
    try {
      list.value = await get{DomainPascal}s(searchParams.value)
    } finally {
      loading.value = false
    }
  }

  const setSearchParams = (params: Partial<{DomainPascal}SearchRequest>) => {
    searchParams.value = { ...searchParams.value, ...params, currentPage: 1 }
  }

  const resetSearch = () => {
    searchParams.value = { currentPage: 1, pageSize: 10 }
  }

  return { list, loading, searchParams, fetch{DomainPascal}s, setSearchParams, resetSearch }
})
```
