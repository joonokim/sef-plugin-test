# Nuxt 4 프로젝트 초기 설정 가이드

## 개요

Nuxt 4 프로젝트의 초기 설정 가이드입니다. 민간/공공 프로젝트 모두 동일한 설정을 사용합니다.

## 프로젝트 생성

### 민간 프로젝트

```bash
# 독립 프로젝트로 생성
pnpm dlx nuxi@latest init frontend
cd frontend
pnpm install
```

### 공공 프로젝트

```bash
# 백엔드 내부에 생성
cd sqisoft-sef-2026
pnpm dlx nuxi@latest init frontend
cd frontend
pnpm install
```

## 필수 의존성 설치

```bash
# shadcn-vue 초기화 및 컴포넌트 설치
pnpm dlx shadcn-vue@latest init
pnpm dlx shadcn-vue@latest add button card input textarea form alert skeleton table pagination badge

# 상태 관리
pnpm add @pinia/nuxt pinia

# 폼 관리
pnpm add vee-validate @vee-validate/zod zod

# 아이콘
pnpm add lucide-vue-next @nuxt/icon

# 토스트 알림
pnpm add vue-sonner

# 날짜 처리
pnpm add date-fns

# VueUse
pnpm add @vueuse/core @vueuse/nuxt
```

## Nuxt 설정 (nuxt.config.ts)

```typescript
import tailwindcss from '@tailwindcss/postcss'

export default defineNuxtConfig({
  compatibilityDate: '2024-04-03',
  devtools: { enabled: true },

  unhead: {
    renderSSRHeadOptions: {
      omitLineBreaks: false,
    },
  },

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
    typeCheck: false, // 개발 모드에서는 비활성화하여 성능 향상
    shim: false,
  },

  // SPA 모드 (공공 WAR 배포 시 정적 파일 생성)
  ssr: false,

  // 빌드 설정
  build: {
    transpile: ['vue-sonner', 'lucide-vue-next', 'vee-validate', '@vee-validate/zod', 'zod'],
  },

  // Nitro 서버 설정 (공공: 정적 파일을 Spring Boot static 폴더로 출력)
  nitro: {
    preset: 'static',
    output: {
      dir: '../src/main/resources/static',
      publicDir: '../src/main/resources/static',
    },
  },

  app: {
    baseURL: '/gbadm/',
    head: {
      title: '공공/민간 공통 대시보드',
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1' },
        { name: 'description', content: '공공기관 및 민간 서비스를 위한 공통 대시보드' },
      ],
    },
  },

  // CSS (TailwindCSS 4 방식)
  css: ['~/assets/css/tailwind.css'],

  // 컴포넌트 자동 import 설정
  components: [
    {
      path: '~/components',
      pathPrefix: false,
      extensions: ['.vue'],
    },
  ],

  // 환경변수
  runtimeConfig: {
    apiSecret: '',
    public: {
      serviceType: 'public', // 'public', 'private', 'common'
      apiBase: process.env.NUXT_PUBLIC_API_BASE || '',
    },
  },

  // 개발 환경 프록시
  vite: {
    server: {
      proxy: {
        '/api': {
          target: process.env.NUXT_DEV_PROXY_TARGET || 'http://localhost:7171',
          changeOrigin: true,
        },
        '^/adm/': {
          target: process.env.NUXT_DEV_PROXY_TARGET || 'http://localhost:7171',
          changeOrigin: true,
        },
      },
    },
    css: {
      postcss: {
        plugins: [tailwindcss],
      },
    },
  },

  // 라우트별 레이아웃 자동 설정
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
})
```

## TypeScript 설정 (tsconfig.json)

```json
{
  "extends": "./.nuxt/tsconfig.json",
  "compilerOptions": {
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitReturns": true,
    "skipLibCheck": true
  }
}
```

## TailwindCSS 4 CSS 설정 (assets/css/tailwind.css)

TailwindCSS 4는 `tailwind.config.ts` 파일 대신 CSS 파일에서 직접 설정합니다:

```css
@import 'tailwindcss';

@custom-variant dark (&:is(.dark *));

:root {
  --background: oklch(0.9818 0.0054 95.0986);
  --foreground: oklch(0.3438 0.0269 95.7226);
  --primary: oklch(0.6171 0.1375 39.0427);
  --primary-foreground: oklch(1 0 0);
  /* ... shadcn-vue 색상 변수 */
  --radius: 0.5rem;
}

.dark {
  --background: oklch(0.2679 0.0036 106.6427);
  --foreground: oklch(0.8074 0.0142 93.0137);
  /* ... 다크 모드 변수 */
}

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  /* ... */
}

@layer base {
  * {
    @apply border-border outline-ring/50;
  }

  body {
    @apply bg-background text-foreground;
  }
}
```

## 환경변수 설정

### .env (공공/기본)

```bash
# 개발 프록시 대상 (Spring Boot 포트: 7171)
NUXT_DEV_PROXY_TARGET=http://localhost:7171

# 서비스 타입
NUXT_PUBLIC_SERVICE_TYPE=public
```

### .env (민간)

```bash
# API
NUXT_PUBLIC_API_BASE=http://localhost:7171/api

# 개발 프록시
NUXT_DEV_PROXY_TARGET=http://localhost:7171

# OAuth (선택사항)
NUXT_PUBLIC_GOOGLE_CLIENT_ID=your-google-client-id
```

## 프로젝트 구조

```
frontend/
├── assets/
│   └── css/
│       └── tailwind.css          # TailwindCSS 4 설정
├── components/
│   ├── ui/                       # shadcn-vue 컴포넌트
│   ├── common/                   # 공통 컴포넌트
│   └── features/                 # 기능별 컴포넌트
├── composables/                  # 조합 함수
├── layouts/                      # 레이아웃 (default, auth)
├── middleware/                   # 라우트 미들웨어 (auth, guest)
├── pages/                        # 페이지 (자동 라우팅)
│   ├── admin/                    # 관리자 페이지
│   ├── auth/                     # 인증 페이지 (auth 레이아웃)
│   ├── board/                    # 게시판 페이지
│   └── dashboard.vue
├── stores/                       # Pinia 스토어
├── types/                        # TypeScript 타입
├── nuxt.config.ts
├── package.json
└── tsconfig.json
```

## 개발 서버 실행

### 공공 (현재 프로젝트 구조)

```bash
# 프론트엔드 (frontend/ 디렉토리에서)
cd frontend
pnpm dev  # http://localhost:3000

# 백엔드 (별도 터미널, sqisoft-sef-2026/ 루트에서)
./gradlew bootRun  # http://localhost:7171
```

### 민간

```bash
cd frontend
pnpm dev  # http://localhost:3000
```

## 주요 스크립트

```bash
pnpm dev              # 개발 서버 실행
pnpm build            # 프로덕션 빌드 (static 출력)
pnpm generate         # 정적 파일 생성
pnpm typecheck        # TypeScript 타입 검사
pnpm lint             # ESLint 검사
pnpm lint:fix         # ESLint 자동 수정
pnpm format           # Prettier 포맷
pnpm check:all        # lint + format:check + typecheck 전체 검사
```

## 다음 단계

- `api-client.md`: API 클라이언트 설정
- `state-management.md`: Pinia 상태 관리
- `routing.md`: 파일 기반 라우팅
- 배포 설정: `deployment-private.md` 또는 `deployment-public.md`
