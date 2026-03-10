---
name: module-generator
description: Nuxt 4 도메인 모듈 세트 생성. types/api/{domain}.ts + composables/use{Domain}.ts + stores/{domain}.ts 3종 파일 자동 생성. "모듈 만들어줘", "composable 생성해줘", "API 클라이언트 코드 만들어줘", 새 도메인 개발 시작 시 사용.
---

# 모듈 생성기 (module-generator)

## 생성 파일

```
types/api/{domain}.ts           # TypeScript 타입 정의
composables/use{Domain}.ts      # API 클라이언트 composable
stores/{domain}.ts              # Pinia 스토어 (전역 상태 필요 시만)
```

생성 후 `types/api/index.ts`에 re-export 추가:
```typescript
export * from './{domain}'
```

## 치환 규칙

| 플레이스홀더 | 예시 (notice) | 설명 |
|------------|--------------|------|
| `{domain}` | `notice` | 소문자, kebab-case |
| `{DomainPascal}` | `Notice` | PascalCase |
| `{DomainLabel}` | `공지사항` | 한국어 명칭 |

## URL 패턴

| 작업 | 일반 API | 관리자 API |
|------|---------|----------|
| 목록 | `GET /api/v1/{domain}s` | `GET /adm/v1/{domain}s` |
| 단건 | `GET /api/v1/{domain}s/{id}` | `GET /adm/v1/{domain}s/{id}` |
| 등록 | `POST /api/v1/{domain}s` | `POST /adm/v1/{domain}s` |
| 수정 | `POST /api/v1/{domain}s/{id}/update` | `POST /adm/v1/{domain}s/{id}/update` |
| 삭제 | `POST /api/v1/{domain}s/{id}/delete` | `POST /adm/v1/{domain}s/{id}/delete` |

> PUT/DELETE는 공공 네트워크 정책상 금지. 수정·삭제는 POST + `/update`, `/delete` 경로 사용.

## 코드 템플릿

`references/module-templates.md` 참조:
- **타입 정의**: 엔티티, SearchRequest, CreateRequest, UpdateRequest
- **Composable**: get목록, get단건, create, update, delete (관리자 API 변형 포함)
- **Store**: 목록 검색 조건 유지가 필요한 경우만 생성

## 관련 스킬

- `sef-2026:page-generator`: 생성된 모듈을 사용하는 페이지 scaffolding
- `sef-2026:frontend`: API 클라이언트 패턴 상세 가이드
