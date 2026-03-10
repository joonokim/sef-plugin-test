# frontend Skill

## 개요

**민간/공공 프로젝트 공통 프론트엔드 시스템 스킬**입니다. Nuxt 4 기반으로 동일한 소스 구조를 유지하며, **프로젝트 위치와 배포 방식만 다릅니다**.

**버전**: 2.2.0

## 핵심 개념

| 구분 | 민간 (Private) | 공공 (Public) |
|------|---------------|--------------|
| **위치** | `frontend/` (독립 프로젝트) | `frontend/` (백엔드 루트 내부) |
| **배포** | Docker 컨테이너 독립 배포 | Spring Boot WAR에 포함 |
| **빌드 출력** | `.output/` → Docker 이미지 | `../src/main/resources/static/` |
| **소스 구조** | ✅ 동일 | ✅ 동일 |

## 주요 기능

- **Nuxt 4 프레임워크**: SPA 모드 (ssr: false)
- **shadcn-vue UI**: TailwindCSS 4 기반 컴포넌트 라이브러리
- **Pinia 상태 관리**: Composition API 스타일
- **TypeScript**: 강타입 지원 (types/api/ 도메인별 파일 분리)
- **파일 기반 라우팅**: flat 구조 (app/ 없음)
- **API 클라이언트**: GET/POST-only (공공 네트워크 정책)
- **공통 컴포넌트**: DataTable, SearchForm, PageHeader, ConfirmDialog 등

## 폴더 구조

민간/공공 모두 동일한 **flat 구조** (`app/` 서브디렉토리 없음):

```
frontend/
├── components/
│   ├── ui/         # shadcn-vue 컴포넌트
│   ├── common/     # 공통 컴포넌트 (DataTable, SearchForm 등)
│   └── admin/      # 관리자 전용 컴포넌트
├── composables/    # API composable (GET/POST-only)
├── layouts/        # default, admin, auth
├── lib/            # utils.ts (shadcn cn() 함수)
├── middleware/     # admin.global.ts, auth.ts, guest.ts
├── pages/          # 파일 기반 자동 라우팅
├── plugins/        # auth-refresh.client.ts, visitTracker.client.ts
├── stores/         # Pinia 스토어
├── types/api/      # 도메인별 타입 파일 분리
├── utils/          # constants.ts, formatter.ts, validation.ts
└── app.vue
```

## References 문서

- **nuxt-setup.md**: Nuxt 4 프로젝트 초기 설정 (nuxt.config.ts 상세)
- **api-client.md**: API 클라이언트 패턴 (GET/POST-only 규칙)
- **state-management.md**: Pinia 상태 관리
- **routing.md**: 파일 기반 라우팅 가이드
- **common-components.md**: 공통 컴포넌트 패턴 (DataTable, SearchForm 등)
- **types-structure.md**: TypeScript 타입 정의 구조
- **deployment-private.md**: 민간 Docker 배포
- **deployment-public.md**: 공공 WAR 배포

## 사용 시나리오

### 프로젝트 초기 설정

```bash
# Nuxt 4 프로젝트 생성
pnpm dlx nuxi@latest init frontend
cd frontend

# 의존성 설치
pnpm install

# shadcn-vue 설정
pnpm dlx shadcn-vue@latest init
pnpm dlx shadcn-vue@latest add button card input table dialog
```

### 공통 컴포넌트 사용

```vue
<script setup lang="ts">
// DataTable, PageHeader 등은 자동 import
const { getBoards } = useBoard()
const { data, pending } = await useAsyncData('boards', () => getBoards())
</script>

<template>
  <PageHeader title="게시글 목록">
    <template #actions>
      <Button @click="navigateTo('/board/create')">등록</Button>
    </template>
  </PageHeader>

  <DataTable
    :data="data?.resultList ?? []"
    :loading="pending"
    :pagination="{ page: 1, pageSize: 10, total: data?.totalCnt ?? 0 }"
  />
</template>
```

### API 호출 (POST-only 패턴)

```typescript
// composables/useBoard.ts — GET/POST만 사용
export const useBoard = () => {
  const { apiFetch } = useApi()

  const getBoards = async (page = 1) =>
    apiFetch<PageResponse<Board>>('/api/v1/boards', { params: { currentPage: page } })

  const updateBoard = async (id: number, data: BoardUpdateRequest) =>
    apiFetch<Board>(`/api/v1/boards/${id}/update`, { method: 'POST', body: JSON.stringify(data) })

  const deleteBoard = async (id: number) =>
    apiFetch<void>(`/api/v1/boards/${id}/delete`, { method: 'POST' })

  return { getBoards, updateBoard, deleteBoard }
}
```

## 배포

### 민간 프로젝트 (Docker)

```bash
# Docker 빌드
docker build -t frontend:latest .
docker run -p 3000:3000 frontend:latest
```

### 공공 프로젝트 (WAR)

```bash
# 프론트엔드 빌드 (nuxt.config.ts의 nitro.output으로 자동 복사)
cd frontend
pnpm build

# WAR 패키징
./gradlew clean bootWar
```

## 관련 스킬

### 공통
- `ui-components`: shadcn-vue UI 컴포넌트
- `auth-system`: 인증 시스템
- `board-system`: 게시판 시스템

### 민간 (sef-2026-private 플러그인)
- `project-init`: 민간 프로젝트 초기화
- `backend`: Spring Boot + JPA
- `deployment`: Docker/Kubernetes 배포

### 공공 (sef-2026-public 플러그인)
- `project-init`: 공공 프로젝트 초기화
- `backend`: Spring Boot + MyBatis
- `deployment`: WAR/WAS 배포

## 이전 스킬과의 차이

- ✅ **통합됨**: 기존 민간/공공 프론트엔드 → 공통 `frontend` 스킬
- ✅ **동일 소스**: 민간/공공 코드 공유
- ✅ **위치 차이만**: 프로젝트 위치와 배포 방식만 구분
- ✅ **문서 통합**: 중복 제거 및 명확한 구조

## 버전

- **v2.2.0**: flat 구조 수정, POST-only API, 공통 컴포넌트/타입 구조 문서화 (2026-03-09)
- **v2.1.0**: sef-2026 공통 플러그인으로 통합
- **v1.0.0**: 초기 통합 버전 (2026-02-09)
