#!/bin/bash

################################################################################
# 프론트엔드 배포 스크립트
# 용도: Nuxt/React/Next.js 프론트엔드를 S3+CloudFront 또는 ECS/EKS에 배포
# 사용법: ./deploy_frontend.sh [환경] [배포방법]
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
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# 기본값
ENVIRONMENT="${1:-staging}"
DEPLOY_METHOD="${2:-s3}"
TAG="${TAG:-latest}"

# AWS 설정
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
S3_BUCKET="${S3_BUCKET:-myapp-${ENVIRONMENT}-frontend}"
CLOUDFRONT_DISTRIBUTION_ID="${CLOUDFRONT_DISTRIBUTION_ID:-}"
ECR_REGISTRY="${ECR_REGISTRY:-}"
ECR_REPOSITORY="${ECR_REPOSITORY:-myapp-frontend}"
ECS_CLUSTER="${ECS_CLUSTER:-myapp-${ENVIRONMENT}-cluster}"
ECS_SERVICE="${ECS_SERVICE:-frontend-${ENVIRONMENT}}"
K8S_NAMESPACE="${K8S_NAMESPACE:-myapp-${ENVIRONMENT}}"

# 도움말 출력
show_help() {
    cat << EOF
프론트엔드 배포 스크립트

사용법:
    ./deploy_frontend.sh [ENVIRONMENT] [DEPLOY_METHOD]

인자:
    ENVIRONMENT     배포 환경 (dev|staging|production, 기본값: staging)
    DEPLOY_METHOD   배포 방법 (s3|ecs|eks, 기본값: s3)

환경변수:
    AWS_REGION                   AWS 리전 (기본값: ap-northeast-2)
    S3_BUCKET                    S3 버킷 이름 (기본값: myapp-{ENVIRONMENT}-frontend)
    CLOUDFRONT_DISTRIBUTION_ID   CloudFront 배포 ID
    ECR_REGISTRY                 ECR 레지스트리 URL
    ECR_REPOSITORY               ECR 리포지토리 이름 (기본값: myapp-frontend)
    ECS_CLUSTER                  ECS 클러스터 이름
    ECS_SERVICE                  ECS 서비스 이름
    K8S_NAMESPACE                Kubernetes 네임스페이스
    TAG                          이미지 태그 (기본값: latest)
    SKIP_BUILD                   빌드 스킵 (기본값: 0)
    API_BASE_URL                 API 베이스 URL

예시:
    # 스테이징 S3 배포
    export API_BASE_URL=https://api-staging.example.com
    ./deploy_frontend.sh staging s3

    # 프로덕션 ECS 배포
    export API_BASE_URL=https://api.example.com
    ./deploy_frontend.sh production ecs

    # CloudFront 캐시 무효화
    export CLOUDFRONT_DISTRIBUTION_ID=E1234567890ABC
    ./deploy_frontend.sh production s3
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

    # Node.js 확인
    if [ "${SKIP_BUILD:-0}" -eq 0 ]; then
        if ! command -v node &> /dev/null; then
            log_error "Node.js가 설치되어 있지 않습니다."
            exit 1
        fi

        if ! command -v pnpm &> /dev/null; then
            log_error "pnpm이 설치되어 있지 않습니다."
            log_info "npm install -g pnpm 을 실행하여 설치하세요."
            exit 1
        fi
    fi

    # Docker 확인 (컨테이너 배포 시)
    if [[ "$DEPLOY_METHOD" == "ecs" || "$DEPLOY_METHOD" == "eks" ]]; then
        if ! command -v docker &> /dev/null; then
            log_error "Docker가 설치되어 있지 않습니다."
            exit 1
        fi
    fi

    # AWS 자격증명 확인
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS 자격증명이 설정되지 않았습니다."
        exit 1
    fi

    log_info "사전 확인 완료"
}

# 프론트엔드 빌드
build_frontend() {
    if [ "${SKIP_BUILD:-0}" -eq 1 ]; then
        log_warn "빌드를 스킵합니다."
        return
    fi

    log_step "프론트엔드 빌드 중..."

    cd "$FRONTEND_DIR"

    # 의존성 설치
    log_info "의존성 설치 중..."
    pnpm install --frozen-lockfile

    # 환경변수 설정
    if [ -n "$API_BASE_URL" ]; then
        export NUXT_PUBLIC_API_BASE_URL="$API_BASE_URL"
        log_info "API 베이스 URL: $API_BASE_URL"
    fi

    # 빌드
    log_info "프로젝트 빌드 중..."

    if [ "$DEPLOY_METHOD" == "s3" ]; then
        # 정적 사이트 생성 (SSG)
        pnpm build  # 또는 pnpm generate (Nuxt static)
    else
        # SSR 빌드
        pnpm build
    fi

    if [ $? -eq 0 ]; then
        log_info "프론트엔드 빌드 성공"
    else
        log_error "프론트엔드 빌드 실패"
        exit 1
    fi
}

# S3 배포
deploy_to_s3() {
    log_step "S3에 배포 중..."

    cd "$FRONTEND_DIR"

    # 빌드 출력 디렉토리 확인
    if [ -d ".output/public" ]; then
        BUILD_DIR=".output/public"
    elif [ -d "dist" ]; then
        BUILD_DIR="dist"
    elif [ -d ".next/static" ]; then
        BUILD_DIR=".next/static"
    else
        log_error "빌드 출력 디렉토리를 찾을 수 없습니다."
        exit 1
    fi

    log_info "빌드 디렉토리: $BUILD_DIR"
    log_info "S3 버킷: $S3_BUCKET"

    # S3 버킷 확인
    if ! aws s3 ls "s3://$S3_BUCKET" &> /dev/null; then
        log_warn "S3 버킷이 존재하지 않습니다. 생성 중..."
        aws s3 mb "s3://$S3_BUCKET" --region "$AWS_REGION"

        # 정적 웹사이트 호스팅 활성화
        aws s3 website "s3://$S3_BUCKET" \
            --index-document index.html \
            --error-document index.html
    fi

    # S3 동기화
    log_info "S3 동기화 중..."
    aws s3 sync "$BUILD_DIR" "s3://$S3_BUCKET" \
        --delete \
        --region "$AWS_REGION" \
        --cache-control "public, max-age=31536000, immutable" \
        --exclude "index.html" \
        --exclude "*.html"

    # HTML 파일 업로드 (캐시 없음)
    aws s3 sync "$BUILD_DIR" "s3://$S3_BUCKET" \
        --region "$AWS_REGION" \
        --cache-control "public, max-age=0, must-revalidate" \
        --include "*.html"

    if [ $? -eq 0 ]; then
        log_info "S3 업로드 성공"
    else
        log_error "S3 업로드 실패"
        exit 1
    fi

    # CloudFront 캐시 무효화
    if [ -n "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
        log_info "CloudFront 캐시 무효화 중..."

        INVALIDATION_ID=$(aws cloudfront create-invalidation \
            --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
            --paths "/*" \
            --query 'Invalidation.Id' \
            --output text)

        log_info "무효화 ID: $INVALIDATION_ID"

        # 무효화 완료 대기 (선택사항)
        if [ "${WAIT_INVALIDATION:-0}" -eq 1 ]; then
            log_info "무효화 완료 대기 중..."
            aws cloudfront wait invalidation-completed \
                --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
                --id "$INVALIDATION_ID"

            log_info "CloudFront 캐시 무효화 완료"
        else
            log_info "CloudFront 캐시 무효화 시작됨 (백그라운드)"
        fi
    fi

    # URL 출력
    log_info "배포 완료!"
    if [ -n "$CLOUDFRONT_DISTRIBUTION_ID" ]; then
        CF_DOMAIN=$(aws cloudfront get-distribution \
            --id "$CLOUDFRONT_DISTRIBUTION_ID" \
            --query 'Distribution.DomainName' \
            --output text)
        log_info "CloudFront URL: https://$CF_DOMAIN"
    else
        log_info "S3 URL: http://$S3_BUCKET.s3-website-$AWS_REGION.amazonaws.com"
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

    cd "$FRONTEND_DIR"

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

    kubectl set image deployment/frontend \
        frontend="$IMAGE_NAME" \
        -n "$K8S_NAMESPACE"

    if [ $? -ne 0 ]; then
        log_error "Deployment 업데이트 실패"
        exit 1
    fi

    # 롤아웃 상태 확인
    log_info "롤아웃 진행 중..."
    kubectl rollout status deployment/frontend \
        -n "$K8S_NAMESPACE" \
        --timeout=10m

    if [ $? -eq 0 ]; then
        log_info "EKS 배포 성공!"

        # Pod 상태 확인
        log_info "Pod 상태:"
        kubectl get pods -n "$K8S_NAMESPACE" -l app=frontend
    else
        log_error "EKS 배포 실패"
        exit 1
    fi
}

# 배포 후 검증
verify_deployment() {
    log_step "배포 검증 중..."

    case "$DEPLOY_METHOD" in
        s3)
            # S3 버킷 확인
            OBJECT_COUNT=$(aws s3 ls "s3://$S3_BUCKET" --recursive | wc -l)
            log_info "S3 객체 수: $OBJECT_COUNT"
            ;;
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
            READY_PODS=$(kubectl get deployment frontend \
                -n "$K8S_NAMESPACE" \
                -o jsonpath='{.status.readyReplicas}')

            log_info "준비된 Pod: $READY_PODS"
            ;;
    esac

    log_info "배포 검증 완료"
}

# 메인 실행
main() {
    log_info "========================================="
    log_info "프론트엔드 배포 스크립트"
    log_info "환경: $ENVIRONMENT"
    log_info "배포 방법: $DEPLOY_METHOD"
    log_info "========================================="

    # 사전 확인
    check_prerequisites

    # 빌드
    if [ "${SKIP_BUILD:-0}" -eq 0 ]; then
        build_frontend
    fi

    # 배포
    case "$DEPLOY_METHOD" in
        s3)
            deploy_to_s3
            ;;
        ecs)
            build_and_push_image
            deploy_to_ecs
            ;;
        eks)
            build_and_push_image
            deploy_to_eks
            ;;
        *)
            log_error "잘못된 배포 방법: $DEPLOY_METHOD (s3|ecs|eks만 가능)"
            show_help
            exit 1
            ;;
    esac

    # 검증
    verify_deployment

    log_info "========================================="
    log_info "프론트엔드 배포 완료!"
    log_info "========================================="
}

# 스크립트 실행
main
