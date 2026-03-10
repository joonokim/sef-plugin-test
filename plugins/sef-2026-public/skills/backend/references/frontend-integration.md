# Frontend Integration Reference

## Project Structure

The frontend lives at `frontend/` in the project root (NOT inside `src/`). It is a Nuxt 4 SPA that gets built into static assets and served by Spring Boot.

```
sqisoft-sef-2026/
├── frontend/          # Nuxt 4 SPA source
│   ├── app/
│   ├── nuxt.config.ts
│   └── package.json
└── src/main/
    └── resources/
        └── static/    # Built frontend output goes here
```

## nuxt.config.ts Key Settings

Actual modules list from source:

```typescript
modules: ['@pinia/nuxt', '@nuxtjs/tailwindcss', 'shadcn-nuxt', '@vueuse/nuxt', '@nuxt/icon']
```

- UI library: **shadcn-vue** (via `shadcn-nuxt`). NOT `@nuxt/ui`.
- CSS: **TailwindCSS** via `@nuxtjs/tailwindcss`
- State: **Pinia** via `@pinia/nuxt`
- Icons: `@nuxt/icon`
- Utilities: `@vueuse/nuxt`
- TypeScript strict mode enabled, typeCheck disabled in dev for performance
- Nuxt 4 compatibility: `future: { compatibilityVersion: 4 }`
- shadcn component dir: `./components/ui`, no prefix

## Package Manager

**pnpm** -- NOT npm, NOT yarn.

```bash
pnpm install
pnpm run dev       # Dev server on http://localhost:3000
pnpm run build     # Production build
pnpm run lint      # ESLint check
```

## Build and Deploy Process

1. Build the frontend SPA:
   ```bash
   cd frontend
   pnpm install
   pnpm run build
   ```
   Output lands in `frontend/.output/public/` (contains `index.html` + `assets/`).

2. Copy built assets into Spring Boot static resources:
   ```bash
   # Copy frontend/.output/public/* -> src/main/resources/static/
   ```

3. Build the Spring Boot application:
   ```bash
   ./gradlew clean build -x test
   ```

4. The resulting WAR/JAR serves both the API and the SPA from a single deployment.

## SPA Routing Configuration

`WebConfig` (`infra/security/config/WebConfig.java`) handles SPA client-side routing fallback. This is the actual class in the codebase (there is no separate `SpaRoutingConfig`):

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        registry.addResourceHandler("/**")
            .addResourceLocations("classpath:/static/")
            .resourceChain(true)
            .addResolver(new PathResourceResolver() {
                @Override
                protected Resource getResource(String resourcePath, Resource location) throws IOException {
                    Resource requested = location.createRelative(resourcePath);
                    return requested.exists() && requested.isReadable()
                        ? requested
                        : new ClassPathResource("/static/index.html");
                }
            });
    }

    @Override
    public void addViewControllers(ViewControllerRegistry registry) {
        registry.addViewController("/").setViewName("forward:/index.html");
        registry.setOrder(Ordered.HIGHEST_PRECEDENCE);
    }
}
```

Any request that does not match a static file or `/api/**` is forwarded to `index.html`, letting Vue Router handle it. CORS is also configured in this same class.

## Development Environment

| Service | URL | Notes |
|---------|-----|-------|
| Spring Boot | `http://localhost:7171` | Backend API server |
| Nuxt dev | `http://localhost:3000` | Frontend dev server with HMR |

Vite proxy in `nuxt.config.ts` forwards `/api` requests to the backend during development:

```typescript
vite: {
  server: {
    proxy: {
      '/api': {
        target: process.env.NUXT_DEV_PROXY_TARGET || 'http://localhost:7171',
        changeOrigin: true,
      },
    },
  },
},
```

The proxy default matches the actual Spring Boot port (7171). Override with `NUXT_DEV_PROXY_TARGET` env var if needed.

Runtime config for the API base URL:
```typescript
runtimeConfig: {
  public: {
    apiBase: process.env.NUXT_PUBLIC_API_BASE || '/api',
  },
},
```

## Troubleshooting

- If SPA routes return 404 in production, verify `WebConfig` is active and `src/main/resources/static/index.html` exists.
- If API calls fail in dev, ensure `NUXT_DEV_PROXY_TARGET` matches Spring Boot port (7171).
- If styles break after build, confirm `pnpm run build` completed without errors and assets were copied to `static/`.
- Swagger UI is only available in `local`/`dev` profiles at `http://localhost:7171/swagger-ui/index.html`.
