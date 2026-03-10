# Pull Request 워크플로우

## 개요

효과적인 코드 리뷰와 협업을 위한 Pull Request (PR) 가이드입니다.

## PR 생성 전 체크리스트

- [ ] 코드가 정상적으로 빌드되는가?
- [ ] 모든 테스트가 통과하는가?
- [ ] 린트 에러가 없는가?
- [ ] 코딩 컨벤션을 따르는가?
- [ ] 커밋 메시지가 규칙을 따르는가?
- [ ] 변경사항이 논리적 단위로 나뉘어 있는가?

## PR 생성 절차

### 1. 브랜치 생성

```bash
# main 브랜치에서 최신 코드 가져오기
git checkout main
git pull origin main

# 기능 브랜치 생성
git checkout -b feature/user-authentication

# 또는 버그 수정
git checkout -b fix/login-error
```

### 2. 작업 및 커밋

```bash
# 파일 수정 후 스테이징
git add src/auth/

# 커밋 (Conventional Commits 규칙 따르기)
git commit -m "feat(auth): implement JWT authentication"

# 추가 작업
git add tests/auth/
git commit -m "test(auth): add authentication tests"
```

### 3. 원격 브랜치에 푸시

```bash
# 처음 푸시 시
git push -u origin feature/user-authentication

# 이후 푸시
git push
```

### 4. PR 생성

GitHub/GitLab에서 PR 생성 후 다음 정보를 작성합니다.

## PR 템플릿

### 제목

간결하고 명확하게 작성 (50자 이내)

```
feat(auth): Add JWT authentication
fix(order): Resolve duplicate payment issue
refactor(api): Extract HTTP client layer
```

### 설명 (Description)

````markdown
## Summary
<!-- 변경 사항 요약 -->
- JWT 기반 인증 시스템 구현
- Access Token (15분) 및 Refresh Token (7일) 분리
- Redis를 사용한 Refresh Token 저장

## Changes
<!-- 주요 변경 파일 및 내용 -->
- `src/auth/jwt.service.ts`: JWT 생성 및 검증 로직
- `src/auth/auth.middleware.ts`: 인증 미들웨어
- `src/auth/auth.controller.ts`: 로그인/로그아웃 API

## Type of Change
<!-- 해당하는 항목에 [x] 표시 -->
- [x] New feature (non-breaking change)
- [ ] Bug fix (non-breaking change)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Refactoring
- [ ] Documentation update

## How to Test
<!-- 테스트 방법 -->
1. 서버 실행: `pnpm dev`
2. POST /api/auth/login 호출
   ```bash
   curl -X POST http://localhost:3000/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com","password":"password123"}'
   ```
3. 응답으로 받은 accessToken으로 보호된 엔드포인트 호출
   ```bash
   curl -X GET http://localhost:3000/api/users/me \
     -H "Authorization: Bearer {accessToken}"
   ```

## Screenshots (Optional)
<!-- UI 변경 시 스크린샷 첨부 -->

## Related Issues
<!-- 관련 이슈 -->
Closes #123
Ref #456

## Checklist
- [x] 코드가 빌드됨
- [x] 테스트 통과
- [x] 린트 에러 없음
- [x] 문서 업데이트 (필요 시)
- [x] Breaking Change 문서화 (해당 시)
````

## 코드 리뷰 가이드

### 리뷰어 (Reviewer)

#### 체크 포인트

**기능**
- [ ] 요구사항을 충족하는가?
- [ ] 엣지 케이스를 처리하는가?
- [ ] 에러 핸들링이 적절한가?

**코드 품질**
- [ ] 코드가 읽기 쉬운가?
- [ ] 중복 코드가 없는가?
- [ ] 네이밍이 명확한가?
- [ ] 복잡도가 적절한가?

**보안**
- [ ] SQL Injection 취약점이 없는가?
- [ ] XSS 취약점이 없는가?
- [ ] 인증/인가가 적절한가?
- [ ] 민감한 정보가 노출되지 않는가?

**성능**
- [ ] 불필요한 쿼리가 없는가?
- [ ] N+1 문제가 없는가?
- [ ] 메모리 누수 가능성이 없는가?

**테스트**
- [ ] 테스트 커버리지가 충분한가?
- [ ] 테스트가 의미 있는가?
- [ ] 엣지 케이스 테스트가 있는가?

#### 리뷰 코멘트 작성

**긍정적인 피드백**
```
✅ Good: 에러 핸들링이 잘 되어 있네요!
✅ Nice: 이 부분 리팩토링으로 코드가 훨씬 깔끔해졌습니다.
```

**개선 제안**
```
💡 Suggestion: 이 함수를 작은 단위로 나누면 테스트하기 더 쉬울 것 같습니다.
💡 Consider: Promise.all()을 사용하면 병렬 처리로 성능을 개선할 수 있습니다.
```

**필수 수정 사항**
```
🔴 Issue: SQL Injection 취약점이 있습니다. Prepared Statement를 사용해주세요.
🔴 Required: 이 부분은 try-catch로 에러 핸들링이 필요합니다.
```

**질문**
```
❓ Question: 이 로직이 필요한 이유를 설명해주실 수 있나요?
❓ Clarification: 이 변수명의 의미가 명확하지 않은데, 더 구체적으로 바꿀 수 있을까요?
```

### PR 작성자 (Author)

#### 리뷰 피드백 대응

**수정이 필요한 경우**
```bash
# 피드백에 따라 코드 수정
git add .
git commit -m "refactor(auth): extract token generation logic"
git push
```

**논의가 필요한 경우**
- 코멘트에 답글로 의견 제시
- 필요시 대안 제시
- 합의 도출 후 수정

**리뷰 승인 후**
- 모든 코멘트 확인
- 승인 받은 후 머지

## PR 머지 전략

### Squash and Merge (권장)

여러 커밋을 하나로 합쳐서 머지

```
feature/user-auth
  - feat(auth): add JWT service
  - feat(auth): add middleware
  - test(auth): add tests
  - fix(auth): fix token expiration

↓ Squash and Merge

main
  - feat(auth): implement JWT authentication (#123)
```

**장점**:
- 깔끔한 히스토리
- 의미 있는 단위로 커밋

**사용 시나리오**:
- 일반적인 기능 개발
- 작은 버그 수정

### Rebase and Merge

커밋을 재배치하여 선형 히스토리 유지

```bash
git checkout feature/user-auth
git rebase main
git push --force-with-lease
```

**장점**:
- 선형 히스토리
- 각 커밋이 의미 있을 때 유용

**사용 시나리오**:
- 커밋이 잘 정리되어 있을 때
- 히스토리가 중요한 경우

### Merge Commit

브랜치 머지 커밋 생성

```
main ─┬─────────┬─ merge commit
      │         │
      feature ──┘
```

**장점**:
- 브랜치 히스토리 보존
- 롤백이 쉬움

**사용 시나리오**:
- 릴리스 브랜치 머지
- 장기 실행 브랜치

## PR 크기 가이드

### 이상적인 PR 크기

- **라인 수**: 200-400 라인
- **파일 수**: 5-10 파일
- **리뷰 시간**: 15-30분

### 큰 PR을 나누는 방법

**나쁜 예**:
```
PR: Implement user management system (2000 lines)
  - User CRUD
  - Authentication
  - Authorization
  - Profile management
  - Email verification
```

**좋은 예**:
```
PR 1: Add user model and database schema (200 lines)
PR 2: Implement user CRUD operations (300 lines)
PR 3: Add JWT authentication (250 lines)
PR 4: Implement authorization middleware (150 lines)
PR 5: Add profile management (200 lines)
```

## Draft PR

작업 중인 PR을 Draft로 표시:

```
[WIP] feat(auth): Implement JWT authentication
```

또는 GitHub Draft PR 기능 사용

**사용 시나리오**:
- 초기 피드백이 필요할 때
- 큰 작업의 방향 확인
- 진행 상황 공유

## 자동화

### CI/CD 파이프라인

```yaml
# .github/workflows/pr-check.yml
name: PR Check

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '20'
      - run: pnpm install
      - run: pnpm lint
      - run: pnpm test
      - run: pnpm build
```

### PR 자동 레이블링

```yaml
# .github/labeler.yml
'type: feature':
  - 'src/**/*.ts'
  - 'src/**/*.tsx'

'type: fix':
  - 'fix/**/*'

'area: backend':
  - 'backend/**/*'

'area: frontend':
  - 'frontend/**/*'
```

## PR 체크리스트 (요약)

### 작성자
- [ ] 의미 있는 제목 작성
- [ ] 상세한 설명 작성
- [ ] 관련 이슈 연결
- [ ] 테스트 통과 확인
- [ ] 린트 에러 해결
- [ ] 스크린샷 첨부 (UI 변경 시)

### 리뷰어
- [ ] 코드 로직 검토
- [ ] 테스트 커버리지 확인
- [ ] 보안 취약점 확인
- [ ] 성능 이슈 확인
- [ ] 코딩 컨벤션 준수 확인

## 관련 문서

- `git-conventions.md`: Git 커밋 메시지 규칙
- `../conventions/typescript-style.md`: TypeScript 코딩 스타일
- `../security/`: 보안 가이드라인
