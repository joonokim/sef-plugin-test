# 백엔드 폴더 구조 상세 설명

## 전체 구조

```
backend/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/example/project/
│   │   │       ├── ProjectApplication.java    # 메인 클래스
│   │   │       ├── config/                    # 설정 클래스
│   │   │       ├── controller/                # REST 컨트롤러
│   │   │       ├── service/                   # 비즈니스 로직
│   │   │       ├── repository/                # 데이터 접근 계층
│   │   │       ├── domain/                    # 엔티티 (JPA)
│   │   │       ├── dto/                       # 데이터 전송 객체
│   │   │       ├── security/                  # 보안 관련
│   │   │       ├── exception/                 # 예외 처리
│   │   │       └── util/                      # 유틸리티
│   │   └── resources/
│   │       ├── application.yml                # 기본 설정
│   │       ├── application-dev.yml            # 개발 환경 설정
│   │       ├── application-prod.yml           # 운영 환경 설정
│   │       ├── logback-spring.xml             # 로그 설정
│   │       ├── db/migration/                  # Flyway/Liquibase 마이그레이션
│   │       └── static/                        # 정적 리소스
│   └── test/
│       └── java/
│           └── com/example/project/
│               ├── controller/                # 컨트롤러 테스트
│               ├── service/                   # 서비스 테스트
│               └── repository/                # 레포지토리 테스트
├── Dockerfile                                  # Docker 이미지 빌드 파일
├── docker-compose.yml                          # 로컬 개발 환경
├── pom.xml                                     # Maven 설정
├── .gitignore                                  # Git 제외 파일
└── README.md                                   # 프로젝트 문서
```

## 각 디렉토리 설명

### config/

애플리케이션 설정 관련 클래스

```
config/
├── SecurityConfig.java          # Spring Security 설정
├── RedisConfig.java             # Redis 캐시 설정
├── JpaConfig.java               # JPA Auditing 설정
├── WebConfig.java               # CORS, Interceptor 등 웹 설정
├── SwaggerConfig.java           # API 문서 설정
└── AsyncConfig.java             # 비동기 처리 설정
```

**예시: SecurityConfig.java**

```java
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        http
            .csrf(csrf -> csrf.disable())
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/auth/**").permitAll()
                .anyRequest().authenticated()
            )
            .addFilterBefore(jwtAuthenticationFilter(),
                UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}
```

### controller/

REST API 엔드포인트 정의

```
controller/
├── AuthController.java          # 인증 API (/api/auth/*)
├── BoardController.java         # 게시판 API (/api/boards/*)
├── UserController.java          # 사용자 API (/api/users/*)
└── FileController.java          # 파일 업로드 API
```

**명명 규칙:**
- `{도메인}Controller.java`
- REST API 경로: `/api/{도메인s}`

### service/

비즈니스 로직 처리

```
service/
├── AuthService.java             # 인증 비즈니스 로직
├── BoardService.java            # 게시판 비즈니스 로직
├── UserService.java             # 사용자 비즈니스 로직
└── EmailService.java            # 이메일 전송 로직
```

**원칙:**
- 트랜잭션 관리 (`@Transactional`)
- 도메인 로직 집중
- Controller와 Repository 사이의 중재자

### repository/

데이터베이스 접근 계층

```
repository/
├── UserRepository.java          # User 엔티티 Repository
├── BoardRepository.java         # Board 엔티티 Repository
└── custom/                      # 커스텀 쿼리
    ├── BoardRepositoryCustom.java
    └── BoardRepositoryCustomImpl.java
```

**사용 기술:**
- Spring Data JPA
- QueryDSL (복잡한 쿼리)

### domain/

JPA 엔티티 클래스

```
domain/
├── User.java                    # 사용자 엔티티
├── Board.java                   # 게시판 엔티티
├── Comment.java                 # 댓글 엔티티
├── File.java                    # 파일 엔티티
└── BaseEntity.java              # 공통 엔티티 (Auditing)
```

**주의사항:**
- 순수 도메인 로직만 포함
- 다른 계층에 의존하지 않음
- Setter 사용 최소화, Builder 패턴 권장

### dto/

데이터 전송 객체

```
dto/
├── request/                     # 요청 DTO
│   ├── BoardCreateRequest.java
│   ├── BoardUpdateRequest.java
│   └── LoginRequest.java
└── response/                    # 응답 DTO
    ├── BoardResponse.java
    ├── UserResponse.java
    └── ErrorResponse.java
```

**명명 규칙:**
- 요청: `{기능}{동작}Request` (예: `BoardCreateRequest`)
- 응답: `{도메인}Response` (예: `BoardResponse`)

### security/

인증/인가 관련 클래스

```
security/
├── JwtTokenProvider.java        # JWT 토큰 생성/검증
├── JwtAuthenticationFilter.java # JWT 필터
├── CustomUserDetails.java       # 사용자 상세 정보
└── CustomUserDetailsService.java # UserDetailsService 구현
```

### exception/

예외 처리 관련

```
exception/
├── GlobalExceptionHandler.java  # 전역 예외 핸들러
├── CustomException.java         # 커스텀 예외 기본 클래스
├── BoardNotFoundException.java  # 게시판 Not Found 예외
└── UnauthorizedException.java   # 인증 예외
```

### util/

유틸리티 클래스

```
util/
├── DateUtil.java                # 날짜 관련 유틸
├── StringUtil.java              # 문자열 처리 유틸
└── FileUtil.java                # 파일 처리 유틸
```

## 레이어 아키텍처

```
┌─────────────────────────────────────────┐
│          Controller Layer               │  (HTTP 요청/응답)
├─────────────────────────────────────────┤
│           Service Layer                 │  (비즈니스 로직)
├─────────────────────────────────────────┤
│         Repository Layer                │  (데이터 접근)
├─────────────────────────────────────────┤
│          Domain Layer                   │  (엔티티)
└─────────────────────────────────────────┘
```

**의존성 방향:**
- Controller → Service → Repository → Domain
- 상위 계층이 하위 계층에 의존
- 역방향 의존 금지 (DIP 원칙)

## 명명 규칙

### 클래스명

- Controller: `{도메인}Controller`
- Service: `{도메인}Service`
- Repository: `{도메인}Repository`
- Entity: `{도메인}` (단수형)

### 메서드명

- 조회: `get{Entity}`, `find{Entity}`
- 생성: `create{Entity}`, `save{Entity}`
- 수정: `update{Entity}`
- 삭제: `delete{Entity}`, `remove{Entity}`
- 검증: `validate{Action}`, `check{Condition}`

## 패키지 구성 전략

### 계층별 패키지 (Layer-based)

현재 구조가 이에 해당합니다.

**장점:**
- 각 계층의 역할이 명확
- 전통적이고 이해하기 쉬움

**단점:**
- 기능별로 파일이 분산됨
- 도메인이 많아지면 각 패키지가 비대해짐

### 기능별 패키지 (Feature-based)

```
com/example/project/
├── board/
│   ├── BoardController.java
│   ├── BoardService.java
│   ├── BoardRepository.java
│   ├── Board.java
│   └── dto/
│       ├── BoardCreateRequest.java
│       └── BoardResponse.java
└── user/
    ├── UserController.java
    ├── UserService.java
    └── ...
```

**장점:**
- 기능별로 응집도가 높음
- 관련 파일들이 모여 있어 유지보수 용이

**단점:**
- 공통 기능 관리가 어려울 수 있음

## 참고 자료

- [Spring Boot Best Practices](https://www.baeldung.com/spring-boot-best-practices)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
