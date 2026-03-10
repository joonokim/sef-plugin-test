#!/bin/bash

################################################################################
# WAR 파일 빌드 스크립트
#
# 이 스크립트는 다음 작업을 수행합니다:
# 1. Nuxt 4 프론트엔드 빌드
# 2. 빌드 결과물을 Spring Boot static 폴더로 복사
# 3. Spring Boot WAR 패키징
#
# 사용법: ./build_war.sh [옵션]
################################################################################

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 기본 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
STATIC_DIR="$PROJECT_ROOT/src/main/resources/static"
BUILD_TOOL="maven"
SKIP_TESTS=false
CLEAN_BUILD=true
BUILD_PROFILE="prod"

# 로그 함수
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

error_exit() {
    log_error "$1"
    exit 1
}

# 사용법 출력
usage() {
    cat <<EOF
사용법: $0 [옵션]

공공 프로젝트 WAR 빌드 스크립트

옵션:
  -s, --skip-tests    테스트 건너뛰기
  -n, --no-clean      clean 빌드 건너뛰기
  -p, --profile NAME  빌드 프로파일 (기본값: prod)
  -g, --gradle        Gradle 사용 (기본값: Maven)
  -h, --help          도움말 출력

예시:
  $0                              # 기본 빌드
  $0 -s                           # 테스트 건너뛰기
  $0 -p dev -s                    # 개발 프로파일, 테스트 건너뛰기
  $0 -g                           # Gradle로 빌드

EOF
    exit 0
}

# 명령행 인수 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -n|--no-clean)
            CLEAN_BUILD=false
            shift
            ;;
        -p|--profile)
            BUILD_PROFILE="$2"
            shift 2
            ;;
        -g|--gradle)
            BUILD_TOOL="gradle"
            shift
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
cat <<EOF

╔════════════════════════════════════════╗
║   공공 프로젝트 WAR 빌드 스크립트       ║
╚════════════════════════════════════════╝

빌드 도구:     $BUILD_TOOL
빌드 프로파일: $BUILD_PROFILE
Clean 빌드:    $CLEAN_BUILD
테스트:        $([ "$SKIP_TESTS" = true ] && echo "건너뛰기" || echo "실행")

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

# 시작 시간 기록
START_TIME=$(date +%s)

# 1. 환경 확인
log "=========================================="
log "1단계: 환경 확인"
log "=========================================="

# Node.js 확인
if ! command -v node &> /dev/null; then
    error_exit "Node.js가 설치되어 있지 않습니다."
fi
NODE_VERSION=$(node -v)
log "Node.js 버전: $NODE_VERSION"

# npm 확인
if ! command -v npm &> /dev/null; then
    error_exit "npm이 설치되어 있지 않습니다."
fi
NPM_VERSION=$(npm -v)
log "npm 버전: $NPM_VERSION"

# Java 확인
if ! command -v java &> /dev/null; then
    error_exit "Java가 설치되어 있지 않습니다."
fi
JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
log "Java 버전: $JAVA_VERSION"

# 빌드 도구 확인
if [ "$BUILD_TOOL" == "maven" ]; then
    if ! command -v mvn &> /dev/null; then
        error_exit "Maven이 설치되어 있지 않습니다."
    fi
    MVN_VERSION=$(mvn -v | head -n 1)
    log "Maven 버전: $MVN_VERSION"
elif [ "$BUILD_TOOL" == "gradle" ]; then
    if ! command -v gradle &> /dev/null && [ ! -f "$PROJECT_ROOT/gradlew" ]; then
        error_exit "Gradle이 설치되어 있지 않습니다."
    fi
    if [ -f "$PROJECT_ROOT/gradlew" ]; then
        GRADLE_CMD="./gradlew"
        log "Gradle Wrapper 사용"
    else
        GRADLE_CMD="gradle"
        GRADLE_VERSION=$(gradle -v | grep "Gradle" | head -n 1)
        log "Gradle 버전: $GRADLE_VERSION"
    fi
fi

# 디렉토리 확인
if [ ! -d "$FRONTEND_DIR" ]; then
    error_exit "프론트엔드 디렉토리를 찾을 수 없습니다: $FRONTEND_DIR"
fi

if [ ! -f "$FRONTEND_DIR/package.json" ]; then
    error_exit "package.json을 찾을 수 없습니다: $FRONTEND_DIR/package.json"
fi

log_success "환경 확인 완료"
echo ""

# 2. Nuxt 4 프론트엔드 빌드
log "=========================================="
log "2단계: Nuxt 4 프론트엔드 빌드"
log "=========================================="

cd "$FRONTEND_DIR" || error_exit "프론트엔드 디렉토리로 이동 실패"

# npm 의존성 설치
log "npm 패키지 설치 중..."
if [ -f "package-lock.json" ]; then
    npm ci || error_exit "npm ci 실패"
else
    npm install || error_exit "npm install 실패"
fi
log_success "npm 패키지 설치 완료"

# 환경 변수 설정
export NODE_ENV=production
log "환경 변수: NODE_ENV=$NODE_ENV"

# Nuxt 빌드
log "Nuxt 빌드 중... (시간이 소요될 수 있습니다)"
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

# 빌드 파일 통계
FILE_COUNT=$(find "$OUTPUT_DIR" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)
log "빌드 파일: $FILE_COUNT 개"
log "빌드 크기: $TOTAL_SIZE"
echo ""

# 3. 빌드 파일 복사
log "=========================================="
log "3단계: 빌드 파일 복사"
log "=========================================="

# static 디렉토리 생성
mkdir -p "$STATIC_DIR" || error_exit "static 디렉토리 생성 실패"

# 기존 파일 삭제
if [ "$(ls -A $STATIC_DIR 2>/dev/null)" ]; then
    log "기존 파일 삭제 중..."
    rm -rf "${STATIC_DIR:?}"/* || log_warning "기존 파일 삭제 실패"
fi

# 빌드 파일 복사
log "빌드 파일 복사 중..."
cp -r "$OUTPUT_DIR"/* "$STATIC_DIR/" || error_exit "파일 복사 실패"
log_success "빌드 파일 복사 완료"

# 복사된 파일 확인
COPIED_COUNT=$(find "$STATIC_DIR" -type f | wc -l)
COPIED_SIZE=$(du -sh "$STATIC_DIR" | cut -f1)
log "복사된 파일: $COPIED_COUNT 개"
log "복사된 크기: $COPIED_SIZE"
echo ""

# 4. Spring Boot WAR 패키징
log "=========================================="
log "4단계: Spring Boot WAR 패키징"
log "=========================================="

cd "$PROJECT_ROOT" || error_exit "프로젝트 루트로 이동 실패"

# 빌드 명령어 구성
if [ "$BUILD_TOOL" == "maven" ]; then
    MVN_ARGS=""
    [ "$CLEAN_BUILD" == true ] && MVN_ARGS="clean"
    MVN_ARGS="$MVN_ARGS package"
    [ "$SKIP_TESTS" == true ] && MVN_ARGS="$MVN_ARGS -DskipTests"
    [ -n "$BUILD_PROFILE" ] && MVN_ARGS="$MVN_ARGS -P$BUILD_PROFILE"

    log "Maven 빌드 실행: mvn $MVN_ARGS"
    mvn $MVN_ARGS || error_exit "Maven 빌드 실패"

    WAR_FILE=$(find "$PROJECT_ROOT/target" -name "*.war" | head -n 1)

elif [ "$BUILD_TOOL" == "gradle" ]; then
    GRADLE_ARGS=""
    [ "$CLEAN_BUILD" == true ] && GRADLE_ARGS="clean"
    GRADLE_ARGS="$GRADLE_ARGS build"
    [ "$SKIP_TESTS" == true ] && GRADLE_ARGS="$GRADLE_ARGS -x test"
    [ -n "$BUILD_PROFILE" ] && GRADLE_ARGS="$GRADLE_ARGS -P$BUILD_PROFILE"

    log "Gradle 빌드 실행: $GRADLE_CMD $GRADLE_ARGS"
    cd "$PROJECT_ROOT"
    $GRADLE_CMD $GRADLE_ARGS || error_exit "Gradle 빌드 실패"

    WAR_FILE=$(find "$PROJECT_ROOT/build/libs" -name "*.war" | head -n 1)
fi

log_success "Spring Boot WAR 패키징 완료"
echo ""

# 5. 빌드 결과 출력
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED / 60))
SECONDS=$((ELAPSED % 60))

cat <<EOF
╔════════════════════════════════════════╗
║           빌드 완료!                   ║
╚════════════════════════════════════════╝

EOF

if [ -n "$WAR_FILE" ] && [ -f "$WAR_FILE" ]; then
    WAR_SIZE=$(du -h "$WAR_FILE" | cut -f1)
    WAR_NAME=$(basename "$WAR_FILE")

    echo "📦 WAR 파일 정보"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  파일명: $WAR_NAME"
    echo "  경로:   $WAR_FILE"
    echo "  크기:   $WAR_SIZE"
    echo ""

    echo "🔍 WAR 파일 검증"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  jar -tf \"$WAR_FILE\" | grep static"
    echo ""

    echo "🚀 로컬 실행"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  java -jar \"$WAR_FILE\""
    echo "  java -jar -Dspring.profiles.active=prod \"$WAR_FILE\""
    echo ""

    echo "📤 배포 방법"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  JEUS:     ./scripts/deploy_to_jeus.sh"
    echo "  WebLogic: ./scripts/deploy_to_weblogic.sh"
    echo "  Tomcat:   cp \"$WAR_FILE\" \$CATALINA_HOME/webapps/"
    echo ""
else
    log_warning "WAR 파일을 찾을 수 없습니다."
fi

echo "⏱  빌드 시간: ${MINUTES}분 ${SECONDS}초"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
