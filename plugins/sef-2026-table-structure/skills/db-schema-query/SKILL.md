# DB Schema Query Skill

DB 스키마를 단계적으로 탐색하고 테이블 구조를 파악하는 스킬입니다.

## 사용 시점

다음 상황에서 이 스킬을 사용하세요:
- 사용자가 DB 스키마, 테이블, 컬럼 정보를 조회하려 할 때
- SQL 쿼리 작성 전 테이블 구조를 확인해야 할 때
- ERD 또는 데이터 모델을 파악해야 할 때
- 특정 테이블의 PK, FK, 인덱스 정보가 필요할 때

## 권장 호출 흐름

항상 아래 순서로 툴을 호출하세요. 단계를 건너뛰지 마세요.

### 1단계: 스키마 목록 조회

```
list_schemas()
```

응답 예시:
```json
{
  "ok": true,
  "database_type": "PostgreSQL",
  "schemas": ["public", "auth", "reporting"]
}
```

### 2단계: 테이블 목록 조회

```
list_tables(schema_name="public")
```

응답 예시:
```json
{
  "ok": true,
  "database_type": "PostgreSQL",
  "schema": "public",
  "tables": [
    {"table_name": "users", "table_type": "BASE TABLE"},
    {"table_name": "orders", "table_type": "BASE TABLE"}
  ]
}
```

### 3단계: 테이블 상세 조회

```
get_table_detail(schema_name="public", table_name="users")
```

응답 예시:
```json
{
  "ok": true,
  "database_type": "PostgreSQL",
  "schema": "public",
  "table": "users",
  "columns": [...],
  "primary_keys": ["id"],
  "foreign_keys": [...],
  "indexes": [...]
}
```

### 캐시 초기화 (DB 변경 후)

```
refresh_schema()
```

응답 예시:
```json
{
  "status": "ok",
  "message": "Cache cleared."
}
```

## MCP 리소스

| URI | 설명 |
|-----|------|
| `rules://db-schemas` | 현재 DB의 스키마 목록을 리소스로 제공 (`list_schemas`와 동일 결과) |

## 에러 처리

응답의 `ok` 필드가 `false`이면 오류입니다.

| code | 설명 | 조치 |
|------|------|------|
| `DB_TIMEOUT` | DB 연결/쿼리 타임아웃 (`retryable: true`) | 재시도 또는 `.env` 타임아웃 값 증가 |
| `MCP_TIMEOUT` | MCP 툴 실행 타임아웃 (`retryable: true`) | 재시도 또는 `MCP_TOOL_TIMEOUT_SEC` 증가 |
| `DB_ERROR` | 일반 DB 오류 | `details` 필드 확인 |
| `INVALID_INPUT` | 파라미터 오류 | 파라미터 확인 |
| `INVALID_CONFIG` | `.env` 필수 설정 누락 | `.env` 파일 확인 |
| `UNSUPPORTED_DB_TYPE` | 지원하지 않는 DB 타입 | `DB_TYPE` 값 확인 (postgresql/mysql/sqlite/oracle) |
| `MCP_ERROR` | MCP 툴 실행 중 예기치 않은 오류 | `details` 필드 확인 |

`retryable: true`인 오류는 자동으로 재시도됩니다.

## 설정 위치

`.env` 파일은 플러그인 루트(`sef-2026-table-structure/.env`)에 위치해야 합니다. 없으면 환경변수에서 읽습니다.
최초 실행 시 `.env`가 없으면 대화형 프롬프트로 설정값을 입력받습니다.

## 지원 DB 타입

- `postgresql` — PostgreSQL
- `mysql` — MySQL
- `sqlite` — SQLite (DB_PATH 필요)
- `oracle` — Oracle (SID 또는 서비스명)
