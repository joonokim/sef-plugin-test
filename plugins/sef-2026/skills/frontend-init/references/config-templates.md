# 설정 파일 템플릿

## package.json

```json
{
  "name": "frontend",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "nuxt dev",
    "build": "nuxt build",
    "generate": "nuxt generate",
    "preview": "nuxt preview",
    "typecheck": "nuxt typecheck",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --write ."
  },
  "dependencies": {
    "@nuxt/icon": "latest",
    "@pinia/nuxt": "latest",
    "@tailwindcss/postcss": "latest",
    "@vee-validate/zod": "latest",
    "@vueuse/core": "latest",
    "@vueuse/nuxt": "latest",
    "clsx": "latest",
    "lucide-vue-next": "latest",
    "pinia": "latest",
    "radix-vue": "latest",
    "shadcn-nuxt": "latest",
    "tailwind-merge": "latest",
    "tailwindcss": "latest",
    "vee-validate": "latest",
    "vue-sonner": "latest",
    "zod": "latest",
    "nuxt": "latest",
    "vue": "latest",
    "vue-router": "latest"
  },
  "devDependencies": {
    "@types/node": "latest",
    "typescript": "latest"
  },
  "packageManager": "pnpm@latest"
}
```

---

## nuxt.config.ts (민간 기본)

```typescript
import tailwindcss from '@tailwindcss/postcss'

export default defineNuxtConfig({
  compatibilityDate: '2024-04-03',
  devtools: { enabled: true },

  modules: ['@pinia/nuxt', 'shadcn-nuxt', '@vueuse/nuxt', '@nuxt/icon'],

  shadcn: {
    prefix: '',
    componentDir: './components/ui',
  },

  typescript: {
    strict: true,
    typeCheck: false,
    shim: false,
  },

  ssr: false,

  css: ['~/assets/css/tailwind.css'],

  components: [
    { path: '~/components', pathPrefix: false, extensions: ['.vue'] },
  ],

  runtimeConfig: {
    public: {
      apiBase: process.env.NUXT_PUBLIC_API_BASE || '',
    },
  },

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

  vite: {
    server: {
      proxy: {
        '/api': { target: 'http://localhost:7171', changeOrigin: true },
        '^/adm/': { target: 'http://localhost:7171', changeOrigin: true },
      },
    },
    css: {
      postcss: { plugins: [tailwindcss] },
    },
  },
})
```

## nuxt.config.ts 추가 설정 (공공 프로젝트 WAR 배포)

민간 기본 설정에 아래 내용을 추가합니다:

```typescript
// nitro: 정적 파일을 Spring Boot static 폴더로 출력
nitro: {
  preset: 'static',
  output: {
    dir: '../src/main/resources/static',
    publicDir: '../src/main/resources/static',
  },
},

// baseURL: 프로젝트 컨텍스트 코드 (예: /gbadm/)
app: {
  baseURL: '/[프로젝트코드]/',
},
```

---

## tsconfig.json

```json
{
  "extends": "./.nuxt/tsconfig.json"
}
```

---

## components.json (shadcn-vue)

```json
{
  "$schema": "https://shadcn-vue.com/schema.json",
  "style": "new-york",
  "typescript": true,
  "tsConfigPath": "./tsconfig.json",
  "framework": "nuxt",
  "tailwind": {
    "config": "",
    "css": "assets/css/tailwind.css",
    "baseColor": "zinc",
    "cssVariables": true
  },
  "iconLibrary": "lucide",
  "aliases": {
    "components": "@/components",
    "composables": "@/composables",
    "hooks": "@/composables",
    "lib": "@/lib",
    "utils": "@/lib/utils"
  }
}
```

---

## assets/css/tailwind.css

```css
@import "tailwindcss";
@import "tw-animate-css";

@custom-variant dark (&:is(.dark *));

:root {
  --radius: 0.5rem;
  --background: oklch(1 0 0);
  --foreground: oklch(0.145 0 0);
  --card: oklch(1 0 0);
  --card-foreground: oklch(0.145 0 0);
  --popover: oklch(1 0 0);
  --popover-foreground: oklch(0.145 0 0);
  --primary: oklch(0.205 0 0);
  --primary-foreground: oklch(0.985 0 0);
  --secondary: oklch(0.97 0 0);
  --secondary-foreground: oklch(0.205 0 0);
  --muted: oklch(0.97 0 0);
  --muted-foreground: oklch(0.556 0 0);
  --accent: oklch(0.97 0 0);
  --accent-foreground: oklch(0.205 0 0);
  --destructive: oklch(0.577 0.245 27.325);
  --border: oklch(0.922 0 0);
  --input: oklch(0.922 0 0);
  --ring: oklch(0.708 0 0);
}

.dark {
  --background: oklch(0.145 0 0);
  --foreground: oklch(0.985 0 0);
  --card: oklch(0.205 0 0);
  --card-foreground: oklch(0.985 0 0);
  --popover: oklch(0.205 0 0);
  --popover-foreground: oklch(0.985 0 0);
  --primary: oklch(0.985 0 0);
  --primary-foreground: oklch(0.205 0 0);
  --secondary: oklch(0.269 0 0);
  --secondary-foreground: oklch(0.985 0 0);
  --muted: oklch(0.269 0 0);
  --muted-foreground: oklch(0.708 0 0);
  --accent: oklch(0.269 0 0);
  --accent-foreground: oklch(0.985 0 0);
  --destructive: oklch(0.396 0.141 25.723);
  --border: oklch(1 0 0 / 10%);
  --input: oklch(1 0 0 / 15%);
  --ring: oklch(0.556 0 0);
}

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-card: var(--card);
  --color-card-foreground: var(--card-foreground);
  --color-popover: var(--popover);
  --color-popover-foreground: var(--popover-foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-secondary: var(--secondary);
  --color-secondary-foreground: var(--secondary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-accent: var(--accent);
  --color-accent-foreground: var(--accent-foreground);
  --color-destructive: var(--destructive);
  --color-border: var(--border);
  --color-input: var(--input);
  --color-ring: var(--ring);
  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
  --radius-xl: calc(var(--radius) + 4px);
}

* {
  border-color: var(--border);
  outline-color: var(--ring);
}

body {
  background-color: var(--background);
  color: var(--foreground);
}
```

---

## .env.example

```bash
# API 서버 URL (개발: Spring Boot, 운영: 실제 서버)
NUXT_PUBLIC_API_BASE=http://localhost:7171
```
