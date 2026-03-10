# Kubernetes 배포 가이드

민간 섹터 프로젝트를 Kubernetes에 배포하는 상세 가이드입니다. 로컬 Minikube부터 AWS EKS까지 다룹니다.

## 개요

Kubernetes는 컨테이너 오케스트레이션 플랫폼으로, 대규모 마이크로서비스 환경에 적합합니다.

### 주요 개념

- **Pod**: 하나 이상의 컨테이너 그룹
- **Deployment**: Pod의 선언적 업데이트
- **Service**: Pod에 대한 네트워크 엔드포인트
- **Ingress**: 클러스터 외부에서 서비스 접근
- **ConfigMap**: 설정 데이터 저장
- **Secret**: 민감한 데이터 저장 (비밀번호, 토큰 등)
- **PersistentVolume**: 영속적 스토리지

## 로컬 개발 환경 (Minikube)

### 1. Minikube 설치

```bash
# macOS
brew install minikube

# Windows (Chocolatey)
choco install minikube

# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
```

### 2. Minikube 시작

```bash
# 클러스터 시작
minikube start --driver=docker --cpus=4 --memory=8192

# 상태 확인
minikube status

# 대시보드 열기
minikube dashboard
```

### 3. kubectl 설치 및 설정

```bash
# macOS
brew install kubectl

# Windows (Chocolatey)
choco install kubernetes-cli

# 버전 확인
kubectl version --client

# 클러스터 정보 확인
kubectl cluster-info
```

## Kubernetes 매니페스트

### 디렉토리 구조

```
k8s/
├── namespace.yaml
├── configmap.yaml
├── secret.yaml
├── backend/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── hpa.yaml
├── frontend/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── hpa.yaml
├── database/
│   ├── statefulset.yaml
│   ├── service.yaml
│   └── pvc.yaml
├── redis/
│   ├── deployment.yaml
│   └── service.yaml
└── ingress.yaml
```

### namespace.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: myapp
  labels:
    name: myapp
    environment: production
```

### configmap.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: myapp
data:
  # 애플리케이션 설정
  APP_NAME: "MyApp"
  APP_VERSION: "1.0.0"

  # 데이터베이스 설정
  DB_HOST: "postgres-service"
  DB_PORT: "5432"
  DB_NAME: "mydb"

  # Redis 설정
  REDIS_HOST: "redis-service"
  REDIS_PORT: "6379"

  # 로깅
  LOG_LEVEL: "INFO"
```

### secret.yaml

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secrets
  namespace: myapp
type: Opaque
stringData:
  # 데이터베이스 비밀번호
  DB_USER: "user"
  DB_PASSWORD: "password"

  # JWT 시크릿
  JWT_SECRET: "your-secret-key-here"

  # AWS 자격증명 (선택사항)
  AWS_ACCESS_KEY_ID: "your-access-key"
  AWS_SECRET_ACCESS_KEY: "your-secret-key"
```

### backend/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: myapp
  labels:
    app: backend
    version: v1
spec:
  replicas: 3
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
        version: v1
    spec:
      containers:
      - name: backend
        image: your-registry/myapp-backend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP

        env:
        # ConfigMap에서 환경변수 로드
        - name: SPRING_PROFILES_ACTIVE
          value: "prod"
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: myapp-config
              key: DB_HOST
        - name: DB_PORT
          valueFrom:
            configMapKeyRef:
              name: myapp-config
              key: DB_PORT
        - name: DB_NAME
          valueFrom:
            configMapKeyRef:
              name: myapp-config
              key: DB_NAME

        # Secret에서 환경변수 로드
        - name: DB_USER
          valueFrom:
            secretKeyRef:
              name: myapp-secrets
              key: DB_USER
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: myapp-secrets
              key: DB_PASSWORD
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: myapp-secrets
              key: JWT_SECRET

        # 리소스 제한
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"

        # 헬스체크
        livenessProbe:
          httpGet:
            path: /actuator/health/liveness
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3

        readinessProbe:
          httpGet:
            path: /actuator/health/readiness
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 5
          timeoutSeconds: 3
          failureThreshold: 3

        # 로그 볼륨
        volumeMounts:
        - name: logs
          mountPath: /app/logs

      volumes:
      - name: logs
        emptyDir: {}

      # 이미지 풀 시크릿 (private registry)
      imagePullSecrets:
      - name: regcred
```

### backend/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: myapp
  labels:
    app: backend
spec:
  type: ClusterIP
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
    name: http
  selector:
    app: backend
```

### backend/hpa.yaml (Horizontal Pod Autoscaler)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: myapp
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
```

### frontend/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: myapp
  labels:
    app: frontend
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
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
        image: your-registry/myapp-frontend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 3000
          name: http

        env:
        - name: NUXT_PUBLIC_API_BASE_URL
          value: "http://backend-service:8080/api"
        - name: NODE_ENV
          value: "production"

        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"

        livenessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10

        readinessProbe:
          httpGet:
            path: /
            port: 3000
          initialDelaySeconds: 10
          periodSeconds: 5

      imagePullSecrets:
      - name: regcred
```

### frontend/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: myapp
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  selector:
    app: frontend
```

### database/statefulset.yaml

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: myapp
spec:
  serviceName: postgres-service
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
          name: postgres

        env:
        - name: POSTGRES_DB
          valueFrom:
            configMapKeyRef:
              name: myapp-config
              key: DB_NAME
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: myapp-secrets
              key: DB_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: myapp-secrets
              key: DB_PASSWORD

        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data

        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"

        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - user
          initialDelaySeconds: 30
          periodSeconds: 10

        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - user
          initialDelaySeconds: 5
          periodSeconds: 5

  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: standard
      resources:
        requests:
          storage: 10Gi
```

### database/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: myapp
spec:
  type: ClusterIP
  clusterIP: None  # Headless service for StatefulSet
  ports:
  - port: 5432
    targetPort: 5432
  selector:
    app: postgres
```

### redis/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379

        command:
        - redis-server
        - --appendonly
        - "yes"

        volumeMounts:
        - name: redis-storage
          mountPath: /data

        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"

      volumes:
      - name: redis-storage
        persistentVolumeClaim:
          claimName: redis-pvc
```

### redis/service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  namespace: myapp
spec:
  type: ClusterIP
  ports:
  - port: 6379
    targetPort: 6379
  selector:
    app: redis
```

### ingress.yaml (Nginx Ingress)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: myapp
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - example.com
    - www.example.com
    - api.example.com
    secretName: myapp-tls
  rules:
  # 프론트엔드
  - host: example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80

  # www 리다이렉트
  - host: www.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend-service
            port:
              number: 80

  # 백엔드 API
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: backend-service
            port:
              number: 8080
```

## 배포 명령어

### 1. 네임스페이스 및 설정 배포

```bash
# 네임스페이스 생성
kubectl apply -f k8s/namespace.yaml

# ConfigMap 및 Secret 생성
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

# Secret 확인
kubectl get secrets -n myapp
kubectl describe secret myapp-secrets -n myapp
```

### 2. 데이터베이스 배포

```bash
# PostgreSQL 배포
kubectl apply -f k8s/database/

# 상태 확인
kubectl get statefulsets -n myapp
kubectl get pvc -n myapp
kubectl logs -f postgres-0 -n myapp
```

### 3. Redis 배포

```bash
kubectl apply -f k8s/redis/
kubectl get pods -n myapp -l app=redis
```

### 4. 백엔드 배포

```bash
kubectl apply -f k8s/backend/

# 배포 상태 확인
kubectl rollout status deployment/backend -n myapp

# Pod 로그 확인
kubectl logs -f deployment/backend -n myapp
```

### 5. 프론트엔드 배포

```bash
kubectl apply -f k8s/frontend/
kubectl rollout status deployment/frontend -n myapp
```

### 6. Ingress 배포

```bash
# Nginx Ingress Controller 설치
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# Ingress 배포
kubectl apply -f k8s/ingress.yaml

# Ingress 확인
kubectl get ingress -n myapp
kubectl describe ingress myapp-ingress -n myapp
```

## AWS EKS 배포

### 1. EKS 클러스터 생성

```bash
# eksctl 설치
brew install eksctl

# 클러스터 생성
eksctl create cluster \
  --name myapp-cluster \
  --region ap-northeast-2 \
  --nodegroup-name standard-workers \
  --node-type t3.medium \
  --nodes 3 \
  --nodes-min 1 \
  --nodes-max 5 \
  --managed

# kubeconfig 업데이트
aws eks update-kubeconfig --region ap-northeast-2 --name myapp-cluster
```

### 2. EBS CSI 드라이버 설치 (영속적 스토리지)

```bash
# IAM 정책 생성
aws iam create-policy \
  --policy-name AmazonEKS_EBS_CSI_Driver_Policy \
  --policy-document file://ebs-csi-policy.json

# IAM 역할 생성 및 연결
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --namespace kube-system \
  --cluster myapp-cluster \
  --attach-policy-arn arn:aws:iam::123456789012:policy/AmazonEKS_EBS_CSI_Driver_Policy \
  --approve

# EBS CSI 드라이버 설치
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
```

### 3. AWS Load Balancer Controller 설치

```bash
# IAM 정책 다운로드
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.5.4/docs/install/iam_policy.json

# IAM 정책 생성
aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json

# IAM 역할 생성
eksctl create iamserviceaccount \
  --cluster=myapp-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::123456789012:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve

# Helm으로 설치
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=myapp-cluster \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller
```

## 유용한 kubectl 명령어

```bash
# 모든 리소스 확인
kubectl get all -n myapp

# Pod 상태 확인
kubectl get pods -n myapp
kubectl get pods -n myapp -o wide
kubectl describe pod <pod-name> -n myapp

# 로그 확인
kubectl logs <pod-name> -n myapp
kubectl logs -f deployment/backend -n myapp
kubectl logs --tail=100 <pod-name> -n myapp

# Pod 내부 접속
kubectl exec -it <pod-name> -n myapp -- /bin/sh

# 포트 포워딩 (로컬 테스트)
kubectl port-forward -n myapp service/backend-service 8080:8080

# 리소스 삭제
kubectl delete -f k8s/backend/
kubectl delete pod <pod-name> -n myapp --force

# 롤링 업데이트
kubectl set image deployment/backend backend=myapp-backend:v2 -n myapp
kubectl rollout status deployment/backend -n myapp
kubectl rollout history deployment/backend -n myapp
kubectl rollout undo deployment/backend -n myapp

# 스케일링
kubectl scale deployment backend --replicas=5 -n myapp

# 리소스 사용량 확인
kubectl top nodes
kubectl top pods -n myapp
```

## CI/CD (GitHub Actions + EKS)

### .github/workflows/deploy-k8s.yml

```yaml
name: Deploy to EKS

on:
  push:
    branches: [main]

env:
  AWS_REGION: ap-northeast-2
  EKS_CLUSTER_NAME: myapp-cluster
  ECR_REPOSITORY: myapp-backend

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build and push Docker image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG ./backend
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --name ${{ env.EKS_CLUSTER_NAME }} --region ${{ env.AWS_REGION }}

      - name: Deploy to EKS
        run: |
          kubectl set image deployment/backend backend=${{ steps.login-ecr.outputs.registry }}/${{ env.ECR_REPOSITORY }}:${{ github.sha }} -n myapp
          kubectl rollout status deployment/backend -n myapp
```

## 모니터링 및 로깅

### Prometheus + Grafana 설치

```bash
# Helm 리포지토리 추가
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Prometheus + Grafana 설치
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# Grafana 접속
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
```

## 트러블슈팅

### Pod가 Pending 상태

```bash
kubectl describe pod <pod-name> -n myapp
# 리소스 부족 또는 PVC 문제 확인
```

### ImagePullBackOff 에러

```bash
# 이미지 레지스트리 자격증명 생성
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n myapp
```

### CrashLoopBackOff

```bash
# 로그 확인
kubectl logs <pod-name> -n myapp --previous
```

## 참고 자료

- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [AWS EKS 공식 문서](https://docs.aws.amazon.com/eks/)
- [kubectl 치트시트](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
