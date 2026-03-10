# Git 커밋 메시지 규칙

## 개요

일관된 Git 커밋 메시지 작성을 위한 Conventional Commits 기반 가이드입니다.

## 커밋 메시지 구조

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 기본 형식

```bash
feat(auth): JWT 토큰 기반 인증 구현

- JWT 토큰 생성 및 검증 로직 추가
- 로그인 API 엔드포인트 구현
- 인증 미들웨어 추가

Closes #123
```

## Type (필수)

### 주요 타입

| Type | 설명 | 예시 |
|------|------|------|
| `feat` | 새로운 기능 추가 | `feat(user): 사용자 프로필 페이지 추가` |
| `fix` | 버그 수정 | `fix(auth): 로그인 실패 시 에러 처리` |
| `docs` | 문서 수정 | `docs(readme): 설치 가이드 업데이트` |
| `style` | 코드 포맷팅, 세미콜론 누락 등 (동작 변경 없음) | `style: prettier 적용` |
| `refactor` | 코드 리팩토링 (기능 변경 없음) | `refactor(api): HTTP 클라이언트 모듈화` |
| `test` | 테스트 코드 추가/수정 | `test(user): 사용자 서비스 단위 테스트` |
| `chore` | 빌드, 설정 파일 수정 | `chore: webpack 설정 업데이트` |
| `perf` | 성능 개선 | `perf(db): 쿼리 인덱스 추가` |
| `ci` | CI/CD 설정 수정 | `ci: GitHub Actions 워크플로우 추가` |
| `build` | 빌드 시스템, 의존성 수정 | `build: lodash 버전 업그레이드` |
| `revert` | 커밋 되돌리기 | `revert: feat(auth): JWT 인증 기능 제거` |

## Scope (선택)

변경된 부분을 나타냅니다.

```bash
feat(auth): ...
fix(user): ...
refactor(api): ...
docs(readme): ...
```

**예시 scope**:
- `auth` - 인증/인가
- `user` - 사용자 관리
- `order` - 주문 관리
- `api` - API 레이어
- `db` - 데이터베이스
- `ui` - 사용자 인터페이스
- `config` - 설정

## Subject (필수)

### 규칙

1. **명령형 현재 시제 사용** (한글의 경우 명사형)
   - ✅ "add feature" / "기능 추가"
   - ❌ "added feature" / "기능을 추가함"

2. **첫 글자 소문자** (한글 제외)
   - ✅ `feat: add login page`
   - ❌ `feat: Add login page`

3. **마침표 사용 안 함**
   - ✅ `fix: resolve null pointer exception`
   - ❌ `fix: resolve null pointer exception.`

4. **50자 이내로 간결하게**
   - ✅ `feat(auth): implement JWT authentication`
   - ❌ `feat(auth): implement JWT based authentication with refresh token support and role-based access control`

### 좋은 Subject 예시

```bash
feat(user): 회원가입 API 구현
fix(order): 주문 취소 시 재고 복구 로직 수정
refactor(db): 데이터베이스 연결 풀 개선
docs(api): API 문서 업데이트
test(auth): 로그인 통합 테스트 추가
```

## Body (선택)

### 언제 작성하나요?

- 변경 이유 설명
- 변경 전후 비교
- 복잡한 로직 설명

### 규칙

1. Subject와 한 줄 띄우기
2. 무엇을, 왜 변경했는지 설명 (어떻게는 코드가 설명)
3. 72자마다 줄바꿈

### 예시

```bash
feat(auth): JWT 기반 인증 시스템 구현

기존 세션 기반 인증에서 JWT로 변경하여 서버 확장성 개선.
- Access Token (15분)과 Refresh Token (7일) 분리
- Redis를 사용한 Refresh Token 저장
- 토큰 갱신 엔드포인트 추가
```

## Footer (선택)

### Breaking Changes

호환성을 깨는 변경사항을 명시합니다.

```bash
feat(api)!: API 응답 형식 변경

BREAKING CHANGE: API 응답이 { data, error } 형식으로 변경됨
기존: { success: boolean, result: any }
변경: { data: any, error: string | null }
```

### 이슈 참조

```bash
Closes #123
Fixes #456
Resolves #789
Ref #321
```

### 여러 이슈

```bash
feat(board): 게시판 검색 기능 추가

Closes #123, #456
```

## 전체 예시

### 예시 1: 기능 추가

```bash
feat(auth): 소셜 로그인 기능 추가

Google, Naver, Kakao OAuth 로그인 지원
- Passport.js 전략 구현
- 소셜 계정 연동 테이블 추가
- 프론트엔드 로그인 버튼 UI 추가

Closes #245
```

### 예시 2: 버그 수정

```bash
fix(order): 결제 중복 처리 문제 해결

동시 요청 시 중복 결제되는 문제 수정
- Redis 분산 락 추가
- 결제 상태 검증 로직 강화

Fixes #789
```

### 예시 3: 리팩토링

```bash
refactor(api): HTTP 클라이언트 추상화

axios를 감싼 API 클라이언트 레이어 추가
- 공통 에러 핸들링
- 인터셉터를 통한 토큰 자동 갱신
- 타입 안전성 개선
```

### 예시 4: Breaking Change

```bash
feat(api)!: API 버전 2.0 출시

BREAKING CHANGE: 모든 엔드포인트가 /v2 접두사 필요
- /api/users → /v2/users
- 응답 형식 통일: { data, meta, error }
- 페이지네이션 형식 변경

Closes #1000
```

## 브랜치 네이밍

### 브랜치 유형

```bash
feature/기능명
fix/버그명
refactor/리팩토링명
release/버전
hotfix/긴급수정
```

### 예시

```bash
feature/user-authentication
fix/payment-duplicate-issue
refactor/api-client-abstraction
release/v2.0.0
hotfix/security-vulnerability
```

## Git 워크플로우

### Feature Branch Workflow

```bash
# 1. 메인 브랜치에서 기능 브랜치 생성
git checkout -b feature/user-profile

# 2. 작업 및 커밋
git add .
git commit -m "feat(user): 프로필 페이지 추가"

# 3. 원격 저장소에 푸시
git push origin feature/user-profile

# 4. Pull Request 생성
# GitHub/GitLab에서 PR 생성

# 5. 코드 리뷰 및 머지
# PR 승인 후 메인 브랜치에 머지
```

### Gitflow

```
main (프로덕션)
  └─ develop (개발)
       ├─ feature/xxx (기능)
       ├─ feature/yyy
       └─ release/v1.0 (릴리스)
            └─ hotfix/zzz (긴급 수정)
```

## 커밋 가이드라인

### 작은 단위로 커밋

```bash
# ✅ Good - 논리적 단위로 커밋
git commit -m "feat(auth): JWT 토큰 생성 로직 추가"
git commit -m "feat(auth): JWT 토큰 검증 미들웨어 추가"
git commit -m "test(auth): JWT 인증 테스트 추가"

# ❌ Bad - 여러 작업을 하나의 커밋으로
git commit -m "feat(auth): JWT 인증 기능 추가, 테스트 추가, 문서 작성"
```

### 의미 있는 커밋

```bash
# ✅ Good
git commit -m "fix(user): 이메일 중복 검증 로직 수정"

# ❌ Bad
git commit -m "fix: 버그 수정"
git commit -m "update"
git commit -m "WIP"
```

### Atomic Commit

하나의 커밋은 하나의 목적만 가져야 합니다.

```bash
# ✅ Good
feat(user): 사용자 등록 API 추가
test(user): 사용자 등록 테스트 추가

# ❌ Bad
feat(user): 사용자 등록 API 추가 및 주문 조회 버그 수정
```

## 커밋 메시지 템플릿

### .gitmessage 설정

```bash
# .gitmessage
# <type>(<scope>): <subject>

# <body>

# <footer>

# Type: feat, fix, docs, style, refactor, test, chore, perf, ci, build, revert
# Scope: auth, user, order, api, db, ui, config 등
# Subject: 50자 이내, 명령형, 소문자 시작, 마침표 없음
# Body: 무엇을, 왜 변경했는지 (72자마다 줄바꿈)
# Footer: Closes #123, BREAKING CHANGE 등
```

### 템플릿 적용

```bash
git config --global commit.template ~/.gitmessage
```

## 잘못된 커밋 수정

### 마지막 커밋 수정

```bash
# 커밋 메시지만 수정
git commit --amend -m "새로운 커밋 메시지"

# 파일 추가 후 커밋 수정
git add forgotten-file.ts
git commit --amend --no-edit
```

### 커밋 되돌리기

```bash
# 커밋 취소 (변경사항 유지)
git reset HEAD~1

# 커밋 및 변경사항 모두 취소
git reset --hard HEAD~1

# 커밋을 되돌리는 새 커밋 생성 (안전)
git revert <commit-hash>
```

### Rebase로 커밋 정리

```bash
# 최근 3개 커밋 수정
git rebase -i HEAD~3

# pick → squash (커밋 합치기)
# pick → reword (메시지 수정)
# pick → edit (커밋 수정)
```

## Conventional Commits 도구

### Commitizen

```bash
npm install -g commitizen cz-conventional-changelog

# 사용
git cz
```

### Husky + Commitlint

```bash
npm install --save-dev @commitlint/cli @commitlint/config-conventional husky

# commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
};

# .husky/commit-msg
npx --no -- commitlint --edit $1
```

## 관련 문서

- `typescript-style.md`: TypeScript 코딩 스타일
- `java-style.md`: Java 코딩 스타일
- `../workflows/pull-request.md`: PR 가이드
