# 마이크로서비스 아키텍처 구조 가이드

민간 섹터 프로젝트의 마이크로서비스 아키텍처 설계 및 구조 가이드입니다.

## 개요

마이크로서비스 아키텍처는 애플리케이션을 작고 독립적인 서비스들의 모음으로 구성하는 아키텍처 패턴입니다.

### 주요 특징

- **독립적 배포**: 각 서비스를 독립적으로 배포
- **기술 다양성**: 서비스별로 다른 기술 스택 사용 가능
- **확장성**: 필요한 서비스만 스케일링
- **장애 격리**: 한 서비스의 장애가 전체에 영향을 미치지 않음
- **팀 자율성**: 서비스별로 독립적인 팀 운영

## 프로젝트 구조

### 모놀리식 vs 마이크로서비스

```
# 모놀리식 구조
project/
├── backend/                  # 하나의 큰 애플리케이션
│   └── src/
│       ├── user/
│       ├── product/
│       ├── order/
│       └── payment/
└── frontend/

# 마이크로서비스 구조
project/
├── services/
│   ├── user-service/         # 사용자 관리 서비스
│   ├── product-service/      # 상품 관리 서비스
│   ├── order-service/        # 주문 관리 서비스
│   ├── payment-service/      # 결제 서비스
│   └── notification-service/ # 알림 서비스
├── frontend/
├── api-gateway/              # API 게이트웨이
└── infrastructure/           # 공통 인프라
```

## 상세 프로젝트 구조

```
microservices-project/
├── services/                         # 마이크로서비스들
│   ├── user-service/
│   │   ├── src/
│   │   │   ├── main/
│   │   │   │   ├── java/com/example/user/
│   │   │   │   │   ├── controller/
│   │   │   │   │   ├── service/
│   │   │   │   │   ├── repository/
│   │   │   │   │   ├── domain/
│   │   │   │   │   ├── dto/
│   │   │   │   │   └── UserServiceApplication.java
│   │   │   │   └── resources/
│   │   │   │       └── application.yml
│   │   │   └── test/
│   │   ├── Dockerfile
│   │   ├── pom.xml
│   │   └── README.md
│   │
│   ├── product-service/
│   │   ├── src/
│   │   ├── Dockerfile
│   │   ├── pom.xml
│   │   └── README.md
│   │
│   ├── order-service/
│   │   ├── src/
│   │   ├── Dockerfile
│   │   ├── pom.xml
│   │   └── README.md
│   │
│   └── payment-service/
│       ├── src/
│       ├── Dockerfile
│       ├── pom.xml
│       └── README.md
│
├── api-gateway/                      # API 게이트웨이
│   ├── src/
│   ├── Dockerfile
│   └── pom.xml
│
├── frontend/                         # 프론트엔드
│   ├── app/
│   ├── Dockerfile
│   └── package.json
│
├── infrastructure/                   # 인프라 공통 설정
│   ├── docker-compose.yml
│   ├── k8s/
│   │   ├── user-service/
│   │   ├── product-service/
│   │   ├── order-service/
│   │   ├── payment-service/
│   │   ├── api-gateway/
│   │   └── ingress.yaml
│   └── terraform/                    # IaC
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── shared/                           # 공유 라이브러리
│   ├── common-models/
│   ├── common-utils/
│   └── service-contracts/
│
├── scripts/                          # 유틸리티 스크립트
│   ├── build_all.sh
│   ├── deploy_all.sh
│   └── run_local.sh
│
└── README.md
```

## 서비스별 책임

### 1. User Service (사용자 서비스)

**책임**:
- 사용자 등록, 로그인, 프로필 관리
- 인증 및 권한 부여
- 사용자 정보 조회

**API 엔드포인트**:
- `POST /users/register` - 회원가입
- `POST /users/login` - 로그인
- `GET /users/{id}` - 사용자 조회
- `PUT /users/{id}` - 사용자 수정

**데이터베이스**:
- PostgreSQL (사용자 정보, 자격증명)

### 2. Product Service (상품 서비스)

**책임**:
- 상품 등록, 조회, 수정, 삭제
- 재고 관리
- 카테고리 관리

**API 엔드포인트**:
- `GET /products` - 상품 목록 조회
- `GET /products/{id}` - 상품 상세 조회
- `POST /products` - 상품 등록
- `PUT /products/{id}` - 상품 수정
- `DELETE /products/{id}` - 상품 삭제

**데이터베이스**:
- PostgreSQL (상품 정보, 재고)

### 3. Order Service (주문 서비스)

**책임**:
- 주문 생성, 조회, 취소
- 주문 상태 관리
- 주문 이력 조회

**API 엔드포인트**:
- `POST /orders` - 주문 생성
- `GET /orders/{id}` - 주문 조회
- `GET /orders/user/{userId}` - 사용자별 주문 조회
- `PUT /orders/{id}/cancel` - 주문 취소

**데이터베이스**:
- PostgreSQL (주문 정보)

**이벤트**:
- 발행: `OrderCreated`, `OrderCancelled`
- 구독: `PaymentCompleted`, `PaymentFailed`

### 4. Payment Service (결제 서비스)

**책임**:
- 결제 처리
- 결제 이력 관리
- 환불 처리

**API 엔드포인트**:
- `POST /payments` - 결제 처리
- `GET /payments/{id}` - 결제 조회
- `POST /payments/{id}/refund` - 환불 처리

**데이터베이스**:
- PostgreSQL (결제 이력)

**이벤트**:
- 발행: `PaymentCompleted`, `PaymentFailed`

### 5. Notification Service (알림 서비스)

**책임**:
- 이메일 발송
- SMS 발송
- 푸시 알림

**API 엔드포인트**:
- `POST /notifications/email` - 이메일 발송
- `POST /notifications/sms` - SMS 발송

**이벤트**:
- 구독: `OrderCreated`, `PaymentCompleted`

## API Gateway

### Spring Cloud Gateway 설정

```yaml
# api-gateway/src/main/resources/application.yml
spring:
  cloud:
    gateway:
      routes:
        # User Service
        - id: user-service
          uri: lb://user-service
          predicates:
            - Path=/api/users/**
          filters:
            - RewritePath=/api/users/(?<segment>.*), /${segment}

        # Product Service
        - id: product-service
          uri: lb://product-service
          predicates:
            - Path=/api/products/**
          filters:
            - RewritePath=/api/products/(?<segment>.*), /${segment}

        # Order Service
        - id: order-service
          uri: lb://order-service
          predicates:
            - Path=/api/orders/**
          filters:
            - RewritePath=/api/orders/(?<segment>.*), /${segment}

        # Payment Service
        - id: payment-service
          uri: lb://payment-service
          predicates:
            - Path=/api/payments/**
          filters:
            - RewritePath=/api/payments/(?<segment>.*), /${segment}

  # Eureka Discovery
  application:
    name: api-gateway

eureka:
  client:
    service-url:
      defaultZone: http://localhost:8761/eureka/
```

## 서비스 간 통신

### 1. 동기 통신 (REST API)

```java
// Order Service에서 Product Service 호출
@Service
public class OrderService {
    @Autowired
    private RestTemplate restTemplate;

    public Order createOrder(OrderRequest request) {
        // Product Service 호출
        Product product = restTemplate.getForObject(
            "http://product-service/products/" + request.getProductId(),
            Product.class
        );

        // 주문 처리
        Order order = new Order();
        order.setProductId(product.getId());
        order.setPrice(product.getPrice());

        return orderRepository.save(order);
    }
}
```

### 2. 비동기 통신 (메시지 큐)

```java
// Order Service - 이벤트 발행
@Service
public class OrderService {
    @Autowired
    private RabbitTemplate rabbitTemplate;

    public Order createOrder(OrderRequest request) {
        Order order = orderRepository.save(new Order(request));

        // 이벤트 발행
        OrderCreatedEvent event = new OrderCreatedEvent(order);
        rabbitTemplate.convertAndSend("order.exchange", "order.created", event);

        return order;
    }
}

// Payment Service - 이벤트 구독
@Component
public class OrderEventListener {
    @Autowired
    private PaymentService paymentService;

    @RabbitListener(queues = "payment.order.created")
    public void handleOrderCreated(OrderCreatedEvent event) {
        // 결제 처리
        paymentService.processPayment(event.getOrderId());
    }
}
```

## 데이터 관리

### Database per Service 패턴

각 마이크로서비스는 자체 데이터베이스를 가집니다.

```yaml
# docker-compose.yml
services:
  user-db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: userdb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password

  product-db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: productdb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password

  order-db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: orderdb
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
```

### Saga 패턴 (분산 트랜잭션)

주문 생성 시나리오:

1. **Order Service**: 주문 생성 (상태: PENDING)
2. **Payment Service**: 결제 처리
   - 성공: PaymentCompleted 이벤트 발행
   - 실패: PaymentFailed 이벤트 발행
3. **Order Service**: 이벤트 수신
   - PaymentCompleted: 주문 상태를 CONFIRMED로 변경
   - PaymentFailed: 주문 상태를 CANCELLED로 변경

## 서비스 디스커버리

### Eureka Server

```java
// eureka-server/src/main/java/com/example/eureka/EurekaServerApplication.java
@SpringBootApplication
@EnableEurekaServer
public class EurekaServerApplication {
    public static void main(String[] args) {
        SpringApplication.run(EurekaServerApplication.class, args);
    }
}
```

```yaml
# eureka-server/src/main/resources/application.yml
server:
  port: 8761

eureka:
  client:
    register-with-eureka: false
    fetch-registry: false
```

### Eureka Client

```yaml
# user-service/src/main/resources/application.yml
spring:
  application:
    name: user-service

eureka:
  client:
    service-url:
      defaultZone: http://localhost:8761/eureka/
  instance:
    prefer-ip-address: true
```

## 모니터링 및 로깅

### Distributed Tracing (Zipkin)

```yaml
# 각 서비스의 application.yml
spring:
  zipkin:
    base-url: http://zipkin:9411
  sleuth:
    sampler:
      probability: 1.0  # 모든 요청 추적 (프로덕션에서는 0.1 권장)
```

### Centralized Logging (ELK Stack)

```yaml
# docker-compose.yml
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:8.5.0
    environment:
      - discovery.type=single-node

  logstash:
    image: docker.elastic.co/logstash/logstash:8.5.0
    volumes:
      - ./logstash/pipeline:/usr/share/logstash/pipeline

  kibana:
    image: docker.elastic.co/kibana/kibana:8.5.0
    ports:
      - "5601:5601"
```

## 보안

### JWT 인증

```java
// api-gateway에서 JWT 검증
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) {
        String token = extractToken(request);

        if (token != null && jwtUtil.validateToken(token)) {
            String userId = jwtUtil.getUserId(token);
            // 요청 헤더에 사용자 ID 추가
            request.setAttribute("X-User-Id", userId);
        }

        filterChain.doFilter(request, response);
    }
}
```

## 배포 전략

### Blue-Green 배포

```yaml
# kubernetes/order-service-blue.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service-blue
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: order-service
        version: blue

---
# kubernetes/order-service-green.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service-green
spec:
  replicas: 3
  template:
    metadata:
      labels:
        app: order-service
        version: green
```

## 장단점

### 장점

1. **독립적 배포**: 서비스별로 독립적으로 배포 가능
2. **기술 다양성**: 서비스마다 적합한 기술 선택 가능
3. **확장성**: 필요한 서비스만 스케일링
4. **장애 격리**: 한 서비스 장애가 전체에 영향 미치지 않음
5. **팀 자율성**: 서비스별로 독립적인 팀 구성 가능

### 단점

1. **복잡성 증가**: 분산 시스템의 복잡성
2. **네트워크 지연**: 서비스 간 통신 오버헤드
3. **데이터 일관성**: 분산 트랜잭션 관리 어려움
4. **운영 복잡도**: 모니터링, 로깅, 디버깅 어려움
5. **초기 비용**: 인프라 구축 비용

## 모범 사례

1. **도메인 주도 설계(DDD)**: 비즈니스 도메인 기반으로 서비스 분리
2. **API 버저닝**: API 버전 관리
3. **Circuit Breaker**: 장애 전파 방지
4. **Rate Limiting**: API 호출 제한
5. **Health Check**: 서비스 상태 모니터링
6. **Graceful Shutdown**: 우아한 종료 처리
7. **Idempotency**: 멱등성 보장

## 참고 자료

- [마이크로서비스 패턴](https://microservices.io/patterns/)
- [Spring Cloud 공식 문서](https://spring.io/projects/spring-cloud)
- [12 Factor App](https://12factor.net/)
- 관련 스킬: `backend`, `deployment` (이 플러그인 내)
