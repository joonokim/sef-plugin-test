# Assets 폴더

## 개요

프로젝트에서 공통으로 사용하는 템플릿, 설정 파일, 스크립트를 포함합니다.

## 디렉토리 구조

```
assets/
├── configs/              # 설정 파일 템플릿
│   ├── .editorconfig    # 에디터 설정
│   ├── .prettierrc      # Prettier 설정
│   ├── tsconfig.json    # TypeScript 설정
│   └── .env.example     # 환경 변수 템플릿
├── templates/           # 프로젝트 템플릿
│   └── docker/         # Docker 관련 템플릿
│       ├── Dockerfile.node
│       ├── Dockerfile.nuxt
│       └── docker-compose.yml
└── scripts/            # 유틸리티 스크립트
    └── setup-project.sh
```

## 사용 방법

### 1. 설정 파일 복사

```bash
# 프로젝트 루트에 설정 파일 복사
cp .claude/assets/configs/.editorconfig .
cp .claude/assets/configs/.prettierrc .
cp .claude/assets/configs/tsconfig.json .
cp .claude/assets/configs/.env.example .env
```

### 2. Docker 템플릿 사용

```bash
# Dockerfile 복사
cp .claude/assets/templates/docker/Dockerfile.nuxt ./Dockerfile

# docker-compose.yml 복사
cp .claude/assets/templates/docker/docker-compose.yml .
```

### 3. 스크립트 실행

```bash
# 프로젝트 초기 설정
chmod +x .claude/assets/scripts/setup-project.sh
./.claude/assets/scripts/setup-project.sh
```

## 파일 설명

### configs/

#### .editorconfig
- 팀 전체의 일관된 코딩 스타일 유지
- 들여쓰기, 줄바꿈, 문자 인코딩 등 설정

#### .prettierrc
- 코드 자동 포맷팅 설정
- JavaScript, TypeScript, JSON, Markdown 등 지원

#### tsconfig.json
- TypeScript 컴파일러 옵션
- 엄격한 타입 체킹 활성화
- 경로 별칭 (@/*, ~/*) 설정

#### .env.example
- 환경 변수 템플릿
- 데이터베이스, Redis, JWT, OAuth 등 설정 예시

### templates/docker/

#### Dockerfile.node
- 일반 Node.js 애플리케이션용 Dockerfile
- 멀티 스테이지 빌드
- 보안: non-root 사용자
- 헬스체크 포함

#### Dockerfile.nuxt
- Nuxt 4 애플리케이션 전용 Dockerfile
- SSR 최적화
- 경량화된 Alpine 이미지

#### docker-compose.yml
- 전체 스택 로컬 개발 환경
- Frontend + Backend + Database + Redis + Nginx
- 네트워크 및 볼륨 설정

### scripts/

#### setup-project.sh
- 프로젝트 초기 설정 자동화
- Node.js, pnpm 확인
- 의존성 설치
- .env 파일 생성
- Git 훅 설정

## 커스터마이징

각 템플릿은 프로젝트 요구사항에 맞게 수정하여 사용하세요.

### tsconfig.json 경로 별칭 수정

```json
{
  "compilerOptions": {
    "paths": {
      "@/*": ["./src/*"],
      "@components/*": ["./src/components/*"],
      "@utils/*": ["./src/utils/*"]
    }
  }
}
```

### .env 추가 변수

```bash
# Custom variables
MY_CUSTOM_VAR=value
FEATURE_FLAG_XXX=true
```

## 관련 문서

- `../reference/conventions/`: 코딩 컨벤션
- `../reference/architecture/`: 아키텍처 가이드
- `../skills/`: 프로젝트 유형별 스킬
