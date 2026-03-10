---
name: deployment
description: 민간 서비스 배포 가이드. Docker 빌드 및 배포, Kubernetes 오케스트레이션, AWS 배포 (ECS, EKS, EC2), CI/CD 파이프라인, Nginx 리버스 프록시. 민간 프로젝트를 클라우드에 배포할 때 사용.
---

# 민간 서비스 배포

## 개요

민간 기업 프로젝트의 배포 가이드입니다. Docker를 사용하여 백엔드와 프론트엔드를 독립적으로 배포하며, AWS, Kubernetes 등 다양한 인프라를 지원합니다.

## 배포 전략

### 1. Docker 기반 배포

백엔드와 프론트엔드를 각각 Docker 이미지로 빌드하여 배포

### 2. Kubernetes 오케스트레이션

마이크로서비스 환경에서 자동 스케일링, 무중단 배포

### 3. AWS 배포

- **ECS**: Docker 컨테이너 오케스트레이션
- **EKS**: Kubernetes 관리형 서비스
- **EC2**: 전통적인 VM 배포
- **S3 + CloudFront**: 프론트엔드 정적 배포

### 4. CI/CD 파이프라인

GitHub Actions, GitLab CI, Jenkins 등을 통한 자동 빌드 및 배포

## 배포 프로세스

### 백엔드 배포

#### 1. Docker 이미지 빌드

```bash
cd backend
docker build -t myapp-backend:latest .
docker tag myapp-backend:latest <registry>/myapp-backend:latest
docker push <registry>/myapp-backend:latest
```

#### 2. AWS ECS 배포

```bash
# ECS 클러스터 생성
aws ecs create-cluster --cluster-name myapp-cluster

# 태스크 정의 등록
aws ecs register-task-definition --cli-input-json file://task-definition.json

# 서비스 생성
aws ecs create-service \
  --cluster myapp-cluster \
  --service-name myapp-backend \
  --task-definition myapp-backend:1 \
  --desired-count 2 \
  --launch-type FARGATE
```

자세한 내용은 `scripts/deploy_backend.sh` 참조

### 프론트엔드 배포

#### Option 1: S3 + CloudFront (정적 배포)

```bash
# Nuxt 4 정적 빌드
npm run generate

# S3 업로드
aws s3 sync .output/public s3://myapp-frontend --delete

# CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id E1234567890 \
  --paths "/*"
```

#### Option 2: Docker 컨테이너 배포

```bash
# Docker 이미지 빌드
docker build -t myapp-frontend:latest .
docker push <registry>/myapp-frontend:latest

# ECS 배포
aws ecs update-service \
  --cluster myapp-cluster \
  --service myapp-frontend \
  --force-new-deployment
```

자세한 내용은 `scripts/deploy_frontend.sh` 참조

## Docker Compose (로컬 개발)

```yaml
version: '3.8'

services:
  backend:
    build: ./backend
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=dev
      - DB_HOST=postgres
      - REDIS_HOST=redis
    depends_on:
      - postgres
      - redis

  frontend:
    build: ./frontend
    ports:
      - "3000:3000"
    environment:
      - NUXT_PUBLIC_API_BASE_URL=http://backend:8080/api
    depends_on:
      - backend

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=mydb
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - backend
      - frontend

volumes:
  postgres_data:
```

## Kubernetes 배포

### Backend Deployment

```yaml
# k8s/backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: <registry>/myapp-backend:latest
        ports:
        - containerPort: 8080
        env:
        - name: SPRING_PROFILES_ACTIVE
          value: "prod"
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: db-host
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  selector:
    app: backend
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
  type: LoadBalancer
```

### Frontend Deployment

```yaml
# k8s/frontend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
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
        image: <registry>/myapp-frontend:latest
        ports:
        - containerPort: 3000
        env:
        - name: NUXT_PUBLIC_API_BASE_URL
          value: "http://backend-service:8080/api"
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

### 배포 명령

```bash
# ConfigMap 생성
kubectl create configmap app-config --from-file=config/

# Secret 생성
kubectl create secret generic app-secrets \
  --from-literal=db-password=yourpassword

# 배포
kubectl apply -f k8s/backend-deployment.yaml
kubectl apply -f k8s/frontend-deployment.yaml

# 상태 확인
kubectl get pods
kubectl get services
```

자세한 내용은 `references/kubernetes.md` 참조

## CI/CD 파이프라인

### GitHub Actions

```yaml
# .github/workflows/backend-ci.yml
name: Backend CI/CD

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Build with Maven
        working-directory: ./backend
        run: mvn clean package -DskipTests

      - name: Build Docker image
        working-directory: ./backend
        run: |
          docker build -t ${{ secrets.ECR_REGISTRY }}/backend:${{ github.sha }} .
          docker tag ${{ secrets.ECR_REGISTRY }}/backend:${{ github.sha }} \
                     ${{ secrets.ECR_REGISTRY }}/backend:latest

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-2

      - name: Push to ECR
        run: |
          aws ecr get-login-password | docker login --username AWS --password-stdin ${{ secrets.ECR_REGISTRY }}
          docker push ${{ secrets.ECR_REGISTRY }}/backend:${{ github.sha }}
          docker push ${{ secrets.ECR_REGISTRY }}/backend:latest

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster myapp-cluster \
            --service backend \
            --force-new-deployment
```

자세한 내용은 `references/ci-cd-pipeline.md` 참조

## Nginx 리버스 프록시

```nginx
# nginx.conf
upstream backend {
    server backend:8080;
}

upstream frontend {
    server frontend:3000;
}

server {
    listen 80;
    server_name example.com;

    # Frontend
    location / {
        proxy_pass http://frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Backend API
    location /api {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

자세한 내용은 `references/nginx-config.md` 참조

## 배포 체크리스트

### 백엔드

- [ ] 환경변수 설정 완료
- [ ] 데이터베이스 마이그레이션 완료
- [ ] Docker 이미지 빌드 및 푸시 완료
- [ ] Health check 엔드포인트 동작 확인
- [ ] 로그 모니터링 설정 완료

### 프론트엔드

- [ ] 환경변수 설정 완료
- [ ] API 엔드포인트 URL 확인
- [ ] Docker 이미지 빌드 및 푸시 완료 (또는 S3 업로드)
- [ ] 빌드 최적화 확인
- [ ] CDN 캐시 무효화 완료

### 인프라

- [ ] 로드 밸런서 설정 완료
- [ ] SSL 인증서 적용 완료
- [ ] 도메인 연결 완료
- [ ] 모니터링 및 알림 설정 완료
- [ ] 백업 정책 설정 완료

## 배포 전략

### Blue-Green 배포

새 버전을 별도 환경에 배포 후, 트래픽을 전환

### Canary 배포

새 버전을 일부 사용자에게만 배포하여 테스트

### Rolling Update

순차적으로 인스턴스를 업데이트

자세한 내용은 각 `references/` 파일 참조

## 트러블슈팅

### CORS 에러 발생 시

백엔드에서 CORS 설정 확인:

```java
@Configuration
public class WebConfig implements WebMvcConfigurer {
    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins("https://example.com")
                .allowedMethods("GET", "POST", "PUT", "DELETE")
                .allowCredentials(true);
    }
}
```

### 프론트엔드 환경변수가 적용되지 않는 경우

- Nuxt: `NUXT_PUBLIC_` 접두사 확인
- React: `VITE_` 접두사 확인
- 빌드 시점에 주입되므로 재빌드 필요

## 참고 자료

- `references/aws-deployment.md`: AWS 배포 상세 가이드
- `references/docker-compose.md`: Docker Compose 설정
- `references/kubernetes.md`: Kubernetes 배포 가이드
- `references/ci-cd-pipeline.md`: CI/CD 파이프라인 구축
- `references/nginx-config.md`: Nginx 설정 가이드
- `scripts/build_containers.sh`: Docker 이미지 빌드 스크립트
- `scripts/deploy_backend.sh`: 백엔드 배포 스크립트
- `scripts/deploy_frontend.sh`: 프론트엔드 배포 스크립트

## 관련 스킬

- `project-init`: 프로젝트 초기화
- `backend`: 백엔드 개발
- `frontend` (sef-2026 플러그인): 공통 프론트엔드 개발
