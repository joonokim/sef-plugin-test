# AWS 배포 가이드

민간 섹터 프로젝트를 AWS에 배포하는 상세 가이드입니다. ECS, EKS, EC2, S3+CloudFront 등 다양한 배포 옵션을 다룹니다.

## 배포 아키텍처 개요

### 옵션 1: ECS Fargate (권장)

- 서버리스 컨테이너 오케스트레이션
- 인프라 관리 불필요
- 자동 스케일링
- 비용 효율적

### 옵션 2: EKS (Kubernetes)

- 복잡한 마이크로서비스에 적합
- Kubernetes 완전 제어
- 멀티 클라우드 호환성

### 옵션 3: EC2

- 전통적인 VM 기반
- 완전한 제어
- 레거시 애플리케이션 마이그레이션

### 옵션 4: S3 + CloudFront (프론트엔드)

- 정적 사이트 호스팅
- 글로벌 CDN
- 최고의 성능

## 사전 준비

### 1. AWS CLI 설치 및 구성

```bash
# AWS CLI 설치 (Windows)
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi

# AWS CLI 설치 (macOS)
brew install awscli

# AWS CLI 설치 (Linux)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 자격 증명 구성
aws configure
# AWS Access Key ID: YOUR_ACCESS_KEY
# AWS Secret Access Key: YOUR_SECRET_KEY
# Default region name: ap-northeast-2
# Default output format: json
```

### 2. Docker 이미지 레지스트리 (ECR) 설정

```bash
# ECR 리포지토리 생성
aws ecr create-repository --repository-name myapp-backend
aws ecr create-repository --repository-name myapp-frontend

# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.ap-northeast-2.amazonaws.com

# Docker 이미지 빌드 및 푸시
docker build -t myapp-backend ./backend
docker tag myapp-backend:latest \
  123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/myapp-backend:latest
docker push 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/myapp-backend:latest
```

## ECS Fargate 배포 (권장)

### 1. VPC 및 네트워크 설정

```bash
# VPC 생성
aws ec2 create-vpc --cidr-block 10.0.0.0/16

# 서브넷 생성
aws ec2 create-subnet --vpc-id vpc-xxxxx --cidr-block 10.0.1.0/24 --availability-zone ap-northeast-2a
aws ec2 create-subnet --vpc-id vpc-xxxxx --cidr-block 10.0.2.0/24 --availability-zone ap-northeast-2b

# 인터넷 게이트웨이 생성
aws ec2 create-internet-gateway
aws ec2 attach-internet-gateway --vpc-id vpc-xxxxx --internet-gateway-id igw-xxxxx

# 라우트 테이블 설정
aws ec2 create-route-table --vpc-id vpc-xxxxx
aws ec2 create-route --route-table-id rtb-xxxxx --destination-cidr-block 0.0.0.0/0 --gateway-id igw-xxxxx
```

### 2. ECS 클러스터 생성

```bash
aws ecs create-cluster \
  --cluster-name myapp-cluster \
  --capacity-providers FARGATE FARGATE_SPOT \
  --default-capacity-provider-strategy \
    capacityProvider=FARGATE,weight=1 \
    capacityProvider=FARGATE_SPOT,weight=1
```

### 3. 태스크 정의 생성

#### backend-task-definition.json

```json
{
  "family": "myapp-backend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::123456789012:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::123456789012:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "backend",
      "image": "123456789012.dkr.ecr.ap-northeast-2.amazonaws.com/myapp-backend:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "SPRING_PROFILES_ACTIVE",
          "value": "prod"
        }
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:ap-northeast-2:123456789012:secret:db-password"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/myapp-backend",
          "awslogs-region": "ap-northeast-2",
          "awslogs-stream-prefix": "ecs"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
```

#### 태스크 정의 등록

```bash
aws ecs register-task-definition --cli-input-json file://backend-task-definition.json
```

### 4. Application Load Balancer 생성

```bash
# ALB 생성
aws elbv2 create-load-balancer \
  --name myapp-alb \
  --subnets subnet-xxxxx subnet-yyyyy \
  --security-groups sg-xxxxx \
  --scheme internet-facing \
  --type application

# 타겟 그룹 생성
aws elbv2 create-target-group \
  --name myapp-backend-tg \
  --protocol HTTP \
  --port 8080 \
  --vpc-id vpc-xxxxx \
  --target-type ip \
  --health-check-path /actuator/health

# 리스너 생성
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:loadbalancer/app/myapp-alb/xxxxx \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/myapp-backend-tg/xxxxx
```

### 5. ECS 서비스 생성

```bash
aws ecs create-service \
  --cluster myapp-cluster \
  --service-name myapp-backend \
  --task-definition myapp-backend:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxxxx,subnet-yyyyy],securityGroups=[sg-xxxxx],assignPublicIp=ENABLED}" \
  --load-balancers targetGroupArn=arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/myapp-backend-tg/xxxxx,containerName=backend,containerPort=8080 \
  --health-check-grace-period-seconds 60
```

### 6. Auto Scaling 설정

```bash
# 스케일링 타겟 등록
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/myapp-cluster/myapp-backend \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10

# CPU 기반 스케일링 정책
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/myapp-cluster/myapp-backend \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name cpu-scaling-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

#### scaling-policy.json

```json
{
  "TargetValue": 70.0,
  "PredefinedMetricSpecification": {
    "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
  },
  "ScaleOutCooldown": 60,
  "ScaleInCooldown": 60
}
```

## RDS 데이터베이스 설정

### 1. RDS 인스턴스 생성

```bash
aws rds create-db-instance \
  --db-instance-identifier myapp-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version 15.3 \
  --master-username admin \
  --master-user-password YourStrongPassword \
  --allocated-storage 20 \
  --vpc-security-group-ids sg-xxxxx \
  --db-subnet-group-name myapp-db-subnet-group \
  --backup-retention-period 7 \
  --preferred-backup-window "03:00-04:00" \
  --preferred-maintenance-window "mon:04:00-mon:05:00" \
  --storage-encrypted \
  --publicly-accessible false
```

### 2. Secrets Manager에 DB 자격증명 저장

```bash
aws secretsmanager create-secret \
  --name myapp-db-credentials \
  --description "Database credentials for MyApp" \
  --secret-string '{"username":"admin","password":"YourStrongPassword","host":"myapp-db.xxxxx.ap-northeast-2.rds.amazonaws.com","port":"5432","dbname":"mydb"}'
```

## S3 + CloudFront (프론트엔드 정적 배포)

### 1. S3 버킷 생성 및 설정

```bash
# S3 버킷 생성
aws s3 mb s3://myapp-frontend

# 정적 웹사이트 호스팅 활성화
aws s3 website s3://myapp-frontend --index-document index.html --error-document index.html

# 버킷 정책 설정 (CloudFront에서만 접근 가능하도록)
cat > bucket-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipal",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::myapp-frontend/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::123456789012:distribution/XXXXX"
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-policy --bucket myapp-frontend --policy file://bucket-policy.json
```

### 2. CloudFront 배포 생성

```bash
# OAC (Origin Access Control) 생성
aws cloudfront create-origin-access-control \
  --origin-access-control-config \
    Name=myapp-oac,\
    SigningProtocol=sigv4,\
    SigningBehavior=always,\
    OriginAccessControlOriginType=s3

# CloudFront 배포 생성
cat > cloudfront-config.json <<EOF
{
  "CallerReference": "myapp-frontend-$(date +%s)",
  "Comment": "MyApp Frontend Distribution",
  "DefaultRootObject": "index.html",
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "S3-myapp-frontend",
        "DomainName": "myapp-frontend.s3.ap-northeast-2.amazonaws.com",
        "S3OriginConfig": {
          "OriginAccessIdentity": ""
        },
        "OriginAccessControlId": "XXXXX"
      }
    ]
  },
  "DefaultCacheBehavior": {
    "TargetOriginId": "S3-myapp-frontend",
    "ViewerProtocolPolicy": "redirect-to-https",
    "AllowedMethods": {
      "Quantity": 2,
      "Items": ["GET", "HEAD"]
    },
    "ForwardedValues": {
      "QueryString": false,
      "Cookies": {
        "Forward": "none"
      }
    },
    "MinTTL": 0,
    "DefaultTTL": 86400,
    "MaxTTL": 31536000
  },
  "CustomErrorResponses": {
    "Quantity": 1,
    "Items": [
      {
        "ErrorCode": 404,
        "ResponsePagePath": "/index.html",
        "ResponseCode": "200",
        "ErrorCachingMinTTL": 300
      }
    ]
  },
  "Enabled": true,
  "PriceClass": "PriceClass_All"
}
EOF

aws cloudfront create-distribution --distribution-config file://cloudfront-config.json
```

### 3. 빌드 및 배포

```bash
# 프론트엔드 빌드
cd frontend
pnpm build

# S3에 업로드
aws s3 sync ./dist s3://myapp-frontend --delete

# CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id E1234567890ABC \
  --paths "/*"
```

## Route 53 도메인 설정

```bash
# Hosted Zone 생성
aws route53 create-hosted-zone \
  --name example.com \
  --caller-reference $(date +%s)

# A 레코드 생성 (ALB)
cat > change-batch.json <<EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "api.example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z123456789ABC",
          "DNSName": "myapp-alb-123456789.ap-northeast-2.elb.amazonaws.com",
          "EvaluateTargetHealth": true
        }
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id Z123456789ABC \
  --change-batch file://change-batch.json

# A 레코드 생성 (CloudFront)
cat > change-batch-cf.json <<EOF
{
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "www.example.com",
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": "Z2FDTNDATAQYW2",
          "DNSName": "d123456789.cloudfront.net",
          "EvaluateTargetHealth": false
        }
      }
    }
  ]
}
EOF

aws route53 change-resource-record-sets \
  --hosted-zone-id Z123456789ABC \
  --change-batch file://change-batch-cf.json
```

## ACM SSL 인증서 발급

```bash
# 인증서 요청
aws acm request-certificate \
  --domain-name example.com \
  --subject-alternative-names "*.example.com" \
  --validation-method DNS \
  --region ap-northeast-2

# DNS 검증 레코드 확인
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:ap-northeast-2:123456789012:certificate/xxxxx

# Route 53에 검증 레코드 추가 (자동)
# 또는 수동으로 CNAME 레코드 추가

# 인증서를 ALB에 연결
aws elbv2 create-listener \
  --load-balancer-arn arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:loadbalancer/app/myapp-alb/xxxxx \
  --protocol HTTPS \
  --port 443 \
  --certificates CertificateArn=arn:aws:acm:ap-northeast-2:123456789012:certificate/xxxxx \
  --default-actions Type=forward,TargetGroupArn=arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:targetgroup/myapp-backend-tg/xxxxx
```

## CloudWatch 모니터링 및 알림

### 1. 로그 그룹 생성

```bash
aws logs create-log-group --log-group-name /ecs/myapp-backend
aws logs create-log-group --log-group-name /ecs/myapp-frontend
```

### 2. CloudWatch Alarm 생성

```bash
# CPU 사용률 알람
aws cloudwatch put-metric-alarm \
  --alarm-name myapp-backend-cpu-high \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ServiceName,Value=myapp-backend Name=ClusterName,Value=myapp-cluster \
  --alarm-actions arn:aws:sns:ap-northeast-2:123456789012:alerts

# 메모리 사용률 알람
aws cloudwatch put-metric-alarm \
  --alarm-name myapp-backend-memory-high \
  --alarm-description "Alert when memory exceeds 80%" \
  --metric-name MemoryUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --evaluation-periods 2 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --dimensions Name=ServiceName,Value=myapp-backend Name=ClusterName,Value=myapp-cluster \
  --alarm-actions arn:aws:sns:ap-northeast-2:123456789012:alerts
```

### 3. SNS 토픽 생성 (알림)

```bash
# SNS 토픽 생성
aws sns create-topic --name myapp-alerts

# 이메일 구독
aws sns subscribe \
  --topic-arn arn:aws:sns:ap-northeast-2:123456789012:myapp-alerts \
  --protocol email \
  --notification-endpoint your-email@example.com
```

## 배포 자동화 (GitHub Actions)

### .github/workflows/deploy-backend.yml

```yaml
name: Deploy Backend to ECS

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'

env:
  AWS_REGION: ap-northeast-2
  ECR_REPOSITORY: myapp-backend
  ECS_CLUSTER: myapp-cluster
  ECS_SERVICE: myapp-backend
  CONTAINER_NAME: backend

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

      - name: Build, tag, and push image to Amazon ECR
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          cd backend
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster ${{ env.ECS_CLUSTER }} \
            --service ${{ env.ECS_SERVICE }} \
            --force-new-deployment
```

## 비용 최적화

### 1. Fargate Spot 사용

```bash
# Fargate Spot으로 비용 70% 절감
aws ecs update-service \
  --cluster myapp-cluster \
  --service myapp-backend \
  --capacity-provider-strategy \
    capacityProvider=FARGATE_SPOT,weight=1,base=0
```

### 2. S3 Intelligent-Tiering

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket myapp-frontend \
  --lifecycle-configuration file://lifecycle.json
```

### 3. CloudFront 가격 클래스 조정

- PriceClass_100: 미국, 캐나다, 유럽
- PriceClass_200: 위 + 아시아, 중동, 아프리카
- PriceClass_All: 전 세계 (기본값)

## 트러블슈팅

### ECS 태스크가 시작되지 않음

```bash
# 태스크 로그 확인
aws ecs describe-tasks \
  --cluster myapp-cluster \
  --tasks task-id

# CloudWatch Logs 확인
aws logs tail /ecs/myapp-backend --follow
```

### ALB Health Check 실패

- Health Check 경로 확인 (/actuator/health)
- 보안 그룹 인바운드 규칙 확인
- 컨테이너 포트 매핑 확인

### CloudFront 캐시 문제

```bash
# 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id E1234567890ABC \
  --paths "/*"
```

## 참고 자료

- [AWS ECS 공식 문서](https://docs.aws.amazon.com/ecs/)
- [AWS CloudFront 공식 문서](https://docs.aws.amazon.com/cloudfront/)
- 관련 스크립트: `scripts/deploy_backend.sh`, `scripts/deploy_frontend.sh`
