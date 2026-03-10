#!/bin/bash

# 프로젝트 초기 설정 스크립트

set -e

echo "🚀 프로젝트 초기 설정을 시작합니다..."

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 함수: 성공 메시지
success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# 함수: 경고 메시지
warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 함수: 에러 메시지
error() {
    echo -e "${RED}✗ $1${NC}"
}

# 1. Node.js 버전 확인
echo "📦 Node.js 버전 확인 중..."
if ! command -v node &> /dev/null; then
    error "Node.js가 설치되어 있지 않습니다."
    exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    error "Node.js 18 이상이 필요합니다. 현재 버전: $(node -v)"
    exit 1
fi
success "Node.js $(node -v) 확인 완료"

# 2. pnpm 설치 확인
echo "📦 pnpm 확인 중..."
if ! command -v pnpm &> /dev/null; then
    warning "pnpm이 설치되어 있지 않습니다. 설치를 진행합니다..."
    npm install -g pnpm
fi
success "pnpm $(pnpm -v) 확인 완료"

# 3. 의존성 설치
echo "📦 의존성 설치 중..."
pnpm install --frozen-lockfile
success "의존성 설치 완료"

# 4. .env 파일 생성
if [ ! -f .env ]; then
    echo "⚙️ .env 파일 생성 중..."
    cp .env.example .env
    success ".env 파일 생성 완료"
    warning ".env 파일을 수정하여 환경 변수를 설정하세요."
else
    success ".env 파일이 이미 존재합니다."
fi

# 5. Git 훅 설정 (Husky)
if [ -f "package.json" ] && grep -q "husky" "package.json"; then
    echo "🔧 Git 훅 설정 중..."
    pnpm prepare
    success "Git 훅 설정 완료"
fi

# 6. 데이터베이스 마이그레이션 (선택사항)
read -p "데이터베이스 마이그레이션을 실행하시겠습니까? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🗄️ 데이터베이스 마이그레이션 실행 중..."
    pnpm db:migrate || warning "마이그레이션 실패. 데이터베이스 설정을 확인하세요."
fi

# 7. 완료
echo ""
echo "✅ 프로젝트 설정이 완료되었습니다!"
echo ""
echo "다음 명령어로 개발 서버를 시작할 수 있습니다:"
echo "  ${GREEN}pnpm dev${NC}"
echo ""
echo "기타 유용한 명령어:"
echo "  ${GREEN}pnpm build${NC}       - 프로덕션 빌드"
echo "  ${GREEN}pnpm test${NC}        - 테스트 실행"
echo "  ${GREEN}pnpm lint${NC}        - 린트 검사"
echo "  ${GREEN}pnpm format${NC}      - 코드 포맷팅"
echo ""
