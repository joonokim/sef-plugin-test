# TypeScript 타입 정의 구조 (types/api/)

## 개요

타입은 `types/api/` 하위에 **도메인별 파일로 분리**하여 관리합니다.
모든 타입은 `types/api/index.ts`에서 통합 re-export하므로 단일 경로로 import 가능합니다.

## 파일 구조

```
types/
└── api/
    ├── common.ts          # 공통 타입 (PageRequest, PageResponse, ApiResponse 등)
    ├── auth.ts            # 인증 타입 (JwtRequest, JwtResponse, AuthInfo 등)
    ├── user.ts            # 사용자 관리 타입
    ├── board.ts           # 게시판 타입
    ├── menu.ts            # 메뉴 관리 타입
    ├── menu-role.ts       # 메뉴-역할 권한 타입
    ├── role.ts            # 역할 관리 타입
    ├── code.ts            # 코드 관리 타입
    ├── notice-popup.ts    # 공지 팝업 타입
    ├── login-history.ts   # 로그인 이력 타입
    ├── system-log.ts      # 시스템 로그 타입 (API 로그, 에러 로그)
    ├── user-statistics.ts # 회원 통계 타입
    ├── bbs-statistics.ts  # 게시판 통계 타입
    ├── visit-statistics.ts # 접속 통계 타입
    └── index.ts           # 전체 re-export
```

---

## 공통 타입 (common.ts)

```typescript
/**
 * API 공통 응답 래퍼
 * 백엔드 ApiResponse<T>와 1:1 대응
 */
export interface ApiResponse<T = void> {
  timestamp: string   // 응답 시간 (yyyy-MM-dd HH:mm:ss)
  code: string        // 응답 코드 (OK, CREATED, BAD_REQUEST 등)
  message: string     // 응답 메시지
  status: string      // HTTP 상태
  data?: T            // 응답 데이터 (성공 시에만)
}

/**
 * 페이지네이션 응답 (레퍼런스 프로젝트의 실제 구조)
 */
export interface PageResponse<T> {
  content: T[]            // 데이터 목록
  pagination: {
    page: number          // 현재 페이지 (0부터)
    size: number          // 페이지 크기
    totalElements: number // 전체 건수
    totalPages: number    // 전체 페이지 수
    first: boolean
    last: boolean
  }
}

/**
 * 검색 파라미터 공통
 */
export interface SearchParams {
  search?: string          // 검색어
  searchType?: SearchType  // 검색 타입
}

export type SearchType = 'all' | 'title' | 'content' | 'author' | 'titleContent'

/**
 * 정렬 파라미터
 */
export interface SortParams {
  sortField?: string
  sortDirection?: 'asc' | 'desc'
}

/**
 * 공통 엔티티 감사 필드 (Y/N 패턴)
 */
export interface Usable    { useYn: 'Y' | 'N' }
export interface Deletable { delYn: 'Y' | 'N' }
export interface Publishable { pblYn: 'Y' | 'N' }

/**
 * 등록/수정 정보 (공공 표준 필드명)
 */
export interface CreatedInfo {
  rgtrId?: string    // 등록자 ID
  rgtrNm?: string    // 등록자 이름
  regDt?: string     // 등록 일시 (ISO 8601)
}
export interface ModifiedInfo {
  mdfrId?: string    // 수정자 ID
  mdfrNm?: string    // 수정자 이름
  mdfcnDt?: string   // 수정 일시 (ISO 8601)
}

/**
 * 선택 옵션
 */
export interface SelectOption<T = string> {
  label: string
  value: T
}

/**
 * 상수
 */
export const DEFAULT_PAGE_SIZE = 10
export const USE_YN_OPTIONS = [
  { label: '사용', value: 'Y' },
  { label: '미사용', value: 'N' },
] as const
```

---

## 인증 타입 (auth.ts)

```typescript
/**
 * 로그인 요청
 */
export interface JwtRequest {
  userId: string    // 사용자 ID (이메일 형식)
  userPswd: string  // 비밀번호
}

/**
 * 인증 정보 (로그인 성공 후 반환)
 */
export interface AuthInfo {
  userId: string
  userName: string
  roleId: string
  userStatusCode: 'A' | 'I' | 'L'  // 활성/비활성/잠김
  canAccessAdmin: boolean
}

/**
 * JWT 응답
 */
export interface JwtResponse {
  authInfo: AuthInfo
  token: string           // Access Token
  refreshToken?: string   // Refresh Token (httpOnly 쿠키 전환 시 생략 가능)
}

export type LoginResponse = ApiResponse<JwtResponse>
```

---

## 게시판 타입 (board.ts)

```typescript
/**
 * 게시글 목록 아이템
 */
export interface BoardListItem {
  bbsId: number
  bbsSeq: number
  title: string
  category: BoardCategory
  rgtrNm: string
  regDt: string
  viewCnt: number
  fileCnt: number
}

/**
 * 게시글 상세
 */
export interface BoardDetail extends BoardListItem {
  content: string
  files: BoardFile[]
  prevBoard?: { bbsSeq: number; title: string }
  nextBoard?: { bbsSeq: number; title: string }
}

/**
 * 게시글 카테고리
 */
export type BoardCategory = 'notice' | 'general' | 'faq'

/**
 * 게시글 등록 요청
 */
export interface BoardRegisterRequest {
  bbsId: number
  title: string
  content: string
  category: BoardCategory
  pblYn: 'Y' | 'N'
  files?: File[]
}

/**
 * 게시글 수정 요청 (POST /{seq}/update)
 */
export interface BoardUpdateRequest {
  title: string
  content: string
  category: BoardCategory
  pblYn: 'Y' | 'N'
  deleteFileIds?: number[]
  files?: File[]
}

/**
 * 게시글 검색 파라미터
 */
export interface BoardSearchParams extends SearchParams {
  bbsId?: number
  category?: BoardCategory
  startDate?: string
  endDate?: string
  currentPage?: number
  pageSize?: number
}

export interface BoardFile {
  fileId: number
  originalName: string
  fileSize: number
  fileUrl: string
}
```

---

## 타입 Import 패턴

### 통합 index.ts를 통한 import (권장)

```typescript
// 모든 타입을 단일 경로에서 import
import type {
  ApiResponse,
  PageResponse,
  Board,
  BoardListItem,
  BoardRegisterRequest,
  AuthInfo,
  JwtRequest,
} from '@/types/api'
```

### 개별 파일에서 직접 import

```typescript
// 특정 도메인 타입만 필요한 경우
import type { Board, BoardSearchParams } from '@/types/api/board'
import type { AuthInfo } from '@/types/api/auth'
```

---

## 신규 도메인 타입 추가 방법

1. `types/api/` 하위에 새 파일 생성 (예: `terms.ts`)
2. 도메인 타입 정의
3. `types/api/index.ts`에 re-export 추가

```typescript
// types/api/terms.ts
export interface Terms {
  termsId: number
  title: string
  content: string
  version: string
  required: boolean
  useYn: 'Y' | 'N'
  regDt: string
}

export interface TermsAgreement {
  termsId: number
  agreedAt: string
}
```

```typescript
// types/api/index.ts 에 추가
export type { Terms, TermsAgreement } from './terms'
```

---

## 공공 표준 필드명 규칙

공공 프로젝트는 데이터베이스 컬럼명을 camelCase로 변환한 필드명을 사용합니다:

| 의미 | 필드명 | 타입 |
|------|--------|------|
| 등록자 ID | `rgtrId` | `string` |
| 등록자 이름 | `rgtrNm` | `string` |
| 등록 일시 | `regDt` | `string` |
| 수정자 ID | `mdfrId` | `string` |
| 수정자 이름 | `mdfrNm` | `string` |
| 수정 일시 | `mdfcnDt` | `string` |
| 사용 여부 | `useYn` | `'Y' \| 'N'` |
| 삭제 여부 | `delYn` | `'Y' \| 'N'` |
| 공개 여부 | `pblYn` | `'Y' \| 'N'` |
| 현재 페이지 | `currentPage` | `number` (1부터) |
| 페이지 크기 | `pageSize` | `number` |
| 전체 건수 | `totalCnt` | `number` |
| 결과 목록 | `resultList` | `T[]` |

> **주의**: 일부 API는 `totalCnt / currentPage / pageSize / resultList` 구조를 반환합니다.
> API 응답 구조를 확인 후 타입을 정의하세요.

## 참고 자료

- `api-client.md`: API composable 패턴
- `common-components.md`: DataTable에서 사용하는 타입 구조
