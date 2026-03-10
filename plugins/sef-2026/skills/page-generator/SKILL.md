---
name: page-generator
description: Nuxt 4 목록·상세·등록·수정 페이지 생성. 도메인명 입력 시 DataTable+SearchForm+PageHeader 조합 boilerplate 자동 생성. 관리자/일반 페이지 모두 지원. "목록 페이지 만들어줘", "CRUD 페이지 생성", "관리자 게시판 폼 페이지" 등 페이지 파일 생성이 필요할 때 사용.
---

# 페이지 생성기 (page-generator)

## 사전 조건

페이지 생성 전 해당 도메인의 `types/api/{domain}.ts`와 `composables/use{Domain}.ts`가 존재해야 합니다.
없으면 `sef-2026:module-generator`로 먼저 생성하세요.

## 치환 규칙

| 플레이스홀더 | 예시 (notice) | 설명 |
|------------|--------------|------|
| `{domain}` | `notice` | 소문자, kebab-case |
| `{DomainPascal}` | `Notice` | PascalCase |
| `{DomainLabel}` | `공지사항` | 한국어 표시명 |
| `{prefix}` | `admin` 또는 비워둠 | 경로 접두사 |

## 생성 파일

```
pages/{prefix}/{domain}/index.vue       # 목록 (패턴 A)
pages/{prefix}/{domain}/[id].vue        # 상세 (패턴 B)
pages/{prefix}/{domain}/create.vue      # 등록 (패턴 C)
pages/{prefix}/{domain}/[id]/edit.vue   # 수정 (패턴 C, isEdit=true)
```

## 패턴 선택 가이드

전체 Vue 코드 템플릿은 `references/page-templates.md` 참조.

| 패턴 | 파일 | 핵심 컴포넌트 |
|------|------|-------------|
| A: 목록 | `index.vue` | DataTable + SearchForm + 페이지네이션 |
| B: 상세 | `[id].vue` | Card + ConfirmDialog (삭제) |
| C: 폼 | `create.vue` / `[id]/edit.vue` | vee-validate + Zod (등록·수정 공용) |

## 관련 스킬

- `sef-2026:module-generator`: types + composable + store 먼저 생성
- `sef-2026:frontend`: 컴포넌트/composable 패턴 가이드
