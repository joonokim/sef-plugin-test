# 민간 프로젝트 프론트엔드 배포 (Docker)

## 개요

민간 프로젝트의 프론트엔드는 **독립된 Docker 컨테이너**로 배포됩니다.

## 프로젝트 위치

```
frontend/                         # 독립 프로젝트
├── app/
├── nuxt.config.ts
├── package.json
├── Dockerfile                    # Docker 이미지 빌드
└── .env.production               # 운영 환경 변수
```

## Dockerfile

```dockerfile
# Build stage
FROM node:20-alpine AS builder

WORKDIR /app

# 의존성 설치
COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile

# 애플리케이션 빌드
COPY . .
RUN pnpm build

# Production stage
FROM node:20-alpine

WORKDIR /app

# 빌드된 파일 복사
COPY --from=builder /app/.output ./

EXPOSE 3000

ENV NUXT_HOST=0.0.0.0
ENV NUXT_PORT=3000
ENV NODE_ENV=production

CMD ["node", "server/index.mjs"]
```

## 빌드 및 실행

### 로컬 빌드

```bash
# 프로덕션 빌드
pnpm build

# 미리보기 (SSR 모드)
pnpm preview
```

### Docker 빌드

```bash
# 이미지 빌드
docker build -t frontend:latest .

# 컨테이너 실행
docker run -p 3000:3000 \
  -e NUXT_PUBLIC_API_BASE=http://api.example.com \
  frontend:latest
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    environment:
      - NUXT_PUBLIC_API_BASE=http://backend:8080/api
    depends_on:
      - backend
    networks:
      - app-network

  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "8080:8080"
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
```

## Kubernetes 배포

### deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  labels:
    app: frontend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: your-registry/frontend:latest
        ports:
        - containerPort: 3000
        env:
        - name: NUXT_PUBLIC_API_BASE
          value: "http://backend-service:8080/api"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  selector:
    app: frontend
  ports:
  - protocol: TCP
    port: 80
    targetPort: 3000
  type: LoadBalancer
```

## CI/CD 파이프라인 (.github/workflows/deploy.yml)

```yaml
name: Deploy Frontend

on:
  push:
    branches: [ main ]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Set up Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '20'

    - name: Install pnpm
      run: npm install -g pnpm

    - name: Install dependencies
      working-directory: ./frontend
      run: pnpm install --frozen-lockfile

    - name: Build
      working-directory: ./frontend
      run: pnpm build

    - name: Build Docker image
      working-directory: ./frontend
      run: docker build -t ${{ secrets.REGISTRY }}/frontend:${{ github.sha }} .

    - name: Push Docker image
      run: docker push ${{ secrets.REGISTRY }}/frontend:${{ github.sha }}

    - name: Deploy to Kubernetes
      run: |
        kubectl set image deployment/frontend \
          frontend=${{ secrets.REGISTRY }}/frontend:${{ github.sha }}
```

## 환경 변수

운영 환경에서는 환경 변수로 설정을 주입합니다:

```bash
# Docker 실행 시
docker run -p 3000:3000 \
  -e NUXT_PUBLIC_API_BASE=https://api.prod.example.com/api \
  -e NUXT_PUBLIC_APP_NAME="Production App" \
  frontend:latest

# Kubernetes
kubectl set env deployment/frontend \
  NUXT_PUBLIC_API_BASE=https://api.prod.example.com/api
```

## Nginx 리버스 프록시 (선택사항)

```nginx
server {
    listen 80;
    server_name example.com;

    location / {
        proxy_pass http://frontend:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## 모니터링

### Health Check

```typescript
// server/api/health.ts
export default defineEventHandler(() => {
  return {
    status: 'ok',
    timestamp: new Date().toISOString(),
  }
})
```

### Dockerfile에 Health Check 추가

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"
```

## 참고 자료

- `deployment-public.md`: 공공 프로젝트 배포 (WAR)
- Docker 공식 문서
- Kubernetes 공식 문서
