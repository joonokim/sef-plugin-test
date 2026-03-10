#!/bin/bash

################################################################################
# 백엔드 배포 스크립트
# 용도: Spring Boot 백엔드를 AWS ECS/EKS/EC2에 배포
# 사용법: ./deploy_backend.sh [환경] [배포방법]
################################################################################

set -e  # 에러 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 환경변수 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"

# 기본값
ENVIRONMENT="${1:-staging}"
DEPLOY_METHOD="${2:-ecs}"
TAG="${TAG:-latest}"

# AWS 설정
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
ECR_REGISTRY="${ECR_REGISTRY:-}"
ECR_REPOSITORY="${ECR_REPOSITORY:-myapp-backend}"
ECS_CLUSTER="${ECS_CLUSTER:-myapp-${ENVIRONMENT}-cluster}"
ECS_SERVICE="${ECS_SERVICE:-backend-${ENVIRONMENT}}"
K8S_NAMESPACE="${K8S_NAMESPACE:-myapp-${ENVIRONMENT}}"

# 도움말 출력
show_help() {
    cat << EOF
백엔드 배포 스크립트

사용법:
    ./deploy_backend.sh [ENVIRONMENT] [DEPLOY_METHOD]

인자:
    ENVIRONMENT     배포 환경 (dev|staging|production, 기본값: staging)
    DEPLOY_METHOD   배포 방법 (ecs|eks|ec2, 기본값: ecs)

환경변수:
    AWS_REGION           AWS 리전 (기본값: ap-northeast-2)
    ECR_REGISTRY         ECR 레지스트리 URL
    ECR_REPOSITORY       ECR 리포지토리 이름 (기본값: myapp-backend)
    ECS_CLUSTER          ECS 클러스터 이름 (기본값: myapp-{ENVIRONMENT}-cluster)
    ECS_SERVICE          ECS 서비스 이름 (기본값: backend-{ENVIRONMENT})
    K8S_NAMESPACE        Kubernetes 네임스페이스 (기본값: myapp-{ENVIRONMENT})
    TAG                  이미지 태그 (기본값: latest)
    SKIP_BUILD           빌드 스킵 (기본값: 0)
    SKIP_TESTS           테스트 스킵 (기본값: 0)

예시:
    # 스테이징 ECS 배포
    ./deploy_backend.sh staging ecs

    # 프로덕션 EKS 배포
    ./deploy_backend.sh production eks

    # 빌드 스킵하고 배포만
    export SKIP_BUILD=1
    ./deploy_backend.sh production ecs
EOF
}

# 도움말 요청 확인
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# 사전 확인
check_prerequisites() {
    log_step "사전 확인 중..."

    # AWS CLI 확인
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI가 설치되어 있지 않습니다."
        exit 1
    fi

    # Docker 확인
    if [ "${SKIP_BUILD:-0}" -eq 0 ]; then
        if ! command -v docker &> /dev/null; then
            log_error "Docker가 설치되어 있지 않습니다."
            exit 1
        fi
    fi

    # kubectl 확인 (EKS 배포 시)
    if [ "$DEPLOY_METHOD" == "eks" ]; then
        if ! command -v kubectl &> /dev/null; then
            log_error "kubectl이 설치되어 있지 않습니다."
            exit 1
        fi
    fi

    # AWS 자격증명 확인
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS 자격증명이 설정되지 않았습니다."
        log_info "aws configure를 실행하여 설정하세요."
        exit 1
    fi

    log_info "사전 확인 완료"
}

# 백엔드 빌드
build_backend() {
    if [ "${SKIP_BUILD:-0}" -eq 1 ]; then
        log_warn "빌드를 스킵합니다."
        return
    fi

    log_step "백엔드 빌드 중..."

    cd "$BACKEND_DIR"

    # Maven 빌드
    if [ "${SKIP_TESTS:-0}" -eq 1 ]; then
        log_warn "테스트를 스킵합니다."
        ./mvnw clean package -DskipTests
    else
        ./mvnw clean package
    fi

    if [ $? -eq 0 ]; then
        log_info "백엔드 빌드 성공"
    else
        log_error "백엔드 빌드 실패"
        exit 1
    fi
}

# Docker 이미지 빌드 및 푸시
build_and_push_image() {
    log_step "Docker 이미지 빌드 및 푸시 중..."

    # ECR 로그인
    log_info "ECR에 로그인 중..."
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$ECR_REGISTRY"

    if [ $? -ne 0 ]; then
        log_error "ECR 로그인 실패"
        exit 1
    fi

    cd "$BACKEND_DIR"

    # 이미지 빌드
    IMAGE_NAME="$ECR_REGISTRY/$ECR_REPOSITORY"
    log_info "이미지 빌드: $IMAGE_NAME:$TAG"

    docker build -t "$IMAGE_NAME:$TAG" .

    if [ $? -ne 0 ]; then
        log_error "Docker 이미지 빌드 실패"
        exit 1
    fi

    # latest 태그 추가
    docker tag "$IMAGE_NAME:$TAG" "$IMAGE_NAME:latest"

    # 이미지 푸시
    log_info "이미지 푸시 중..."
    docker push "$IMAGE_NAME:$TAG"
    docker push "$IMAGE_NAME:latest"

    if [ $? -eq 0 ]; then
        log_info "이미지 푸시 성공: $IMAGE_NAME:$TAG"
    else
        log_error "이미지 푸시 실패"
        exit 1
    fi
}

# ECS 배포
deploy_to_ecs() {
    log_step "ECS에 배포 중..."

    log_info "클러스터: $ECS_CLUSTER"
    log_info "서비스: $ECS_SERVICE"

    # 서비스 업데이트
    aws ecs update-service \
        --cluster "$ECS_CLUSTER" \
        --service "$ECS_SERVICE" \
        --force-new-deployment \
        --region "$AWS_REGION"

    if [ $? -ne 0 ]; then
        log_error "ECS 서비스 업데이트 실패"
        exit 1
    fi

    log_info "ECS 서비스 업데이트 시작됨"

    # 배포 상태 확인
    log_info "배포 완료 대기 중... (최대 10분)"
    aws ecs wait services-stable \
        --cluster "$ECS_CLUSTER" \
        --services "$ECS_SERVICE" \
        --region "$AWS_REGION" \
        --cli-read-timeout 600

    if [ $? -eq 0 ]; then
        log_info "ECS 배포 성공!"
    else
        log_error "ECS 배포 실패 또는 타임아웃"

        # 배포 이벤트 확인
        log_info "최근 이벤트:"
        aws ecs describe-services \
            --cluster "$ECS_CLUSTER" \
            --services "$ECS_SERVICE" \
            --region "$AWS_REGION" \
            --query 'services[0].events[:5]' \
            --output table

        exit 1
    fi
}

# EKS 배포
deploy_to_eks() {
    log_step "EKS에 배포 중..."

    # kubeconfig 업데이트
    log_info "kubeconfig 업데이트 중..."
    aws eks update-kubeconfig \
        --name "$ECS_CLUSTER" \
        --region "$AWS_REGION"

    if [ $? -ne 0 ]; then
        log_error "kubeconfig 업데이트 실패"
        exit 1
    fi

    # Deployment 이미지 업데이트
    IMAGE_NAME="$ECR_REGISTRY/$ECR_REPOSITORY:$TAG"
    log_info "Deployment 이미지 업데이트: $IMAGE_NAME"

    kubectl set image deployment/backend \
        backend="$IMAGE_NAME" \
        -n "$K8S_NAMESPACE"

    if [ $? -ne 0 ]; then
        log_error "Deployment 업데이트 실패"
        exit 1
    fi

    # 롤아웃 상태 확인
    log_info "롤아웃 진행 중..."
    kubectl rollout status deployment/backend \
        -n "$K8S_NAMESPACE" \
        --timeout=10m

    if [ $? -eq 0 ]; then
        log_info "EKS 배포 성공!"

        # Pod 상태 확인
        log_info "Pod 상태:"
        kubectl get pods -n "$K8S_NAMESPACE" -l app=backend
    else
        log_error "EKS 배포 실패"

        # 실패한 Pod 로그 확인
        log_info "실패한 Pod 로그:"
        kubectl logs -n "$K8S_NAMESPACE" -l app=backend --tail=50

        exit 1
    fi
}

# EC2 배포
deploy_to_ec2() {
    log_step "EC2에 배포 중..."

    log_warn "EC2 배포는 SSH를 통해 수동으로 진행됩니다."

    # EC2 인스턴스 정보
    INSTANCE_ID="${EC2_INSTANCE_ID:-}"
    INSTANCE_IP="${EC2_INSTANCE_IP:-}"

    if [ -z "$INSTANCE_ID" ] && [ -z "$INSTANCE_IP" ]; then
        log_error "EC2_INSTANCE_ID 또는 EC2_INSTANCE_IP 환경변수가 설정되지 않았습니다."
        exit 1
    fi

    # SSH 키 경로
    SSH_KEY="${SSH_KEY:-~/.ssh/myapp.pem}"

    if [ ! -f "$SSH_KEY" ]; then
        log_error "SSH 키를 찾을 수 없습니다: $SSH_KEY"
        exit 1
    fi

    # 인스턴스 IP 가져오기
    if [ -z "$INSTANCE_IP" ]; then
        INSTANCE_IP=$(aws ec2 describe-instances \
            --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' \
            --output text \
            --region "$AWS_REGION")
    fi

    log_info "EC2 인스턴스: $INSTANCE_IP"

    # SSH로 배포 명령 실행
    log_info "SSH로 배포 스크립트 실행 중..."

    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "ec2-user@$INSTANCE_IP" << 'EOF'
        set -e

        # Docker 이미지 풀
        echo "Docker 이미지 풀링 중..."
        aws ecr get-login-password --region ${AWS_REGION} | \
            docker login --username AWS --password-stdin ${ECR_REGISTRY}

        docker pull ${ECR_REGISTRY}/${ECR_REPOSITORY}:${TAG}

        # 기존 컨테이너 중지 및 제거
        echo "기존 컨테이너 중지 중..."
        docker stop myapp-backend || true
        docker rm myapp-backend || true

        # 새 컨테이너 실행
        echo "새 컨테이너 시작 중..."
        docker run -d \
            --name myapp-backend \
            --restart unless-stopped \
            -p 8080:8080 \
            -e SPRING_PROFILES_ACTIVE=prod \
            ${ECR_REGISTRY}/${ECR_REPOSITORY}:${TAG}

        # 헬스체크
        echo "헬스체크 대기 중..."
        sleep 10

        curl -f http://localhost:8080/actuator/health || exit 1

        echo "배포 완료!"
EOF

    if [ $? -eq 0 ]; then
        log_info "EC2 배포 성공!"
    else
        log_error "EC2 배포 실패"
        exit 1
    fi
}

# 배포 후 검증
verify_deployment() {
    log_step "배포 검증 중..."

    case "$DEPLOY_METHOD" in
        ecs)
            # ECS 태스크 상태 확인
            RUNNING_COUNT=$(aws ecs describe-services \
                --cluster "$ECS_CLUSTER" \
                --services "$ECS_SERVICE" \
                --region "$AWS_REGION" \
                --query 'services[0].runningCount' \
                --output text)

            log_info "실행 중인 태스크: $RUNNING_COUNT"
            ;;
        eks)
            # Pod 상태 확인
            READY_PODS=$(kubectl get deployment backend \
                -n "$K8S_NAMESPACE" \
                -o jsonpath='{.status.readyReplicas}')

            log_info "준비된 Pod: $READY_PODS"
            ;;
        ec2)
            # 헬스체크
            if curl -f "http://$INSTANCE_IP:8080/actuator/health"; then
                log_info "헬스체크 성공"
            else
                log_warn "헬스체크 실패"
            fi
            ;;
    esac

    log_info "배포 검증 완료"
}

# 메인 실행
main() {
    log_info "========================================="
    log_info "백엔드 배포 스크립트"
    log_info "환경: $ENVIRONMENT"
    log_info "배포 방법: $DEPLOY_METHOD"
    log_info "========================================="

    # 사전 확인
    check_prerequisites

    # 빌드
    if [ "${SKIP_BUILD:-0}" -eq 0 ]; then
        build_backend
        build_and_push_image
    fi

    # 배포
    case "$DEPLOY_METHOD" in
        ecs)
            deploy_to_ecs
            ;;
        eks)
            deploy_to_eks
            ;;
        ec2)
            deploy_to_ec2
            ;;
        *)
            log_error "잘못된 배포 방법: $DEPLOY_METHOD (ecs|eks|ec2만 가능)"
            show_help
            exit 1
            ;;
    esac

    # 검증
    verify_deployment

    log_info "========================================="
    log_info "백엔드 배포 완료!"
    log_info "========================================="
}

# 스크립트 실행
main
