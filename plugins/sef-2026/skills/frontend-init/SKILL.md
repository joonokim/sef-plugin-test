---
name: frontend-init
description: Nuxt 4 프론트엔드 프로젝트 초기 구조 생성. package.json, nuxt.config.ts, tailwind.css, 공통 composables, types, middleware, layouts 기본 파일 scaffolding. "프론트엔드 초기화", "Nuxt 4 세팅", "frontend 폴더 구조 만들어줘" 요청 시 또는 새 프로젝트의 frontend/ 디렉토리가 비어있을 때 사용.
---

# 프론트엔드 초기화 (frontend-init)

## 생성 파일 목록

```
frontend/
├── package.json
├── nuxt.config.ts
├── tsconfig.json
├── components.json              # shadcn-vue 설정
├── .env / .env.example
├── app.vue
├── assets/css/tailwind.css
├── lib/utils.ts
├── types/api/common.ts
├── types/api/auth.ts
├── types/api/index.ts
├── composables/useApi.ts
├── stores/auth.ts
├── middleware/auth.ts
├── middleware/guest.ts
├── middleware/admin.global.ts
├── layouts/default.vue
├── layouts/auth.vue
├── layouts/admin.vue
├── pages/index.vue
├── pages/auth/login.vue
└── pages/auth/logout.vue
```

## 실행 절차

### 1. 설정 파일 생성 → `references/config-templates.md` 참조

`package.json`, `nuxt.config.ts`, `components.json`, `assets/css/tailwind.css`, `.env.example`, `tsconfig.json` 생성.

**공공/민간 분기**:
- **공공**: `nuxt.config.ts`에 `nitro.output` + `app.baseURL` 추가 설정 적용
- **민간**: 기본 설정 그대로 사용 (Docker 배포 시 ssr: true 검토)

### 2. 공통 보일러플레이트 생성 → `references/boilerplate-files.md` 참조

`app.vue`, `lib/utils.ts`, `types/api/`, `composables/useApi.ts`, `stores/auth.ts`, `middleware/`, `layouts/`, `pages/auth/` 생성.

### 3. shadcn-vue 컴포넌트 설치

```bash
pnpm dlx shadcn-vue@latest add button card input label dialog table form select badge separator dropdown-menu sheet textarea
```

### 4. 개발 서버 시작

```bash
cd frontend
pnpm install
pnpm dev  # http://localhost:3000
```

## 참조 파일

- `references/config-templates.md`: package.json, nuxt.config.ts (공통+공공), components.json, tailwind.css
- `references/boilerplate-files.md`: app.vue, types, composables, stores, middleware, layouts, 기본 pages

## 관련 스킬

- `sef-2026:page-generator`: 목록/상세/폼 페이지 생성
- `sef-2026:module-generator`: 도메인 모듈 세트 (types + composable + store) 생성
