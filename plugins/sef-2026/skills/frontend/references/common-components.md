# 공통 컴포넌트 패턴 (components/common/)

## 개요

`components/common/` 디렉토리에는 프로젝트 전반에서 재사용되는 공통 UI 컴포넌트가 위치합니다.
shadcn-vue의 기본 컴포넌트를 래핑하거나 조합하여 프로젝트 특화 컴포넌트를 제공합니다.

## 컴포넌트 목록

| 파일 | 용도 |
|------|------|
| `DataTable.vue` | 제네릭 타입 지원 데이터 테이블 (페이지네이션, 정렬 내장) |
| `SearchForm.vue` | 슬롯 기반 검색 폼 카드 |
| `FormField.vue` | 레이블 + 입력 + 에러 메시지 래퍼 |
| `PageHeader.vue` | 페이지 상단 헤더 (제목, 설명, 액션 버튼) |
| `EmptyState.vue` | 빈 상태 표시 카드 |
| `ConfirmDialog.vue` | 확인/취소 모달 다이얼로그 |
| `LoadingSpinner.vue` | 로딩 스피너 |
| `SidebarMenu.vue` | 사이드바 메뉴 래퍼 |
| `SidebarMenuItem.vue` | 사이드바 개별 메뉴 아이템 |

---

## DataTable.vue

제네릭 타입 `T`를 지원하는 범용 데이터 테이블. 정렬과 페이지네이션 UI를 내장합니다.

### Props

```typescript
interface DataTableColumn<T> {
  key: keyof T | string       // 데이터 키
  label: string               // 컬럼 헤더 텍스트
  sortable?: boolean          // 정렬 활성화 여부
  align?: 'left' | 'center' | 'right'  // 셀 정렬
  width?: string              // 컬럼 너비 (CSS)
  formatter?: (value: any, row: T) => string  // 값 포맷터
}

interface Props<T> {
  data: T[]                   // 표시할 데이터 배열
  columns: DataTableColumn<T>[] // 컬럼 정의
  loading?: boolean           // 로딩 상태
  emptyText?: string          // 빈 상태 메시지
  pagination: {
    page: number              // 현재 페이지 (1부터)
    pageSize: number          // 페이지 크기
    total: number             // 전체 건수
  }
  sortBy?: string             // 현재 정렬 필드
  sortOrder?: 'asc' | 'desc' // 정렬 방향
}
```

### Emits

```typescript
interface Emits {
  (e: 'sort', column: string, order: 'asc' | 'desc'): void
  (e: 'page-change', page: number): void
}
```

### 슬롯

| 슬롯명 | 설명 |
|--------|------|
| `cell-{key}` | 특정 컬럼 셀 커스텀 렌더링. `{ row, value }` 제공 |

### 사용 예시

```vue
<script setup lang="ts">
import type { Board } from '@/types/api/board'
import type { DataTableColumn } from '@/components/common/DataTable.vue'

const columns: DataTableColumn<Board>[] = [
  { key: 'id', label: 'No.', align: 'center', width: '80px' },
  { key: 'title', label: '제목', sortable: true },
  { key: 'rgtrNm', label: '작성자', align: 'center', width: '120px' },
  {
    key: 'regDt',
    label: '등록일',
    align: 'center',
    width: '120px',
    formatter: (v) => formatDate(v),
  },
]

const page = ref(1)
const { getBoards } = useBoard()
const { data, pending, refresh } = await useAsyncData(
  'boards',
  () => getBoards(page.value)
)

const handlePageChange = (newPage: number) => {
  page.value = newPage
  refresh()
}
</script>

<template>
  <DataTable
    :data="data?.resultList ?? []"
    :columns="columns"
    :loading="pending"
    :pagination="{
      page: data?.currentPage ?? 1,
      pageSize: data?.pageSize ?? 10,
      total: data?.totalCnt ?? 0,
    }"
    @page-change="handlePageChange"
  >
    <!-- 특정 셀 커스텀 렌더링 -->
    <template #cell-title="{ row, value }">
      <NuxtLink :to="`/board/${row.id}`" class="hover:underline">
        {{ value }}
      </NuxtLink>
    </template>
  </DataTable>
</template>
```

---

## SearchForm.vue

Card 래퍼 안에 검색 필드와 검색/초기화 버튼을 포함하는 검색 폼.
`fields` 슬롯에 검색 입력 컴포넌트를 주입합니다.

### Emits

```typescript
interface Emits {
  (e: 'search'): void  // 검색 버튼 클릭 또는 폼 submit
  (e: 'reset'): void   // 초기화 버튼 클릭
}
```

### 슬롯

| 슬롯명 | 설명 |
|--------|------|
| `fields` | 검색 입력 필드 영역 (grid 레이아웃 자동 적용) |
| `actions` | 기본 검색/초기화 버튼 대체 시 사용 |

### 사용 예시

```vue
<script setup lang="ts">
const searchForm = reactive({
  keyword: '',
  category: '',
})

const { getBoards } = useBoard()
const { data, refresh } = await useAsyncData('boards', () => getBoards())

const handleSearch = () => refresh()
const handleReset = () => {
  searchForm.keyword = ''
  searchForm.category = ''
  refresh()
}
</script>

<template>
  <SearchForm @search="handleSearch" @reset="handleReset">
    <template #fields>
      <!-- grid 안에 자동 배치 -->
      <div>
        <Label>키워드</Label>
        <Input v-model="searchForm.keyword" placeholder="검색어 입력" />
      </div>
      <div>
        <Label>카테고리</Label>
        <Select v-model="searchForm.category">
          <SelectTrigger><SelectValue placeholder="전체" /></SelectTrigger>
          <SelectContent>
            <SelectItem value="">전체</SelectItem>
            <SelectItem value="notice">공지</SelectItem>
          </SelectContent>
        </Select>
      </div>
    </template>
  </SearchForm>
</template>
```

---

## FormField.vue

레이블, 입력 슬롯, 힌트, 에러 메시지를 통합하는 폼 필드 래퍼.

### Props

```typescript
interface Props {
  label?: string     // 레이블 텍스트
  required?: boolean // 필수 표시 (*) 여부
  error?: string     // 에러 메시지 (표시 시 hint 숨김)
  hint?: string      // 힌트 텍스트
  id?: string        // input id (미입력 시 자동 생성)
}
```

### 슬롯

| 슬롯명 | 슬롯 Props | 설명 |
|--------|-----------|------|
| (default) | `{ id: string }` | 입력 컴포넌트. id 연결에 사용 |

### 사용 예시

```vue
<template>
  <!-- 기본 사용 -->
  <FormField label="제목" required :error="errors.title">
    <template #default="{ id }">
      <Input :id="id" v-model="form.title" />
    </template>
  </FormField>

  <!-- 힌트 포함 -->
  <FormField label="비밀번호" hint="8자 이상 입력하세요">
    <template #default="{ id }">
      <Input :id="id" type="password" v-model="form.password" />
    </template>
  </FormField>
</template>
```

---

## PageHeader.vue

페이지 상단에 제목, 설명, 액션 버튼(우측)을 표시하는 헤더 컴포넌트.
하단에 `<Separator />` 포함.

### Props

```typescript
interface Props {
  title: string        // 페이지 제목 (필수)
  description?: string // 부제목 (선택)
}
```

### 슬롯

| 슬롯명 | 설명 |
|--------|------|
| `actions` | 우측 버튼 영역 (등록, 내보내기 등) |

### 사용 예시

```vue
<template>
  <PageHeader title="게시글 관리" description="게시글을 조회하고 관리합니다.">
    <template #actions>
      <Button @click="navigateTo('/admin/board/create')">
        <Plus class="mr-2 h-4 w-4" />
        등록
      </Button>
      <Button variant="outline" @click="handleExcelDownload">
        <Download class="mr-2 h-4 w-4" />
        엑셀 다운로드
      </Button>
    </template>
  </PageHeader>
</template>
```

---

## EmptyState.vue

데이터가 없을 때 표시하는 빈 상태 카드 컴포넌트.

### Props

```typescript
interface Props {
  title?: string       // 제목 (기본: '데이터가 없습니다')
  description?: string // 설명 (기본: '표시할 항목이 없습니다.')
  icon?: string        // 아이콘 이모지 (미입력 시 기본 SVG 아이콘)
  actionText?: string  // 액션 버튼 텍스트 (미입력 시 버튼 숨김)
}
```

### Emits

```typescript
interface Emits {
  (e: 'action'): void  // 액션 버튼 클릭
}
```

### 사용 예시

```vue
<template>
  <!-- 단순 빈 상태 -->
  <EmptyState
    v-if="!data?.resultList.length"
    title="게시글이 없습니다"
    description="첫 번째 게시글을 작성해보세요."
    action-text="게시글 작성"
    @action="navigateTo('/board/create')"
  />
</template>
```

---

## ConfirmDialog.vue

확인/취소 모달 다이얼로그. v-model:open으로 개폐 상태 제어.

### Props

```typescript
interface Props {
  open?: boolean             // 다이얼로그 열림 여부
  title?: string             // 제목 (기본: '확인')
  description?: string       // 본문 (기본: '이 작업을 수행하시겠습니까?')
  confirmText?: string       // 확인 버튼 텍스트 (기본: '확인')
  cancelText?: string        // 취소 버튼 텍스트 (기본: '취소')
  variant?: 'default' | 'destructive'  // 확인 버튼 스타일
}
```

### Emits

```typescript
interface Emits {
  (e: 'update:open', value: boolean): void
  (e: 'confirm'): void
  (e: 'cancel'): void
}
```

### 사용 예시

```vue
<script setup lang="ts">
const deleteDialog = ref(false)
const targetId = ref<number | null>(null)

const openDeleteDialog = (id: number) => {
  targetId.value = id
  deleteDialog.value = true
}

const { deleteBoard } = useBoard()
const handleDelete = async () => {
  if (!targetId.value) return
  await deleteBoard(targetId.value)
  toast.success('삭제되었습니다.')
  refresh()
}
</script>

<template>
  <!-- 삭제 버튼 -->
  <Button variant="destructive" size="sm" @click="openDeleteDialog(board.id)">
    삭제
  </Button>

  <!-- 삭제 확인 다이얼로그 -->
  <ConfirmDialog
    v-model:open="deleteDialog"
    title="게시글 삭제"
    description="삭제된 게시글은 복구할 수 없습니다. 삭제하시겠습니까?"
    confirm-text="삭제"
    variant="destructive"
    @confirm="handleDelete"
  />
</template>
```

---

## LoadingSpinner.vue

로딩 상태를 표시하는 스피너 컴포넌트.

### 사용 예시

```vue
<template>
  <div v-if="pending" class="flex justify-center py-8">
    <LoadingSpinner />
  </div>
  <div v-else>
    <!-- 실제 콘텐츠 -->
  </div>
</template>
```

---

## 관리자 전용 컴포넌트 (components/admin/)

| 파일 | 용도 |
|------|------|
| `AdminHeader.vue` | 관리자 상단 헤더 (사용자 정보, 로그아웃) |
| `AdminSidebar.vue` | 관리자 사이드바 네비게이션 |
| `AdminBreadcrumb.vue` | 현재 위치 브레드크럼 |
| `AuditReasonModal.vue` | 감사 로그 사유 입력 모달 |
| `MenuRolePermissionNode.vue` | 메뉴-역할 권한 트리 노드 |
| `MenuTreeNode.vue` | 메뉴 트리 노드 |
| `StatisticsTabs.vue` | 통계 탭 전환 컴포넌트 |

### AuditReasonModal 사용 예시

```vue
<script setup lang="ts">
const auditModal = ref(false)
const pendingAction = ref<(() => Promise<void>) | null>(null)

// 감사 로그가 필요한 작업 실행 시
const handleSensitiveAction = async (action: () => Promise<void>) => {
  pendingAction.value = action
  auditModal.value = true
}

const executeWithAudit = async (reason: string) => {
  if (!pendingAction.value) return
  // 사유를 서버에 전달 후 작업 실행
  await pendingAction.value()
  auditModal.value = false
}
</script>

<template>
  <AuditReasonModal
    v-model:open="auditModal"
    @confirm="executeWithAudit"
  />
</template>
```

---

## 공통 컴포넌트 자동 Import

`nuxt.config.ts`에 `pathPrefix: false` 설정으로 컴포넌트가 자동 import됩니다:

```typescript
components: [
  { path: '~/components', pathPrefix: false, extensions: ['.vue'] },
],
```

따라서 페이지/컴포넌트에서 별도 import 없이 사용 가능합니다:

```vue
<template>
  <!-- import 없이 바로 사용 -->
  <DataTable ... />
  <SearchForm ... />
  <PageHeader ... />
</template>
```

## 참고 자료

- `routing.md`: 파일 기반 라우팅
- `api-client.md`: API composable 패턴
- `types-structure.md`: TypeScript 타입 정의 구조
