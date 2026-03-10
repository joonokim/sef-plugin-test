---
name: backend
description: 민간 서비스 백엔드 구조 및 개발. Spring Boot API 서버 (JAR), JPA/Hibernate, Redis 캐싱, Docker 컨테이너화, RESTful API 설계. 민간 프로젝트의 독립된 백엔드 개발 시 사용.
---

# 민간 서비스 백엔드

## 개요

민간 기업 프로젝트의 백엔드 구조 및 개발 가이드입니다. Spring Boot를 기반으로 하며, JAR로 패키징하여 독립 실행하거나 Docker 컨테이너로 배포합니다.

## 주요 기능

- Spring Boot API 서버 (JAR 패키징)
- JPA/Hibernate ORM
- RESTful API 설계
- Redis 캐싱
- Docker 컨테이너화
- JWT 인증
- PostgreSQL/MySQL 데이터베이스 연동

## 폴더 구조

```
backend/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/example/project/
│   │   │       ├── ProjectApplication.java
│   │   │       ├── config/              # 설정 클래스
│   │   │       │   ├── SecurityConfig.java
│   │   │       │   ├── RedisConfig.java
│   │   │       │   └── JpaConfig.java
│   │   │       ├── controller/          # REST 컨트롤러
│   │   │       │   ├── AuthController.java
│   │   │       │   └── BoardController.java
│   │   │       ├── service/             # 비즈니스 로직
│   │   │       │   ├── AuthService.java
│   │   │       │   └── BoardService.java
│   │   │       ├── repository/          # JPA 리포지토리
│   │   │       │   ├── UserRepository.java
│   │   │       │   └── BoardRepository.java
│   │   │       ├── domain/              # 엔티티 (JPA)
│   │   │       │   ├── User.java
│   │   │       │   └── Board.java
│   │   │       ├── dto/                 # 데이터 전송 객체
│   │   │       │   ├── request/
│   │   │       │   └── response/
│   │   │       ├── security/            # 보안 관련
│   │   │       │   ├── JwtTokenProvider.java
│   │   │       │   └── JwtAuthenticationFilter.java
│   │   │       ├── exception/           # 예외 처리
│   │   │       │   ├── GlobalExceptionHandler.java
│   │   │       │   └── CustomException.java
│   │   │       └── util/                # 유틸리티
│   │   └── resources/
│   │       ├── application.yml          # 기본 설정
│   │       ├── application-dev.yml      # 개발 환경
│   │       ├── application-prod.yml     # 운영 환경
│   │       └── logback-spring.xml       # 로그 설정
│   └── test/
│       └── java/
│           └── com/example/project/
│               ├── controller/
│               ├── service/
│               └── repository/
├── Dockerfile
├── docker-compose.yml
├── pom.xml (또는 build.gradle)
└── README.md
```

## 주요 설정

### application.yml

```yaml
spring:
  application:
    name: project-backend

  datasource:
    driver-class-name: org.postgresql.Driver
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:mydb}
    username: ${DB_USER:user}
    password: ${DB_PASSWORD:password}
    hikari:
      maximum-pool-size: 10

  jpa:
    hibernate:
      ddl-auto: validate
    show-sql: false
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
        format_sql: true

  data:
    redis:
      host: ${REDIS_HOST:localhost}
      port: ${REDIS_PORT:6379}

server:
  port: 8080

jwt:
  secret: ${JWT_SECRET:your-secret-key}
  expiration: 86400000  # 24시간

logging:
  level:
    root: INFO
    com.example.project: DEBUG
```

### pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project>
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
    </parent>

    <groupId>com.example</groupId>
    <artifactId>project-backend</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <dependencies>
        <!-- Spring Boot Starter Web -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>

        <!-- Spring Boot Starter Data JPA -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>

        <!-- Spring Boot Starter Security -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-security</artifactId>
        </dependency>

        <!-- Spring Boot Starter Redis -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>

        <!-- PostgreSQL Driver -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>

        <!-- JWT -->
        <dependency>
            <groupId>io.jsonwebtoken</groupId>
            <artifactId>jjwt</artifactId>
            <version>0.9.1</version>
        </dependency>

        <!-- Lombok -->
        <dependency>
            <groupId>org.projectlombok</groupId>
            <artifactId>lombok</artifactId>
            <optional>true</optional>
        </dependency>

        <!-- Test -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

## Docker 설정

### Dockerfile

```dockerfile
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN ./mvnw clean package -DskipTests

FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/*.jar app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  backend:
    build: .
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
    depends_on:
      - postgres
      - redis

  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=mydb
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  postgres_data:
```

## REST API 설계 예시

### Controller

```java
@RestController
@RequestMapping("/api/boards")
@RequiredArgsConstructor
public class BoardController {

    private final BoardService boardService;

    @GetMapping
    public ResponseEntity<Page<BoardResponse>> getBoards(
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "10") int size
    ) {
        Page<BoardResponse> boards = boardService.getBoards(page, size);
        return ResponseEntity.ok(boards);
    }

    @GetMapping("/{id}")
    public ResponseEntity<BoardResponse> getBoard(@PathVariable Long id) {
        BoardResponse board = boardService.getBoard(id);
        return ResponseEntity.ok(board);
    }

    @PostMapping
    public ResponseEntity<BoardResponse> createBoard(
        @Valid @RequestBody BoardCreateRequest request
    ) {
        BoardResponse board = boardService.createBoard(request);
        return ResponseEntity.status(HttpStatus.CREATED).body(board);
    }

    @PutMapping("/{id}")
    public ResponseEntity<BoardResponse> updateBoard(
        @PathVariable Long id,
        @Valid @RequestBody BoardUpdateRequest request
    ) {
        BoardResponse board = boardService.updateBoard(id, request);
        return ResponseEntity.ok(board);
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteBoard(@PathVariable Long id) {
        boardService.deleteBoard(id);
        return ResponseEntity.noContent().build();
    }
}
```

## 빌드 및 실행

### 로컬 실행

```bash
# Maven
./mvnw spring-boot:run

# Gradle
./gradlew bootRun
```

### Docker 빌드 및 실행

```bash
# Docker Compose로 실행
docker-compose up -d

# 단독 실행
docker build -t backend:latest .
docker run -p 8080:8080 backend:latest
```

## 참고 자료

- `references/spring-boot-api.md`: Spring Boot API 서버 구축 상세 가이드
- `references/jpa-setup.md`: JPA/Hibernate 설정 및 사용법
- `references/redis-cache.md`: Redis 캐싱 전략
- `references/folder-structure.md`: 폴더 구조 상세 설명
- `references/docker-setup.md`: Docker 설정 및 최적화
- `scripts/generate_api_scaffold.py`: API 스캐폴딩 자동 생성

## 관련 스킬

- `project-init`: 프로젝트 초기화
- `frontend` (sef-2026 플러그인): 공통 프론트엔드 개발
- `deployment`: 배포
