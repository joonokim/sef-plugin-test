#!/bin/bash

################################################################################
# JEUS 자동 배포 스크립트
#
# 이 스크립트는 WAR 파일을 JEUS WAS에 자동으로 배포합니다.
#
# 사용법: ./deploy_to_jeus.sh [WAR파일경로]
#
# 환경 변수:
#   JEUS_HOME         - JEUS 설치 디렉토리
#   JEUS_ADMIN_USER   - JEUS 관리자 사용자명 (기본값: administrator)
#   JEUS_ADMIN_PASS   - JEUS 관리자 비밀번호
#   JEUS_SERVER       - 대상 서버 이름 (기본값: server1)
#   JEUS_DOMAIN       - 도메인 이름 (기본값: domain1)
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

# JEUS 설정
JEUS_HOME=${JEUS_HOME:-/path/to/jeus}
ADMIN_USER=${JEUS_ADMIN_USER:-administrator}
ADMIN_PASS=${JEUS_ADMIN_PASS}
SERVER_NAME=${JEUS_SERVER:-server1}
DOMAIN_NAME=${JEUS_DOMAIN:-domain1}

# 애플리케이션 설정
APP_NAME="public-project"
CONTEXT_PATH="/"

# WAR 파일 경로
if [ -n "$1" ]; then
    WAR_FILE="$1"
else
    # Maven 빌드 결과 찾기
    if [ -d "$PROJECT_ROOT/target" ]; then
        WAR_FILE=$(find "$PROJECT_ROOT/target" -name "*.war" | head -n 1)
    elif [ -d "$PROJECT_ROOT/build/libs" ]; then
        WAR_FILE=$(find "$PROJECT_ROOT/build/libs" -name "*.war" | head -n 1)
    fi
fi

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
사용법: $0 [WAR파일경로]

JEUS 자동 배포 스크립트

환경 변수:
  JEUS_HOME         JEUS 설치 디렉토리
  JEUS_ADMIN_USER   관리자 사용자명 (기본값: administrator)
  JEUS_ADMIN_PASS   관리자 비밀번호 (필수)
  JEUS_SERVER       대상 서버 (기본값: server1)
  JEUS_DOMAIN       도메인 이름 (기본값: domain1)

예시:
  export JEUS_HOME=/usr/local/jeus
  export JEUS_ADMIN_PASS=mypassword
  $0
  $0 target/myapp.war

EOF
    exit 0
}

# 도움말 옵션 처리
if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
    usage
fi

# 배너 출력
cat <<EOF

╔════════════════════════════════════════╗
║      JEUS 자동 배포 스크립트           ║
╚════════════════════════════════════════╝

EOF

# 1. 환경 확인
log "=========================================="
log "1단계: 환경 확인"
log "=========================================="

# JEUS_HOME 확인
if [ -z "$JEUS_HOME" ] || [ ! -d "$JEUS_HOME" ]; then
    error_exit "JEUS_HOME이 설정되지 않았거나 디렉토리를 찾을 수 없습니다: $JEUS_HOME"
fi
log "JEUS_HOME: $JEUS_HOME"

# jeusadmin 확인
if [ ! -f "$JEUS_HOME/bin/jeusadmin" ]; then
    error_exit "jeusadmin을 찾을 수 없습니다: $JEUS_HOME/bin/jeusadmin"
fi

# 관리자 비밀번호 확인
if [ -z "$ADMIN_PASS" ]; then
    error_exit "JEUS_ADMIN_PASS 환경 변수가 설정되지 않았습니다."
fi

# WAR 파일 확인
if [ -z "$WAR_FILE" ] || [ ! -f "$WAR_FILE" ]; then
    error_exit "WAR 파일을 찾을 수 없습니다: $WAR_FILE"
fi

WAR_ABS_PATH=$(cd "$(dirname "$WAR_FILE")" && pwd)/$(basename "$WAR_FILE")
WAR_SIZE=$(du -h "$WAR_ABS_PATH" | cut -f1)

log "WAR 파일: $WAR_ABS_PATH"
log "파일 크기: $WAR_SIZE"
log "애플리케이션: $APP_NAME"
log "서버: $SERVER_NAME"
log "도메인: $DOMAIN_NAME"
log "Context Path: $CONTEXT_PATH"

log_success "환경 확인 완료"
echo ""

# 2. JEUS 연결 테스트
log "=========================================="
log "2단계: JEUS 연결 테스트"
log "=========================================="

cat > /tmp/jeus_test.txt <<EOF
quit
EOF

log "JEUS 관리 서버 연결 테스트 중..."
if ! $JEUS_HOME/bin/jeusadmin -u $ADMIN_USER -p $ADMIN_PASS -f /tmp/jeus_test.txt &> /dev/null; then
    rm /tmp/jeus_test.txt
    error_exit "JEUS 관리 서버에 연결할 수 없습니다. 사용자명/비밀번호를 확인하세요."
fi

rm /tmp/jeus_test.txt
log_success "JEUS 연결 성공"
echo ""

# 3. 기존 애플리케이션 확인
log "=========================================="
log "3단계: 기존 애플리케이션 확인"
log "=========================================="

cat > /tmp/jeus_check_app.txt <<EOF
application-info -name $APP_NAME
quit
EOF

if $JEUS_HOME/bin/jeusadmin -u $ADMIN_USER -p $ADMIN_PASS -f /tmp/jeus_check_app.txt 2>&1 | grep -q "not found"; then
    log "기존 애플리케이션이 없습니다. 신규 배포를 진행합니다."
    DEPLOY_TYPE="new"
else
    log "기존 애플리케이션이 존재합니다. 재배포를 진행합니다."
    DEPLOY_TYPE="redeploy"
fi

rm /tmp/jeus_check_app.txt
echo ""

# 4. 배포 실행
log "=========================================="
log "4단계: 애플리케이션 배포"
log "=========================================="

# 배포 명령 생성
if [ "$DEPLOY_TYPE" == "new" ]; then
    # 신규 배포
    cat > /tmp/jeus_deploy.txt <<EOF
deploy -name $APP_NAME -path $WAR_ABS_PATH -contextpath $CONTEXT_PATH -server $SERVER_NAME
start-application -name $APP_NAME -server $SERVER_NAME
application-info -name $APP_NAME
quit
EOF
    log "신규 배포 시작..."
else
    # 재배포
    cat > /tmp/jeus_deploy.txt <<EOF
stop-application -name $APP_NAME -server $SERVER_NAME
redeploy -name $APP_NAME -path $WAR_ABS_PATH -server $SERVER_NAME
start-application -name $APP_NAME -server $SERVER_NAME
application-info -name $APP_NAME
quit
EOF
    log "재배포 시작..."
fi

# 배포 실행
START_TIME=$(date +%s)

if ! $JEUS_HOME/bin/jeusadmin -u $ADMIN_USER -p $ADMIN_PASS -f /tmp/jeus_deploy.txt; then
    rm /tmp/jeus_deploy.txt
    error_exit "배포에 실패했습니다."
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))

rm /tmp/jeus_deploy.txt

log_success "배포 완료 (소요 시간: ${ELAPSED}초)"
echo ""

# 5. 배포 검증
log "=========================================="
log "5단계: 배포 검증"
log "=========================================="

sleep 3  # 애플리케이션 시작 대기

# 애플리케이션 상태 확인
cat > /tmp/jeus_verify.txt <<EOF
application-info -name $APP_NAME
quit
EOF

log "애플리케이션 상태 확인 중..."
DEPLOY_OUTPUT=$($JEUS_HOME/bin/jeusadmin -u $ADMIN_USER -p $ADMIN_PASS -f /tmp/jeus_verify.txt 2>&1)

rm /tmp/jeus_verify.txt

if echo "$DEPLOY_OUTPUT" | grep -q "RUNNING"; then
    log_success "애플리케이션이 정상적으로 실행 중입니다."
elif echo "$DEPLOY_OUTPUT" | grep -q "DEPLOYED"; then
    log_warning "애플리케이션이 배포되었지만 시작되지 않았습니다."
else
    log_error "애플리케이션 상태를 확인할 수 없습니다."
fi

echo ""

# 6. 로그 확인 안내
log "=========================================="
log "6단계: 배포 완료"
log "=========================================="

cat <<EOF
╔════════════════════════════════════════╗
║         배포가 완료되었습니다!          ║
╚════════════════════════════════════════╝

📋 배포 정보
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  애플리케이션: $APP_NAME
  서버:         $SERVER_NAME
  도메인:       $DOMAIN_NAME
  Context Path: $CONTEXT_PATH

🔍 로그 확인
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  tail -f $JEUS_HOME/domains/$DOMAIN_NAME/servers/$SERVER_NAME/logs/JeusServer.log

🌐 접속 URL
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  http://localhost:8080$CONTEXT_PATH

📊 관리 콘솔
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  http://localhost:9736/webadmin

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF

exit 0
