#!/bin/bash

################################################################################
# 공공 프로젝트 통합 빌드 스크립트
#
# 이 스크립트는 다음 작업을 수행합니다:
# 1. Nuxt 4 프론트엔드 빌드
# 2. 빌드 결과물을 Spring Boot static 폴더로 복사
# 3. Spring Boot WAR 패키징 (Gradle 사용)
#
# 프로젝트 구조:
#   project-root/
#   ├── frontend/              # Nuxt 4 프로젝트
#   ├── src/                   # Spring Boot 백엔드
#   └── build.gradle.kts       # Gradle 빌드 설정
#
# 사용법: ./build_with_nuxt.sh [옵션]
# 옵션:
#   -s, --skip-tests    테스트 건너뛰기 (기본값: 건너뜀)
#   -t, --run-tests     테스트 실행
#   -c, --clean         빌드 전 clean 실행 (기본값: 실행)
#   -p, --profile       빌드 프로파일 지정 (기본값: local)
################################################################################

set -e  # 에러 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 기본 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 스크립트가 plugins/sef-2026-public/skills/backend/scripts 에 있을 경우
# 실제 프로젝트 루트로 이동 (5단계 상위)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
STATIC_DIR="$PROJECT_ROOT/src/main/resources/static"
SKIP_TESTS=true
CLEAN_BUILD=true
BUILD_PROFILE="local"

# 함수: 사용법 출력
usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  -s, --skip-tests    테스트 건너뛰기 (기본값: 건너뜀)"
    echo "  -t, --run-tests     테스트 실행"
    echo "  -c, --clean         빌드 전 clean 실행 (기본값: 실행)"
    echo "  -p, --profile NAME  빌드 프로파일 지정 (기본값: local)"
    echo "  -h, --help          도움말 출력"
    exit 1
}

# 함수: 로그 출력
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 함수: 에러 처리
error_exit() {
    log_error "$1"
    exit 1
}

# 명령행 인수 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -t|--run-tests)
            SKIP_TESTS=false
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -p|--profile)
            BUILD_PROFILE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            usage
            ;;
    esac
done

# 배너 출력
echo ""
echo "=========================================="
echo "  sqisoft-sef-2026 통합 빌드"
echo "=========================================="
echo "프로젝트 루트: $PROJECT_ROOT"
echo "빌드 프로파일: $BUILD_PROFILE"
echo "테스트 건너뛰기: $SKIP_TESTS"
echo "Clean 빌드: $CLEAN_BUILD"
echo "=========================================="
echo ""

# 1. 디렉토리 존재 확인
log "디렉토리 확인 중..."
if [ ! -d "$FRONTEND_DIR" ]; then
    error_exit "프론트엔드 디렉토리를 찾을 수 없습니다: $FRONTEND_DIR"
fi

if [ ! -f "$FRONTEND_DIR/package.json" ]; then
    error_exit "package.json을 찾을 수 없습니다: $FRONTEND_DIR/package.json"
fi

if [ ! -f "$PROJECT_ROOT/build.gradle.kts" ]; then
    error_exit "build.gradle.kts를 찾을 수 없습니다: $PROJECT_ROOT/build.gradle.kts"
fi

log_success "디렉토리 확인 완료"

# 2. Nuxt 4 프론트엔드 빌드
echo ""
log "=========================================="
log "1단계: Nuxt 4 프론트엔드 빌드"
log "=========================================="

cd "$FRONTEND_DIR" || error_exit "프론트엔드 디렉토리로 이동 실패"

# Node.js 버전 확인
if ! command -v node &> /dev/null; then
    error_exit "Node.js가 설치되어 있지 않습니다."
fi

NODE_VERSION=$(node -v)
log "Node.js 버전: $NODE_VERSION"

# npm 의존성 설치
log "npm 패키지 설치 중..."
if [ -f "package-lock.json" ]; then
    npm ci || npm install || error_exit "npm 패키지 설치 실패"
else
    npm install || error_exit "npm install 실패"
fi
log_success "npm 패키지 설치 완료"

# 환경 변수 설정
export NODE_ENV=production
log "환경 변수: NODE_ENV=$NODE_ENV"

# Nuxt 빌드
log "Nuxt 빌드 중..."
npm run build || error_exit "Nuxt 빌드 실패"
log_success "Nuxt 빌드 완료"

# 빌드 결과 확인
OUTPUT_DIR="$FRONTEND_DIR/.output/public"
if [ ! -d "$OUTPUT_DIR" ]; then
    error_exit "빌드 출력 디렉토리를 찾을 수 없습니다: $OUTPUT_DIR"
fi

if [ ! -f "$OUTPUT_DIR/index.html" ]; then
    log_warning "index.html을 찾을 수 없습니다. 빌드가 제대로 완료되지 않았을 수 있습니다."
fi

# 3. 빌드 파일 복사
echo ""
log "=========================================="
log "2단계: 빌드 파일 복사"
log "=========================================="

# static 디렉토리 생성
mkdir -p "$STATIC_DIR" || error_exit "static 디렉토리 생성 실패"

# 기존 파일 삭제
if [ "$(ls -A "$STATIC_DIR" 2>/dev/null)" ]; then
    log "기존 파일 삭제 중..."
    rm -rf "${STATIC_DIR:?}"/* || log_warning "기존 파일 삭제 실패"
fi

# 빌드 파일 복사
log "빌드 파일 복사 중..."
cp -r "$OUTPUT_DIR"/* "$STATIC_DIR/" || error_exit "파일 복사 실패"
log_success "빌드 파일 복사 완료"

# 복사된 파일 확인
FILE_COUNT=$(find "$STATIC_DIR" -type f | wc -l)
log "복사된 파일 수: $FILE_COUNT"

# 4. Spring Boot WAR 패키징
echo ""
log "=========================================="
log "3단계: Spring Boot WAR 패키징 (Gradle)"
log "=========================================="

cd "$PROJECT_ROOT" || error_exit "프로젝트 루트로 이동 실패"

# Gradle Wrapper 확인
GRADLE_CMD="gradle"
if [ -f "$PROJECT_ROOT/gradlew" ]; then
    GRADLE_CMD="./gradlew"
    chmod +x "$PROJECT_ROOT/gradlew" 2>/dev/null || true
fi

# Gradle 빌드 명령어 구성
GRADLE_ARGS=""
[ "$CLEAN_BUILD" == true ] && GRADLE_ARGS="clean "
GRADLE_ARGS="${GRADLE_ARGS}build"
[ "$SKIP_TESTS" == true ] && GRADLE_ARGS="$GRADLE_ARGS -x test"
[ -n "$BUILD_PROFILE" ] && GRADLE_ARGS="$GRADLE_ARGS -Pprofile=$BUILD_PROFILE"

log "Gradle 빌드 실행: $GRADLE_CMD $GRADLE_ARGS"
$GRADLE_CMD $GRADLE_ARGS || error_exit "Gradle 빌드 실패"

WAR_FILE=$(find "$PROJECT_ROOT/build/libs" -name "*.war" 2>/dev/null | head -n 1)

log_success "Spring Boot WAR 패키징 완료"

# 5. 빌드 결과 출력
echo ""
echo "=========================================="
log_success "빌드 완료!"
echo "=========================================="

if [ -n "$WAR_FILE" ] && [ -f "$WAR_FILE" ]; then
    WAR_SIZE=$(du -h "$WAR_FILE" | cut -f1)
    echo "WAR 파일: $WAR_FILE"
    echo "파일 크기: $WAR_SIZE"
    echo ""
    echo "WAR 파일 내용 확인:"
    echo "  jar -tf \"$WAR_FILE\" | grep static | head -20"
    echo ""

    # 실제로 static 파일 확인
    echo "포함된 static 파일 (상위 15개):"
    jar -tf "$WAR_FILE" | grep "WEB-INF/classes/static" | head -15 || echo "  (static 파일 없음)"
    echo ""

    echo "로컬 실행:"
    echo "  java -jar \"$WAR_FILE\""
    echo ""
    echo "브라우저 접속:"
    echo "  http://localhost:7171"
else
    log_warning "WAR 파일을 찾을 수 없습니다."
fi

echo ""
echo "=========================================="
echo ""

exit 0
