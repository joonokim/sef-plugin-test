# Docker 설정 및 최적화

## Dockerfile (Multi-stage Build)

### 최적화된 Dockerfile

```dockerfile
# Build stage
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app

# Maven Wrapper 복사
COPY mvnw .
COPY .mvn .mvn

# pom.xml만 먼저 복사하여 의존성 캐싱
COPY pom.xml .
RUN ./mvnw dependency:go-offline

# 소스 코드 복사 및 빌드
COPY src ./src
RUN ./mvnw clean package -DskipTests

# Production stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# 비root 사용자 생성
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# JAR 파일 복사
COPY --from=builder /app/target/*.jar app.jar

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Gradle 버전

```dockerfile
# Build stage
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app

# Gradle Wrapper 복사
COPY gradlew .
COPY gradle gradle

# build.gradle만 먼저 복사
COPY build.gradle settings.gradle ./
RUN ./gradlew dependencies --no-daemon

# 소스 코드 복사 및 빌드
COPY src ./src
RUN ./gradlew build -x test --no-daemon

# Production stage
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

COPY --from=builder /app/build/libs/*.jar app.jar

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

## Docker Compose

### 전체 스택 구성

```yaml
version: '3.8'

services:
  # Backend API
  backend:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: backend
    ports:
      - "8080:8080"
    environment:
      - SPRING_PROFILES_ACTIVE=dev
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=mydb
      - DB_USER=user
      - DB_PASSWORD=password
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - JWT_SECRET=your-secret-key
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: postgres
    environment:
      - POSTGRES_DB=mydb
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./init-scripts:/docker-entrypoint-initdb.d
    networks:
      - app-network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d mydb"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    networks:
      - app-network
    restart: unless-stopped
    command: redis-server --appendonly yes

  # Nginx Reverse Proxy (선택사항)
  nginx:
    image: nginx:alpine
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl:/etc/nginx/ssl
    depends_on:
      - backend
    networks:
      - app-network
    restart: unless-stopped

networks:
  app-network:
    driver: bridge

volumes:
  postgres_data:
  redis_data:
```

### 개발 환경용 (docker-compose.dev.yml)

```yaml
version: '3.8'

services:
  backend:
    build:
      context: .
      target: builder  # 개발용 스테이지
    volumes:
      - ./src:/app/src  # 소스 코드 핫 리로드
    environment:
      - SPRING_PROFILES_ACTIVE=dev
      - SPRING_DEVTOOLS_RESTART_ENABLED=true
    command: ./mvnw spring-boot:run

  postgres:
    ports:
      - "5432:5432"  # 로컬에서 직접 접근 가능

  redis:
    ports:
      - "6379:6379"  # 로컬에서 직접 접근 가능
```

사용:
```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up
```

## .dockerignore

```
# Maven
target/
!target/*.jar
pom.xml.tag
pom.xml.releaseBackup
pom.xml.versionsBackup
pom.xml.next
release.properties

# Gradle
.gradle
build/
!build/libs/*.jar

# IDE
.idea/
*.iml
.vscode/
*.swp
*.swo

# Git
.git/
.gitignore

# Logs
*.log

# OS
.DS_Store
Thumbs.db

# Env
.env
.env.local

# Docs
README.md
docs/
```

## Docker 빌드 및 실행

### 로컬 빌드

```bash
# 이미지 빌드
docker build -t backend:latest .

# 컨테이너 실행
docker run -d \
  --name backend \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=prod \
  -e DB_HOST=host.docker.internal \
  backend:latest

# 로그 확인
docker logs -f backend

# 컨테이너 중지
docker stop backend

# 컨테이너 제거
docker rm backend
```

### Docker Compose 사용

```bash
# 모든 서비스 시작
docker-compose up -d

# 특정 서비스만 시작
docker-compose up -d backend postgres

# 로그 확인
docker-compose logs -f backend

# 서비스 중지
docker-compose down

# 볼륨까지 삭제
docker-compose down -v

# 서비스 재시작
docker-compose restart backend
```

## 최적화 팁

### 1. 레이어 캐싱 활용

의존성 다운로드와 소스 코드 빌드를 분리하여 캐싱 효율 극대화

```dockerfile
# 의존성만 먼저 다운로드 (캐싱)
COPY pom.xml .
RUN ./mvnw dependency:go-offline

# 이후 소스 코드 복사
COPY src ./src
RUN ./mvnw package
```

### 2. Multi-stage Build

빌드 도구는 최종 이미지에 포함하지 않음

```dockerfile
FROM eclipse-temurin:17-jdk-alpine AS builder
# 빌드 수행

FROM eclipse-temurin:17-jre-alpine
# JRE만 사용하여 이미지 크기 감소
COPY --from=builder /app/target/*.jar app.jar
```

### 3. Alpine Linux 사용

```dockerfile
# 일반 이미지: ~300MB
FROM eclipse-temurin:17-jre

# Alpine 이미지: ~150MB
FROM eclipse-temurin:17-jre-alpine
```

### 4. 비root 사용자 실행

```dockerfile
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring
```

### 5. Health Check 추가

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD wget --spider http://localhost:8080/actuator/health || exit 1
```

## Spring Boot Actuator 설정

### pom.xml

```xml
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

### application.yml

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      show-details: when-authorized
```

## 프로덕션 환경 설정

### JVM 옵션

```dockerfile
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

### 환경변수 주입

```bash
docker run -d \
  --name backend \
  -p 8080:8080 \
  -e SPRING_PROFILES_ACTIVE=prod \
  -e JAVA_OPTS="-Xmx512m -Xms256m" \
  -e DB_HOST=prod-db.example.com \
  -e DB_PASSWORD=$(cat /run/secrets/db-password) \
  backend:latest
```

## 트러블슈팅

### 컨테이너가 즉시 종료되는 경우

```bash
# 로그 확인
docker logs backend

# 인터랙티브 모드로 실행
docker run -it backend:latest sh
```

### 네트워크 연결 문제

```bash
# 네트워크 확인
docker network inspect app-network

# 컨테이너 IP 확인
docker inspect backend | grep IPAddress
```

### 볼륨 권한 문제

```bash
# 볼륨 상세 정보
docker volume inspect postgres_data

# 권한 수정 (필요시)
docker-compose down
sudo chown -R $USER:$USER ./volumes/
docker-compose up -d
```

## 참고 자료

- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Spring Boot Docker Guide](https://spring.io/guides/topicals/spring-boot-docker/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
