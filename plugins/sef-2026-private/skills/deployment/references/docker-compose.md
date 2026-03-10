# Docker Compose 로컬 개발 환경 가이드

민간 섹터 프로젝트의 Docker Compose를 사용한 로컬 개발 환경 구성 가이드입니다.

## 개요

Docker Compose를 사용하면 백엔드, 프론트엔드, 데이터베이스, 캐시 등 모든 서비스를 한 번에 실행할 수 있습니다.

## 기본 구조

```
project/
├── backend/
│   └── Dockerfile
├── frontend/
│   └── Dockerfile
├── docker-compose.yml
├── docker-compose.dev.yml
├── docker-compose.prod.yml
└── .env
```

## docker-compose.yml (기본)

```yaml
version: '3.8'

services:
  # 백엔드 서비스 (Spring Boot)
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: myapp-backend
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=${SPRING_PROFILES_ACTIVE:-dev}
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=${DB_NAME:-mydb}
      - DB_USER=${DB_USER:-user}
      - DB_PASSWORD=${DB_PASSWORD:-password}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    volumes:
      - ./backend/logs:/app/logs
    networks:
      - myapp-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # 프론트엔드 서비스 (Nuxt 4)
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: myapp-frontend
    ports:
      - "3000:3000"
    environment:
      - NUXT_PUBLIC_API_BASE_URL=http://backend:8080/api
      - NODE_ENV=${NODE_ENV:-development}
    depends_on:
      - backend
    volumes:
      - ./frontend:/app
      - /app/node_modules
      - /app/.nuxt
    networks:
      - myapp-network
    restart: unless-stopped

  # PostgreSQL 데이터베이스
  postgres:
    image: postgres:15-alpine
    container_name: myapp-postgres
    ports:
      - "5432:5432"
    environment:
      - POSTGRES_DB=${DB_NAME:-mydb}
      - POSTGRES_USER=${DB_USER:-user}
      - POSTGRES_PASSWORD=${DB_PASSWORD:-password}
      - POSTGRES_INITDB_ARGS=--encoding=UTF-8
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./backend/init-scripts:/docker-entrypoint-initdb.d
    networks:
      - myapp-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER:-user}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis 캐시
  redis:
    image: redis:7-alpine
    container_name: myapp-redis
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    networks:
      - myapp-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

  # Nginx 리버스 프록시
  nginx:
    image: nginx:alpine
    container_name: myapp-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - backend
      - frontend
    networks:
      - myapp-network
    restart: unless-stopped

  # pgAdmin (데이터베이스 관리 도구)
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: myapp-pgadmin
    ports:
      - "5050:80"
    environment:
      - PGADMIN_DEFAULT_EMAIL=${PGADMIN_EMAIL:-admin@example.com}
      - PGADMIN_DEFAULT_PASSWORD=${PGADMIN_PASSWORD:-admin}
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    networks:
      - myapp-network
    restart: unless-stopped

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  pgadmin_data:
    driver: local

networks:
  myapp-network:
    driver: bridge
```

## docker-compose.dev.yml (개발 환경)

```yaml
version: '3.8'

services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile.dev
    volumes:
      - ./backend/src:/app/src
      - ./backend/target:/app/target
    environment:
      - SPRING_PROFILES_ACTIVE=dev
      - SPRING_DEVTOOLS_RESTART_ENABLED=true
    command: ./mvnw spring-boot:run

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile.dev
    volumes:
      - ./frontend:/app
      - /app/node_modules
      - /app/.nuxt
    environment:
      - NODE_ENV=development
    command: pnpm dev

  # Mailhog (이메일 테스트)
  mailhog:
    image: mailhog/mailhog:latest
    container_name: myapp-mailhog
    ports:
      - "1025:1025" # SMTP
      - "8025:8025" # Web UI
    networks:
      - myapp-network
```

## docker-compose.prod.yml (프로덕션)

```yaml
version: '3.8'

services:
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
      args:
        - MAVEN_OPTS=-Dmaven.test.skip=true
    environment:
      - SPRING_PROFILES_ACTIVE=prod
      - JAVA_OPTS=-Xms512m -Xmx1024m
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1024M
        reservations:
          cpus: '0.5'
          memory: 512M

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
      args:
        - NODE_ENV=production
    environment:
      - NODE_ENV=production
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M

  postgres:
    volumes:
      - /data/postgres:/var/lib/postgresql/data
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2048M
```

## Dockerfile 예시

### backend/Dockerfile

```dockerfile
# Multi-stage build
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar

# 비-root 사용자로 실행
RUN addgroup -g 1000 appuser && \
    adduser -u 1000 -G appuser -s /bin/sh -D appuser
USER appuser

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
```

### backend/Dockerfile.dev

```dockerfile
FROM maven:3.9-eclipse-temurin-17
WORKDIR /app

# 의존성 캐싱
COPY pom.xml .
RUN mvn dependency:go-offline

COPY . .

CMD ["./mvnw", "spring-boot:run"]
```

### frontend/Dockerfile

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app

# 의존성 설치
COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile

# 빌드
COPY . .
RUN pnpm build

# Production stage
FROM node:20-alpine
WORKDIR /app

# 비-root 사용자
RUN addgroup -g 1000 appuser && \
    adduser -u 1000 -G appuser -s /bin/sh -D appuser

COPY --from=builder --chown=appuser:appuser /app/.output ./

USER appuser

EXPOSE 3000

ENV NUXT_HOST=0.0.0.0
ENV NUXT_PORT=3000

CMD ["node", "server/index.mjs"]
```

### frontend/Dockerfile.dev

```dockerfile
FROM node:20-alpine
WORKDIR /app

COPY package.json pnpm-lock.yaml ./
RUN npm install -g pnpm && pnpm install

COPY . .

EXPOSE 3000

CMD ["pnpm", "dev"]
```

## 환경변수 (.env)

```bash
# 애플리케이션
SPRING_PROFILES_ACTIVE=dev
NODE_ENV=development

# 데이터베이스
DB_NAME=mydb
DB_USER=user
DB_PASSWORD=password

# pgAdmin
PGADMIN_EMAIL=admin@example.com
PGADMIN_PASSWORD=admin

# JWT
JWT_SECRET=your-secret-key-here
JWT_EXPIRATION=86400000

# AWS (선택사항)
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_REGION=ap-northeast-2

# OAuth (선택사항)
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=
```

## 실행 명령어

### 개발 환경 실행

```bash
# 모든 서비스 실행
docker-compose up

# 백그라운드 실행
docker-compose up -d

# 특정 서비스만 실행
docker-compose up backend postgres

# 개발 환경 오버라이드
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up

# 빌드 후 실행
docker-compose up --build

# 특정 서비스 재빌드
docker-compose up --build backend
```

### 프로덕션 환경 실행

```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### 서비스 관리

```bash
# 서비스 중지
docker-compose stop

# 서비스 시작
docker-compose start

# 서비스 재시작
docker-compose restart backend

# 서비스 제거 (볼륨 유지)
docker-compose down

# 서비스 제거 (볼륨 포함)
docker-compose down -v

# 로그 확인
docker-compose logs -f backend

# 특정 서비스의 셸 접속
docker-compose exec backend /bin/sh
docker-compose exec postgres psql -U user -d mydb
```

### 데이터베이스 작업

```bash
# PostgreSQL 접속
docker-compose exec postgres psql -U user -d mydb

# 데이터베이스 백업
docker-compose exec postgres pg_dump -U user mydb > backup.sql

# 데이터베이스 복원
docker-compose exec -T postgres psql -U user -d mydb < backup.sql

# Redis CLI 접속
docker-compose exec redis redis-cli
```

## 유용한 스크립트

### scripts/docker-dev.sh

```bash
#!/bin/bash

# 개발 환경 시작
echo "Starting development environment..."
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# 로그 출력
echo "Showing logs..."
docker-compose logs -f
```

### scripts/docker-clean.sh

```bash
#!/bin/bash

# 모든 컨테이너 중지 및 제거
echo "Stopping and removing containers..."
docker-compose down -v

# 이미지 제거
echo "Removing images..."
docker-compose down --rmi all

# 사용하지 않는 볼륨 제거
echo "Removing unused volumes..."
docker volume prune -f

# 사용하지 않는 네트워크 제거
echo "Removing unused networks..."
docker network prune -f

echo "Cleanup complete!"
```

### scripts/docker-rebuild.sh

```bash
#!/bin/bash

SERVICE=$1

if [ -z "$SERVICE" ]; then
  echo "Usage: ./docker-rebuild.sh <service-name>"
  echo "Example: ./docker-rebuild.sh backend"
  exit 1
fi

echo "Rebuilding $SERVICE..."
docker-compose stop $SERVICE
docker-compose rm -f $SERVICE
docker-compose build --no-cache $SERVICE
docker-compose up -d $SERVICE
docker-compose logs -f $SERVICE
```

## 헬스체크 및 의존성

### 헬스체크 설정

```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### 서비스 의존성

```yaml
depends_on:
  postgres:
    condition: service_healthy
  redis:
    condition: service_started
```

## 네트워크 설정

### 커스텀 네트워크

```yaml
networks:
  frontend-network:
    driver: bridge
  backend-network:
    driver: bridge
    internal: true # 외부 접근 차단

services:
  frontend:
    networks:
      - frontend-network
      - backend-network

  backend:
    networks:
      - backend-network

  postgres:
    networks:
      - backend-network
```

## 볼륨 관리

### Named 볼륨 vs Bind 마운트

```yaml
volumes:
  # Named 볼륨 (프로덕션)
  postgres_data:
    driver: local

services:
  postgres:
    volumes:
      # Named 볼륨
      - postgres_data:/var/lib/postgresql/data
      # Bind 마운트 (개발)
      - ./init-scripts:/docker-entrypoint-initdb.d
```

## 성능 최적화

### 1. 빌드 캐시 활용

```dockerfile
# 의존성 먼저 복사 (캐시 활용)
COPY package.json pnpm-lock.yaml ./
RUN pnpm install

# 소스코드 나중에 복사
COPY . .
```

### 2. Multi-stage 빌드

```dockerfile
FROM maven:3.9-eclipse-temurin-17 AS builder
# 빌드...

FROM eclipse-temurin:17-jre-alpine
# 런타임만...
```

### 3. .dockerignore 활용

```
# .dockerignore
node_modules
.git
.env
*.log
target
dist
.nuxt
```

## 트러블슈팅

### 포트 충돌

```bash
# 사용 중인 포트 확인
lsof -i :8080
netstat -ano | findstr :8080

# 포트 변경
ports:
  - "8081:8080"
```

### 볼륨 권한 문제

```bash
# Linux/macOS
sudo chown -R $USER:$USER ./data

# 또는 Dockerfile에서
RUN chmod -R 755 /app/data
```

### 네트워크 연결 실패

```bash
# 네트워크 재생성
docker-compose down
docker network prune -f
docker-compose up
```

### 컨테이너가 즉시 종료됨

```bash
# 로그 확인
docker-compose logs backend

# 컨테이너 상태 확인
docker-compose ps
```

## 모범 사례

1. **환경변수 사용**: 하드코딩 금지
2. **헬스체크 설정**: 서비스 상태 모니터링
3. **볼륨 사용**: 데이터 영속성
4. **네트워크 분리**: 보안 강화
5. **리소스 제한**: 메모리, CPU 제한
6. **.dockerignore**: 불필요한 파일 제외
7. **멀티 스테이지 빌드**: 이미지 크기 최소화
8. **비-root 사용자**: 보안 강화

## 참고 자료

- [Docker Compose 공식 문서](https://docs.docker.com/compose/)
- [Docker 베스트 프랙티스](https://docs.docker.com/develop/dev-best-practices/)
- 관련 스크립트: `scripts/build_containers.sh`
