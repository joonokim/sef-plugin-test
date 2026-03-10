# 페이지 템플릿

치환 규칙: `{domain}` → 소문자, `{DomainPascal}` → PascalCase, `{DomainLabel}` → 한국어명, `{prefix}` → 경로 접두사

---

## 패턴 A: 목록 페이지 (index.vue)

**경로**: `pages/{prefix}/{domain}/index.vue`

```vue
<script setup lang="ts">
import type { {DomainPascal}SearchRequest } from '@/types/api/{domain}'

// definePageMeta({ layout: 'admin' })  // 관리자 페이지인 경우 주석 해제

const { get{DomainPascal}s } = use{DomainPascal}()

const page = ref(1)
const pageSize = ref(10)
const searchParams = ref<Partial<{DomainPascal}SearchRequest>>({})

const { data, pending, refresh } = await useAsyncData(
  '{domain}-list',
  () => get{DomainPascal}s({ ...searchParams.value, currentPage: page.value, pageSize: pageSize.value })
)

const handleSearch = (params: Partial<{DomainPascal}SearchRequest>) => {
  searchParams.value = params
  page.value = 1
  refresh()
}

const handleReset = () => {
  searchParams.value = {}
  page.value = 1
  refresh()
}

const handlePageChange = (newPage: number) => {
  page.value = newPage
  refresh()
}
</script>

<template>
  <div>
    <PageHeader title="{DomainLabel} 목록">
      <template #actions>
        <Button @click="navigateTo('/{prefix}/{domain}/create')">등록</Button>
      </template>
    </PageHeader>

    <SearchForm @search="handleSearch" @reset="handleReset">
      <!-- TODO: 검색 조건 추가 -->
      <FormField label="검색어" name="keyword">
        <Input v-model="searchParams.keyword" placeholder="검색어를 입력하세요" />
      </FormField>
    </SearchForm>

    <DataTable
      :data="data?.resultList ?? []"
      :loading="pending"
      :pagination="{
        currentPage: data?.currentPage ?? 1,
        totalCnt: data?.totalCnt ?? 0,
        pageSize: data?.pageSize ?? 10,
      }"
      @page-change="handlePageChange"
    >
      <template #cell-actions="{ row }">
        <div class="flex gap-2">
          <Button variant="outline" size="sm" @click="navigateTo(`/{prefix}/{domain}/${row.id}`)">
            상세
          </Button>
          <Button variant="outline" size="sm" @click="navigateTo(`/{prefix}/{domain}/${row.id}/edit`)">
            수정
          </Button>
        </div>
      </template>
    </DataTable>
  </div>
</template>
```

---

## 패턴 B: 상세 페이지 ([id].vue)

**경로**: `pages/{prefix}/{domain}/[id].vue`

```vue
<script setup lang="ts">
import { toast } from 'vue-sonner'

const route = useRoute()
const id = computed(() => Number(route.params.id))

const { get{DomainPascal}, delete{DomainPascal} } = use{DomainPascal}()

const { data: item, pending } = await useAsyncData(
  `{domain}-${id.value}`,
  () => get{DomainPascal}(id.value)
)

const showDeleteDialog = ref(false)

const handleDelete = async () => {
  try {
    await delete{DomainPascal}(id.value)
    toast.success('삭제되었습니다.')
    navigateTo('/{prefix}/{domain}')
  } catch (error: any) {
    toast.error('삭제 실패', { description: error.message })
  }
}
</script>

<template>
  <div>
    <PageHeader title="{DomainLabel} 상세">
      <template #actions>
        <Button variant="outline" @click="navigateTo(`/{prefix}/{domain}/${id}/edit`)">수정</Button>
        <Button variant="destructive" @click="showDeleteDialog = true">삭제</Button>
      </template>
    </PageHeader>

    <LoadingSpinner v-if="pending" />

    <Card v-else-if="item">
      <CardContent class="pt-6">
        <!-- TODO: 도메인별 상세 내용 -->
        <div class="grid gap-4">
          <div class="grid grid-cols-[120px_1fr] items-center gap-2 border-b pb-2">
            <span class="text-sm font-medium text-muted-foreground">ID</span>
            <span>{{ item.id }}</span>
          </div>
          <!-- TODO: 추가 필드 -->
        </div>
      </CardContent>
    </Card>

    <EmptyState v-else message="{DomainLabel}을 찾을 수 없습니다." />

    <ConfirmDialog
      v-model:open="showDeleteDialog"
      title="삭제 확인"
      description="정말 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다."
      @confirm="handleDelete"
    />
  </div>
</template>
```

---

## 패턴 C: 등록/수정 폼 (create.vue / [id]/edit.vue 공용)

**등록**: `pages/{prefix}/{domain}/create.vue`
**수정**: `pages/{prefix}/{domain}/[id]/edit.vue`

두 파일 모두 아래 코드를 사용. `isEdit` computed로 자동 분기.

```vue
<script setup lang="ts">
import { useForm } from 'vee-validate'
import { toTypedSchema } from '@vee-validate/zod'
import { z } from 'zod'
import { toast } from 'vue-sonner'
import type { {DomainPascal}CreateRequest } from '@/types/api/{domain}'

const route = useRoute()
const isEdit = computed(() => !!route.params.id)
const id = computed(() => isEdit.value ? Number(route.params.id) : null)

const { create{DomainPascal}, update{DomainPascal}, get{DomainPascal} } = use{DomainPascal}()

// 수정 시 기존 데이터 로드
const { data: existing } = isEdit.value
  ? await useAsyncData(`{domain}-edit-${id.value}`, () => get{DomainPascal}(id.value!))
  : { data: ref(null) }

// Zod 스키마 — TODO: 도메인별 필드에 맞게 수정
const formSchema = toTypedSchema(
  z.object({
    title: z.string().min(1, '제목을 입력하세요').max(200, '200자 이내로 입력하세요'),
    content: z.string().min(1, '내용을 입력하세요'),
  })
)

const { handleSubmit, isSubmitting, setValues } = useForm({
  validationSchema: formSchema,
})

// 수정 시 기존 값 주입
if (existing.value) {
  setValues({
    title: (existing.value as any).title,
    content: (existing.value as any).content,
  })
}

const onSubmit = handleSubmit(async (values) => {
  try {
    if (isEdit.value && id.value) {
      await update{DomainPascal}(id.value, values)
      toast.success('수정되었습니다.')
    } else {
      await create{DomainPascal}(values as {DomainPascal}CreateRequest)
      toast.success('등록되었습니다.')
    }
    navigateTo('/{prefix}/{domain}')
  } catch (error: any) {
    toast.error(isEdit.value ? '수정 실패' : '등록 실패', { description: error.message })
  }
})
</script>

<template>
  <div>
    <PageHeader :title="isEdit ? '{DomainLabel} 수정' : '{DomainLabel} 등록'" />

    <Card>
      <CardContent class="pt-6">
        <form @submit="onSubmit" class="space-y-6">
          <!-- TODO: 도메인별 폼 필드 -->
          <FormField name="title" v-slot="{ componentField }">
            <FormItem>
              <FormLabel>제목 <span class="text-destructive">*</span></FormLabel>
              <FormControl>
                <Input v-bind="componentField" placeholder="제목을 입력하세요" />
              </FormControl>
              <FormMessage />
            </FormItem>
          </FormField>

          <FormField name="content" v-slot="{ componentField }">
            <FormItem>
              <FormLabel>내용 <span class="text-destructive">*</span></FormLabel>
              <FormControl>
                <Textarea v-bind="componentField" placeholder="내용을 입력하세요" rows="10" />
              </FormControl>
              <FormMessage />
            </FormItem>
          </FormField>

          <div class="flex justify-end gap-2">
            <Button type="button" variant="outline" @click="navigateTo('/{prefix}/{domain}')">
              취소
            </Button>
            <Button type="submit" :disabled="isSubmitting">
              {{ isEdit ? '수정' : '등록' }}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  </div>
</template>
```
