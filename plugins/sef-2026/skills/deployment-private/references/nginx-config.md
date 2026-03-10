# Nginx 리버스 프록시 설정 가이드

민간 섹터 프로젝트의 Nginx를 사용한 리버스 프록시 및 로드 밸런싱 설정 가이드입니다.

## 개요

Nginx는 고성능 웹 서버이자 리버스 프록시 서버로, 백엔드와 프론트엔드 사이의 게이트웨이 역할을 합니다.

### 주요 기능

- 리버스 프록시
- 로드 밸런싱
- SSL/TLS 종료
- 정적 파일 서빙
- 캐싱
- Gzip 압축
- Rate Limiting

## 기본 설정

### nginx.conf (메인 설정)

```nginx
# 사용자 및 워커 프로세스
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

# 이벤트 설정
events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 로그 포맷
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # 기본 설정
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 20M;

    # Gzip 압축
    gzip on;
    gzip_disable "msie6";
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # 버퍼 크기
    client_body_buffer_size 128k;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 16k;

    # 타임아웃
    client_body_timeout 12;
    client_header_timeout 12;
    send_timeout 10;

    # 가상 호스트 설정 포함
    include /etc/nginx/conf.d/*.conf;
}
```

## 리버스 프록시 설정

### 기본 리버스 프록시

```nginx
# /etc/nginx/conf.d/default.conf
upstream backend {
    server backend:8080 max_fails=3 fail_timeout=30s;
}

upstream frontend {
    server frontend:3000 max_fails=3 fail_timeout=30s;
}

server {
    listen 80;
    server_name example.com www.example.com;

    # 보안 헤더
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # 프론트엔드 (SPA)
    location / {
        proxy_pass http://frontend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # 백엔드 API
    location /api {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # 타임아웃 설정
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;

        # 버퍼링
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }

    # 헬스체크
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
```

## SSL/TLS 설정

### HTTPS 설정

```nginx
server {
    listen 80;
    server_name example.com www.example.com;

    # HTTP to HTTPS 리다이렉트
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name example.com www.example.com;

    # SSL 인증서
    ssl_certificate /etc/nginx/ssl/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/privkey.pem;

    # SSL 설정
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/nginx/ssl/chain.pem;
    resolver 8.8.8.8 8.8.4.4 valid=300s;
    resolver_timeout 5s;

    # HSTS
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;

    # 보안 헤더
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # 프론트엔드
    location / {
        proxy_pass http://frontend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }

    # 백엔드 API
    location /api {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 로드 밸런싱

### Round Robin (기본)

```nginx
upstream backend {
    server backend-1:8080;
    server backend-2:8080;
    server backend-3:8080;
}
```

### Least Connections

```nginx
upstream backend {
    least_conn;
    server backend-1:8080;
    server backend-2:8080;
    server backend-3:8080;
}
```

### IP Hash (세션 유지)

```nginx
upstream backend {
    ip_hash;
    server backend-1:8080;
    server backend-2:8080;
    server backend-3:8080;
}
```

### 가중치 기반

```nginx
upstream backend {
    server backend-1:8080 weight=3;
    server backend-2:8080 weight=2;
    server backend-3:8080 weight=1;
}
```

### 헬스체크 포함

```nginx
upstream backend {
    server backend-1:8080 max_fails=3 fail_timeout=30s;
    server backend-2:8080 max_fails=3 fail_timeout=30s;
    server backend-3:8080 max_fails=3 fail_timeout=30s backup;
}
```

## 캐싱

### 프록시 캐시 설정

```nginx
# http 블록
proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=api_cache:10m max_size=1g inactive=60m use_temp_path=off;

server {
    # ...

    # API 캐싱
    location /api {
        proxy_pass http://backend;
        proxy_cache api_cache;
        proxy_cache_key "$scheme$request_method$host$request_uri";
        proxy_cache_valid 200 302 10m;
        proxy_cache_valid 404 1m;
        proxy_cache_bypass $http_cache_control;
        add_header X-Cache-Status $upstream_cache_status;
    }

    # 정적 파일 캐싱
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
        proxy_pass http://frontend;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

## Rate Limiting

### 요청 제한

```nginx
# http 블록
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login_limit:10m rate=5r/m;

server {
    # ...

    # API 전체 제한
    location /api {
        limit_req zone=api_limit burst=20 nodelay;
        limit_req_status 429;
        proxy_pass http://backend;
    }

    # 로그인 엔드포인트 제한
    location /api/auth/login {
        limit_req zone=login_limit burst=5;
        limit_req_status 429;
        proxy_pass http://backend;
    }
}
```

### 연결 제한

```nginx
# http 블록
limit_conn_zone $binary_remote_addr zone=conn_limit:10m;

server {
    # ...

    location / {
        limit_conn conn_limit 10;
        proxy_pass http://frontend;
    }
}
```

## 정적 파일 서빙

### React/Next.js 빌드 파일

```nginx
server {
    listen 80;
    server_name example.com;
    root /usr/share/nginx/html;
    index index.html;

    # Gzip 압축
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # SPA 라우팅 처리
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 정적 파일 캐싱
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # API 프록시
    location /api {
        proxy_pass http://backend:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## WebSocket 지원

```nginx
upstream websocket {
    server backend:8080;
}

server {
    # ...

    location /ws {
        proxy_pass http://websocket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket 타임아웃
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
}
```

## 다중 도메인 설정

```nginx
# API 도메인
server {
    listen 443 ssl http2;
    server_name api.example.com;

    ssl_certificate /etc/nginx/ssl/api.example.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/api.example.com/privkey.pem;

    location / {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# 프론트엔드 도메인
server {
    listen 443 ssl http2;
    server_name www.example.com;

    ssl_certificate /etc/nginx/ssl/www.example.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/www.example.com/privkey.pem;

    location / {
        proxy_pass http://frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# 관리자 도메인
server {
    listen 443 ssl http2;
    server_name admin.example.com;

    ssl_certificate /etc/nginx/ssl/admin.example.com/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/admin.example.com/privkey.pem;

    # IP 화이트리스트
    allow 203.0.113.0/24;
    deny all;

    location / {
        proxy_pass http://admin-frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 로깅 및 모니터링

### 상세 로그 설정

```nginx
# http 블록
log_format detailed '$remote_addr - $remote_user [$time_local] '
                    '"$request" $status $body_bytes_sent '
                    '"$http_referer" "$http_user_agent" '
                    'rt=$request_time uct="$upstream_connect_time" '
                    'uht="$upstream_header_time" urt="$upstream_response_time"';

server {
    access_log /var/log/nginx/access.log detailed;
    error_log /var/log/nginx/error.log warn;

    # ...
}
```

### 상태 모니터링

```nginx
server {
    listen 8080;
    server_name localhost;

    location /nginx_status {
        stub_status on;
        access_log off;
        allow 127.0.0.1;
        deny all;
    }
}
```

## Docker 통합

### Dockerfile

```dockerfile
FROM nginx:alpine

# 설정 파일 복사
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ /etc/nginx/conf.d/

# SSL 인증서 (선택사항)
COPY ssl/ /etc/nginx/ssl/

# 정적 파일 (선택사항)
COPY dist/ /usr/share/nginx/html/

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./ssl:/etc/nginx/ssl:ro
      - nginx_cache:/var/cache/nginx
    depends_on:
      - backend
      - frontend
    networks:
      - myapp-network
    restart: unless-stopped

volumes:
  nginx_cache:

networks:
  myapp-network:
    driver: bridge
```

## 성능 최적화

### 1. 워커 프로세스 최적화

```nginx
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}
```

### 2. 버퍼 크기 최적화

```nginx
http {
    client_body_buffer_size 128k;
    client_max_body_size 20M;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 16k;
    output_buffers 1 32k;
    postpone_output 1460;
}
```

### 3. TCP 최적화

```nginx
http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 100;
}
```

### 4. HTTP/2 활성화

```nginx
server {
    listen 443 ssl http2;
    # ...
}
```

## 보안 강화

### 1. DDoS 방어

```nginx
# http 블록
limit_req_zone $binary_remote_addr zone=ddos:10m rate=100r/s;
limit_conn_zone $binary_remote_addr zone=conn:10m;

server {
    limit_req zone=ddos burst=200 nodelay;
    limit_conn conn 20;
    # ...
}
```

### 2. SQL Injection 방어

```nginx
location ~ ^/api {
    if ($request_uri ~* "(union|select|insert|delete|drop|update|having|sleep|benchmark)") {
        return 403;
    }
    proxy_pass http://backend;
}
```

### 3. 버전 정보 숨기기

```nginx
http {
    server_tokens off;
}
```

## 테스트 및 디버깅

### 설정 테스트

```bash
# 설정 파일 문법 검사
nginx -t

# 설정 파일 리로드
nginx -s reload

# Nginx 재시작
systemctl restart nginx
```

### 로그 확인

```bash
# 실시간 로그 확인
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# 에러 로그만 필터링
grep "error" /var/log/nginx/error.log
```

## 참고 자료

- [Nginx 공식 문서](https://nginx.org/en/docs/)
- [Nginx 성능 튜닝 가이드](https://www.nginx.com/blog/tuning-nginx/)
- Docker Compose 통합: `docker-compose.md`
