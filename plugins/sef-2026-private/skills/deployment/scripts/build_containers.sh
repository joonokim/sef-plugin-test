#!/bin/bash

################################################################################
# Docker 컨테이너 빌드 스크립트
# 용도: 백엔드 및 프론트엔드 Docker 이미지 빌드 및 레지스트리 푸시
# 사용법: ./build_containers.sh [backend|frontend|all] [tag]
################################################################################

set -e  # 에러 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# 환경변수 설정
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_DIR="$PROJECT_ROOT/backend"
FRONTEND_DIR="$PROJECT_ROOT/frontend"

# 기본값
TARGET="${1:-all}"
TAG="${2:-latest}"
REGISTRY="${REGISTRY:-}"
BACKEND_IMAGE_NAME="${BACKEND_IMAGE_NAME:-myapp-backend}"
FRONTEND_IMAGE_NAME="${FRONTEND_IMAGE_NAME_NAME:-myapp-frontend}"

# 도움말 출력
show_help() {
    cat << EOF
Docker 컨테이너 빌드 스크립트

사용법:
    ./build_containers.sh [TARGET] [TAG]

인자:
    TARGET      빌드 대상 (backend|frontend|all, 기본값: all)
    TAG         이미지 태그 (기본값: latest)

환경변수:
    REGISTRY              Docker 레지스트리 URL (예: 123456789012.dkr.ecr.ap-northeast-2.amazonaws.com)
    BACKEND_IMAGE_NAME    백엔드 이미지 이름 (기본값: myapp-backend)
    FRONTEND_IMAGE_NAME   프론트엔드 이미지 이름 (기본값: myapp-frontend)
    DOCKER_BUILDKIT       BuildKit 사용 여부 (기본값: 1)
    SKIP_TESTS            테스트 스킵 여부 (기본값: 0)

예시:
    # 모든 컨테이너 빌드
    ./build_containers.sh all latest

    # 백엔드만 빌드
    ./build_containers.sh backend v1.0.0

    # ECR에 푸시
    export REGISTRY=123456789012.dkr.ecr.ap-northeast-2.amazonaws.com
    ./build_containers.sh all latest

    # 테스트 스킵
    export SKIP_TESTS=1
    ./build_containers.sh backend latest
EOF
}

# 도움말 요청 확인
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Docker 설치 확인
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker가 설치되어 있지 않습니다."
        exit 1
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker 데몬이 실행 중이지 않습니다."
        exit 1
    fi

    log_info "Docker 버전: $(docker --version)"
}

# ECR 로그인
login_ecr() {
    if [[ -n "$REGISTRY" && "$REGISTRY" == *"ecr"* ]]; then
        log_info "ECR에 로그인 중..."

        # AWS 리전 추출
        REGION=$(echo "$REGISTRY" | cut -d'.' -f4)

        aws ecr get-login-password --region "$REGION" | \
            docker login --username AWS --password-stdin "$REGISTRY"

        if [ $? -eq 0 ]; then
            log_info "ECR 로그인 성공"
        else
            log_error "ECR 로그인 실패"
            exit 1
        fi
    fi
}

# 백엔드 빌드
build_backend() {
    log_info "======================="
    log_info "백엔드 이미지 빌드 시작"
    log_info "======================="

    if [ ! -d "$BACKEND_DIR" ]; then
        log_error "백엔드 디렉토리를 찾을 수 없습니다: $BACKEND_DIR"
        exit 1
    fi

    cd "$BACKEND_DIR"

    # 이미지 이름 설정
    if [ -n "$REGISTRY" ]; then
        IMAGE_NAME="$REGISTRY/$BACKEND_IMAGE_NAME"
    else
        IMAGE_NAME="$BACKEND_IMAGE_NAME"
    fi

    log_info "이미지 이름: $IMAGE_NAME:$TAG"

    # 빌드 인자 설정
    BUILD_ARGS=""
    if [ "${SKIP_TESTS:-0}" -eq 1 ]; then
        log_warn "테스트를 스킵합니다."
        BUILD_ARGS="--build-arg MAVEN_OPTS=-Dmaven.test.skip=true"
    fi

    # Docker 빌드
    log_info "Docker 이미지 빌드 중..."
    DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}" docker build \
        $BUILD_ARGS \
        -t "$IMAGE_NAME:$TAG" \
        -t "$IMAGE_NAME:latest" \
        -f Dockerfile \
        .

    if [ $? -eq 0 ]; then
        log_info "백엔드 이미지 빌드 성공: $IMAGE_NAME:$TAG"
    else
        log_error "백엔드 이미지 빌드 실패"
        exit 1
    fi

    # 레지스트리에 푸시
    if [ -n "$REGISTRY" ]; then
        log_info "이미지를 레지스트리에 푸시 중..."
        docker push "$IMAGE_NAME:$TAG"
        docker push "$IMAGE_NAME:latest"

        if [ $? -eq 0 ]; then
            log_info "이미지 푸시 성공"
        else
            log_error "이미지 푸시 실패"
            exit 1
        fi
    fi

    log_info "백엔드 빌드 완료"
}

# 프론트엔드 빌드
build_frontend() {
    log_info "========================="
    log_info "프론트엔드 이미지 빌드 시작"
    log_info "========================="

    if [ ! -d "$FRONTEND_DIR" ]; then
        log_error "프론트엔드 디렉토리를 찾을 수 없습니다: $FRONTEND_DIR"
        exit 1
    fi

    cd "$FRONTEND_DIR"

    # 이미지 이름 설정
    if [ -n "$REGISTRY" ]; then
        IMAGE_NAME="$REGISTRY/$FRONTEND_IMAGE_NAME"
    else
        IMAGE_NAME="$FRONTEND_IMAGE_NAME"
    fi

    log_info "이미지 이름: $IMAGE_NAME:$TAG"

    # Docker 빌드
    log_info "Docker 이미지 빌드 중..."
    DOCKER_BUILDKIT="${DOCKER_BUILDKIT:-1}" docker build \
        -t "$IMAGE_NAME:$TAG" \
        -t "$IMAGE_NAME:latest" \
        -f Dockerfile \
        .

    if [ $? -eq 0 ]; then
        log_info "프론트엔드 이미지 빌드 성공: $IMAGE_NAME:$TAG"
    else
        log_error "프론트엔드 이미지 빌드 실패"
        exit 1
    fi

    # 레지스트리에 푸시
    if [ -n "$REGISTRY" ]; then
        log_info "이미지를 레지스트리에 푸시 중..."
        docker push "$IMAGE_NAME:$TAG"
        docker push "$IMAGE_NAME:latest"

        if [ $? -eq 0 ]; then
            log_info "이미지 푸시 성공"
        else
            log_error "이미지 푸시 실패"
            exit 1
        fi
    fi

    log_info "프론트엔드 빌드 완료"
}

# 이미지 정보 출력
show_images() {
    log_info "빌드된 이미지:"

    if [ -n "$REGISTRY" ]; then
        docker images | grep "$REGISTRY" | grep -E "$BACKEND_IMAGE_NAME|$FRONTEND_IMAGE_NAME"
    else
        docker images | grep -E "$BACKEND_IMAGE_NAME|$FRONTEND_IMAGE_NAME"
    fi
}

# 메인 실행
main() {
    log_info "Docker 컨테이너 빌드 스크립트 시작"
    log_info "대상: $TARGET, 태그: $TAG"

    # Docker 확인
    check_docker

    # ECR 로그인
    if [ -n "$REGISTRY" ]; then
        login_ecr
    fi

    # 빌드 실행
    case "$TARGET" in
        backend)
            build_backend
            ;;
        frontend)
            build_frontend
            ;;
        all)
            build_backend
            build_frontend
            ;;
        *)
            log_error "잘못된 대상: $TARGET (backend|frontend|all만 가능)"
            show_help
            exit 1
            ;;
    esac

    # 빌드된 이미지 출력
    show_images

    log_info "모든 빌드 완료!"
}

# 스크립트 실행
main
