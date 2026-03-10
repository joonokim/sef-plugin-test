# 마이크로서비스 아키텍처 가이드

## 개요

마이크로서비스는 애플리케이션을 작고 독립적인 서비스들로 분해하는 아키텍처 패턴입니다.

## 마이크로서비스 원칙

### 1. 단일 책임 원칙 (Single Responsibility)

각 서비스는 하나의 비즈니스 기능만 담당합니다.

```
✅ 좋은 예:
- UserService: 사용자 관리
- OrderService: 주문 관리
- PaymentService: 결제 처리

❌ 나쁜 예:
- BusinessService: 모든 비즈니스 로직
```

### 2. 독립적 배포 (Independent Deployment)

각 서비스는 다른 서비스에 영향을 주지 않고 독립적으로 배포 가능해야 합니다.

### 3. 데이터베이스 분리 (Database per Service)

각 서비스는 자체 데이터베이스를 가집니다.

```
UserService → user_db
OrderService → order_db
PaymentService → payment_db
```

### 4. API 기반 통신

서비스 간 통신은 잘 정의된 API를 통해서만 이루어집니다.

## 아키텍처 패턴

### API Gateway Pattern

```
Client
  │
  ▼
API Gateway
  │
  ├─▶ UserService
  ├─▶ OrderService
  └─▶ PaymentService
```

**장점**:
- 단일 진입점
- 인증/인가 중앙화
- 라우팅 및 로드 밸런싱

### Service Mesh Pattern

```
Service A ←──(Sidecar)──▶ Service B
    │                        │
(Sidecar)                (Sidecar)
    │                        │
    └────────Control Plane────┘
```

**장점**:
- 서비스 디스커버리
- 로드 밸런싱
- 보안 (mTLS)
- 모니터링

## 통신 방식

### 1. 동기 통신 (Synchronous)

**REST API**
```typescript
// UserService에서 OrderService 호출
const response = await fetch('http://order-service/api/orders', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ userId, items })
});
```

**gRPC**
```protobuf
service OrderService {
  rpc CreateOrder(OrderRequest) returns (OrderResponse);
}
```

### 2. 비동기 통신 (Asynchronous)

**메시지 큐 (RabbitMQ, Kafka)**
```typescript
// OrderService에서 이벤트 발행
publisher.publish('order.created', {
  orderId: '123',
  userId: 'user-456',
  timestamp: new Date()
});

// EmailService에서 이벤트 구독
subscriber.subscribe('order.created', async (event) => {
  await sendOrderConfirmationEmail(event.userId);
});
```

## 데이터 일관성

### Saga Pattern

분산 트랜잭션을 여러 단계의 로컬 트랜잭션으로 나눕니다.

**Choreography 방식** (이벤트 기반)
```
1. OrderService: 주문 생성 → order.created 이벤트
2. PaymentService: 결제 처리 → payment.completed 이벤트
3. InventoryService: 재고 차감 → inventory.updated 이벤트
```

**Orchestration 방식** (중앙 제어)
```
OrderOrchestrator
  │
  ├─▶ 1. OrderService.createOrder()
  ├─▶ 2. PaymentService.processPayment()
  └─▶ 3. InventoryService.decreaseStock()
```

### CQRS (Command Query Responsibility Segregation)

읽기와 쓰기를 분리합니다.

```
Write Model (Command) → PostgreSQL
    │
    └─▶ Event Store
          │
          └─▶ Read Model (Query) → MongoDB / Elasticsearch
```

## 서비스 디스커버리

### Client-Side Discovery

```typescript
// Consul을 사용한 서비스 디스커버리
const services = await consul.catalog.service.nodes('order-service');
const service = loadBalancer.select(services);
const response = await fetch(`http://${service.address}:${service.port}/api/orders`);
```

### Server-Side Discovery

```yaml
# Kubernetes Service
apiVersion: v1
kind: Service
metadata:
  name: order-service
spec:
  selector:
    app: order
  ports:
    - port: 80
      targetPort: 3000
```

## 장애 처리 (Resilience)

### Circuit Breaker

```typescript
const breaker = new CircuitBreaker(callExternalService, {
  timeout: 3000,
  errorThresholdPercentage: 50,
  resetTimeout: 30000
});

try {
  const result = await breaker.fire(params);
} catch (error) {
  // Fallback 로직
  return getCachedData();
}
```

### Retry Pattern

```typescript
const retry = async (fn, retries = 3, delay = 1000) => {
  try {
    return await fn();
  } catch (error) {
    if (retries === 0) throw error;
    await sleep(delay);
    return retry(fn, retries - 1, delay * 2);
  }
};
```

### Bulkhead Pattern

```typescript
// 리소스 격리
const userServicePool = new Pool({ max: 10 });
const orderServicePool = new Pool({ max: 10 });
```

## 모니터링 및 로깅

### Distributed Tracing

```typescript
// OpenTelemetry
const tracer = trace.getTracer('order-service');
const span = tracer.startSpan('createOrder');

try {
  // 비즈니스 로직
  const order = await createOrder(data);
  span.setStatus({ code: SpanStatusCode.OK });
  return order;
} catch (error) {
  span.setStatus({ code: SpanStatusCode.ERROR });
  throw error;
} finally {
  span.end();
}
```

### Centralized Logging

```yaml
# ELK Stack (Elasticsearch, Logstash, Kibana)
filebeat → logstash → elasticsearch → kibana
```

## 배포 전략

### Blue-Green Deployment

```
Blue (v1.0) ←── 100% 트래픽
Green (v2.0) ←── 0% 트래픽

배포 후:
Blue (v1.0) ←── 0% 트래픽
Green (v2.0) ←── 100% 트래픽
```

### Canary Deployment

```
v1.0 ←── 90% 트래픽
v2.0 ←── 10% 트래픽

점진적으로 v2.0 비율 증가
```

## 보안

### API Gateway에서 인증/인가

```typescript
// JWT 검증
app.use(async (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  const decoded = await verifyJWT(token);
  req.user = decoded;
  next();
});
```

### 서비스 간 mTLS

```yaml
# Istio mTLS 설정
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT
```

## 모범 사례

1. **작게 시작하기**: 모놀리스부터 시작하여 필요할 때 분리
2. **도메인 주도 설계**: Bounded Context를 기반으로 서비스 분리
3. **API 버전 관리**: /v1, /v2 등 명확한 버전 관리
4. **자동화**: CI/CD 파이프라인 구축
5. **관찰 가능성**: 로깅, 모니터링, 트레이싱
6. **문서화**: API 문서 (OpenAPI/Swagger)

## 안티 패턴 (Anti-Patterns)

❌ **분산 모놀리스**: 서비스는 분리했지만 여전히 강하게 결합됨
❌ **공유 데이터베이스**: 여러 서비스가 하나의 DB를 공유
❌ **과도한 분리**: 불필요하게 작은 서비스로 나눔
❌ **동기 체인**: 서비스 A → B → C → D (긴 동기 호출 체인)

## 관련 도구

- **API Gateway**: Kong, AWS API Gateway, NGINX
- **Service Mesh**: Istio, Linkerd, Consul
- **메시지 큐**: RabbitMQ, Apache Kafka, AWS SQS
- **컨테이너**: Docker, Kubernetes
- **모니터링**: Prometheus, Grafana, Jaeger
- **로깅**: ELK Stack, Fluentd

## 참고 자료

- [마틴 파울러의 마이크로서비스](https://martinfowler.com/microservices/)
- [12 Factor App](https://12factor.net/)
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
