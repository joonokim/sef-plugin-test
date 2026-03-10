import subprocess
import sys


def _pip_install(*packages: str) -> None:
    """패키지를 pip으로 자동 설치합니다."""
    print(f"[AUTO-INSTALL] 설치 중: {' '.join(packages)}", file=sys.stderr)
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "--quiet", *packages],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"[AUTO-INSTALL] 설치 실패:\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    print(f"[AUTO-INSTALL] 설치 완료: {' '.join(packages)}", file=sys.stderr)


try:
    from mcp.server.fastmcp import FastMCP
except ModuleNotFoundError:
    _pip_install("mcp[cli]", "fastmcp")
    from mcp.server.fastmcp import FastMCP

from pathlib import Path
from functools import wraps
from datetime import datetime
from typing import Any, Dict
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FutureTimeoutError
import io
import logging
import os
import re
import socket
import time


if sys.stdout.encoding != "utf-8":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
if sys.stderr.encoding != "utf-8":
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")


PLUGIN_ROOT = Path(__file__).resolve().parent.parent.parent.parent

log_dir = PLUGIN_ROOT / "logs"
log_dir.mkdir(exist_ok=True)

logger = logging.getLogger("mcp_server")
logger.setLevel(logging.INFO)
if not logger.handlers:
    fh = logging.FileHandler(
        log_dir / f"mcp_server_{datetime.now().strftime('%Y%m%d')}.log",
        encoding="utf-8",
    )
    fh.setFormatter(logging.Formatter("%(asctime)s | %(levelname)s | %(message)s"))
    logger.addHandler(fh)


def log_access(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        logger.info("request: %s", func.__name__)
        return func(*args, **kwargs)

    return wrapper


mcp = FastMCP("DB-Schema-Inspector")
_cache: Dict[str, Any] = {}

DB_CONNECT_TIMEOUT_SEC = int(os.environ.get("DB_CONNECT_TIMEOUT_SEC", "5"))
DB_QUERY_TIMEOUT_MS = int(os.environ.get("DB_QUERY_TIMEOUT_MS", "10000"))
MCP_TOOL_TIMEOUT_SEC = int(os.environ.get("MCP_TOOL_TIMEOUT_SEC", "15"))
DB_RETRY_COUNT = int(os.environ.get("DB_RETRY_COUNT", "1"))
DB_RETRY_BACKOFF_SEC = float(os.environ.get("DB_RETRY_BACKOFF_SEC", "0.3"))


def _ok(payload: Dict[str, Any]) -> Dict[str, Any]:
    payload["ok"] = True
    return payload


def _error(code: str, message: str, retryable: bool = False, details: str = "") -> Dict[str, Any]:
    out: Dict[str, Any] = {
        "ok": False,
        "code": code,
        "message": message,
        "retryable": retryable,
    }
    if details:
        out["details"] = details
    return out


def _is_timeout_error(exc: Exception) -> bool:
    if isinstance(exc, (TimeoutError, socket.timeout, FutureTimeoutError)):
        return True
    text = str(exc).lower()
    keywords = [
        "timeout",
        "timed out",
        "statement timeout",
        "lock wait timeout",
        "canceling statement due to statement timeout",
        "dpi-1067",
        "dpi-1080",
    ]
    return any(k in text for k in keywords)


_DRIVER_PACKAGES: Dict[str, str] = {
    "psycopg2": "psycopg2-binary",
    "pymysql": "pymysql",
    "oracledb": "oracledb",
}


def _ensure_driver(module_name: str) -> None:
    """DB 드라이버 패키지가 없으면 자동 설치합니다."""
    try:
        __import__(module_name)
    except ModuleNotFoundError:
        package = _DRIVER_PACKAGES.get(module_name, module_name)
        _pip_install(package)


def _db_error(context: str, exc: Exception) -> Dict[str, Any]:
    if _is_timeout_error(exc):
        return _error("DB_TIMEOUT", f"{context} timed out.", retryable=True, details=str(exc))
    return _error("DB_ERROR", f"{context} failed.", details=str(exc))


def _run_with_mcp_timeout(fn, timeout_sec: int = MCP_TOOL_TIMEOUT_SEC) -> Dict[str, Any]:
    for attempt in range(DB_RETRY_COUNT + 1):
        with ThreadPoolExecutor(max_workers=1) as ex:
            future = ex.submit(fn)
            try:
                result = future.result(timeout=timeout_sec)
            except FutureTimeoutError:
                result = _error(
                    "MCP_TIMEOUT",
                    f"Tool execution exceeded {timeout_sec}s timeout.",
                    retryable=True,
                )
            except Exception as e:
                result = _error("MCP_ERROR", "Tool execution failed.", details=str(e))

        if (
            isinstance(result, dict)
            and result.get("retryable")
            and attempt < DB_RETRY_COUNT
        ):
            time.sleep(DB_RETRY_BACKOFF_SEC * (attempt + 1))
            continue
        return result


def _execute_tool(fn) -> Dict[str, Any]:
    try:
        return _run_with_mcp_timeout(fn)
    except ValueError as e:
        return _error("INVALID_CONFIG", str(e))
    except Exception as e:
        return _error("MCP_ERROR", "Unhandled tool error.", details=str(e))


def load_env() -> Dict[str, str]:
    env_path = PLUGIN_ROOT / ".env"
    config: Dict[str, str] = {}

    if env_path.exists():
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    value = value.strip()
                    if (value.startswith('"') and value.endswith('"')) or \
                       (value.startswith("'") and value.endswith("'")):
                        value = value[1:-1]
                    config[key.strip()] = value

    for key in [
        "DB_TYPE",
        "DB_HOST",
        "DB_PORT",
        "DB_NAME",
        "DB_USER",
        "DB_PASSWORD",
        "DB_PATH",
        "DB_SID",
    ]:
        if key not in config and os.environ.get(key):
            config[key] = os.environ[key]

    return config


def _safe_ident(name: str) -> str:
    if not re.match(r"^[A-Za-z0-9_.$]+$", name or ""):
        raise ValueError(f"Invalid identifier: {name}")
    return name


def _db_type(config: Dict[str, str]) -> str:
    db_type = (config.get("DB_TYPE") or "").strip().lower()
    if not db_type:
        raise ValueError("DB_TYPE is not configured.")
    return db_type


def _list_schemas(config: Dict[str, str]) -> Dict[str, Any]:
    db_type = _db_type(config)
    cache_key = f"schemas:{db_type}:{config.get('DB_NAME', '')}:{config.get('DB_USER', '')}"
    if cache_key in _cache:
        return _cache[cache_key]

    if db_type == "postgresql":
        _ensure_driver("psycopg2")
        try:
            import psycopg2
            from psycopg2.extras import RealDictCursor

            conn = psycopg2.connect(
                host=config.get("DB_HOST", "localhost"),
                port=config.get("DB_PORT") or "5432",
                database=config.get("DB_NAME", ""),
                user=config.get("DB_USER", ""),
                password=config.get("DB_PASSWORD", ""),
                connect_timeout=DB_CONNECT_TIMEOUT_SEC,
            )
            cur = conn.cursor(cursor_factory=RealDictCursor)
            cur.execute("SET statement_timeout = %s", (DB_QUERY_TIMEOUT_MS,))
            cur.execute(
                """
                SELECT schema_name
                FROM information_schema.schemata
                WHERE schema_name NOT IN ('pg_catalog', 'information_schema')
                ORDER BY schema_name
                """
            )
            schemas = [row["schema_name"] for row in cur.fetchall()]
            cur.close()
            conn.close()
            result = _ok({"database_type": "PostgreSQL", "schemas": schemas})
        except Exception as e:
            result = _db_error("PostgreSQL schema load", e)
    elif db_type == "mysql":
        _ensure_driver("pymysql")
        db_name = config.get("DB_NAME", "")
        result = _ok({"database_type": "MySQL", "schemas": [db_name] if db_name else []})
    elif db_type == "sqlite":
        result = _ok({"database_type": "SQLite", "schemas": ["main"]})
    elif db_type == "oracle":
        _ensure_driver("oracledb")
        owner = (config.get("DB_USER", "") or "").upper()
        result = _ok({"database_type": "Oracle", "schemas": [owner] if owner else []})
    else:
        result = _error("UNSUPPORTED_DB_TYPE", f"Unsupported DB_TYPE: {db_type}")

    if result.get("ok"):
        _cache[cache_key] = result
    return result


def _list_tables(config: Dict[str, str], schema_name: str) -> Dict[str, Any]:
    db_type = _db_type(config)
    schema_name = (schema_name or "").strip()
    if not schema_name:
        return _error("INVALID_INPUT", "schema_name is required.")

    cache_key = f"tables:{db_type}:{schema_name.lower()}"
    if cache_key in _cache:
        return _cache[cache_key]

    if db_type == "postgresql":
        _ensure_driver("psycopg2")
        try:
            import psycopg2
            from psycopg2.extras import RealDictCursor

            conn = psycopg2.connect(
                host=config.get("DB_HOST", "localhost"),
                port=config.get("DB_PORT") or "5432",
                database=config.get("DB_NAME", ""),
                user=config.get("DB_USER", ""),
                password=config.get("DB_PASSWORD", ""),
                connect_timeout=DB_CONNECT_TIMEOUT_SEC,
            )
            cur = conn.cursor(cursor_factory=RealDictCursor)
            cur.execute("SET statement_timeout = %s", (DB_QUERY_TIMEOUT_MS,))
            cur.execute(
                """
                SELECT table_name, table_type
                FROM information_schema.tables
                WHERE table_schema = %s
                ORDER BY table_name
                """,
                (schema_name,),
            )
            tables = [dict(row) for row in cur.fetchall()]
            cur.close()
            conn.close()
            result = _ok({"database_type": "PostgreSQL", "schema": schema_name, "tables": tables})
        except Exception as e:
            result = _db_error("PostgreSQL table list", e)
    elif db_type == "mysql":
        _ensure_driver("pymysql")
        try:
            import pymysql

            conn = pymysql.connect(
                host=config.get("DB_HOST", "localhost"),
                port=int(config.get("DB_PORT") or "3306"),
                database=config.get("DB_NAME", ""),
                user=config.get("DB_USER", ""),
                password=config.get("DB_PASSWORD", ""),
                connect_timeout=DB_CONNECT_TIMEOUT_SEC,
                read_timeout=DB_CONNECT_TIMEOUT_SEC,
                write_timeout=DB_CONNECT_TIMEOUT_SEC,
            )
            cur = conn.cursor(pymysql.cursors.DictCursor)
            cur.execute(
                """
                SELECT table_name, table_type
                FROM information_schema.tables
                WHERE table_schema = %s
                ORDER BY table_name
                """,
                (schema_name,),
            )
            tables = [dict(row) for row in cur.fetchall()]
            cur.close()
            conn.close()
            result = _ok({"database_type": "MySQL", "schema": schema_name, "tables": tables})
        except Exception as e:
            result = _db_error("MySQL table list", e)
    elif db_type == "sqlite":
        try:
            import sqlite3

            db_path = config.get("DB_PATH", "")
            if not db_path:
                return _error("INVALID_INPUT", "DB_PATH is required for sqlite.")

            conn = sqlite3.connect(db_path, timeout=DB_CONNECT_TIMEOUT_SEC)
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            cur.execute(f"PRAGMA busy_timeout = {DB_QUERY_TIMEOUT_MS}")
            cur.execute(
                """
                SELECT name
                FROM sqlite_master
                WHERE type='table' AND name NOT LIKE 'sqlite_%'
                ORDER BY name
                """
            )
            tables = [{"table_name": row["name"], "table_type": "BASE TABLE"} for row in cur.fetchall()]
            cur.close()
            conn.close()
            result = _ok({"database_type": "SQLite", "schema": "main", "tables": tables})
        except Exception as e:
            result = _db_error("SQLite table list", e)
    elif db_type == "oracle":
        _ensure_driver("oracledb")
        try:
            import oracledb

            dsn = (
                oracledb.makedsn(
                    config.get("DB_HOST", "localhost"),
                    config.get("DB_PORT") or "1521",
                    sid=config.get("DB_SID", ""),
                )
                if config.get("DB_SID")
                else oracledb.makedsn(
                    config.get("DB_HOST", "localhost"),
                    config.get("DB_PORT") or "1521",
                    service_name=config.get("DB_NAME", ""),
                )
            )
            conn = oracledb.connect(
                user=config.get("DB_USER", ""),
                password=config.get("DB_PASSWORD", ""),
                dsn=dsn,
            )
            try:
                conn.call_timeout = DB_QUERY_TIMEOUT_MS
            except Exception:
                pass
            cur = conn.cursor()
            cur.execute("SELECT table_name FROM user_tables ORDER BY table_name")
            tables = [{"table_name": row[0], "table_type": "BASE TABLE"} for row in cur.fetchall()]
            cur.close()
            conn.close()
            result = _ok({"database_type": "Oracle", "schema": schema_name, "tables": tables})
        except Exception as e:
            result = _db_error("Oracle table list", e)
    else:
        result = _error("UNSUPPORTED_DB_TYPE", f"Unsupported DB_TYPE: {db_type}")

    if result.get("ok"):
        _cache[cache_key] = result
    return result


def _table_detail(config: Dict[str, str], schema_name: str, table_name: str) -> Dict[str, Any]:
    db_type = _db_type(config)
    schema_name = (schema_name or "").strip()
    table_name = (table_name or "").strip()
    if not schema_name:
        return _error("INVALID_INPUT", "schema_name is required.")
    if not table_name:
        return _error("INVALID_INPUT", "table_name is required.")

    cache_key = f"detail:{db_type}:{schema_name.lower()}:{table_name.lower()}"
    if cache_key in _cache:
        return _cache[cache_key]

    if db_type == "postgresql":
        _ensure_driver("psycopg2")
        try:
            import psycopg2
            from psycopg2.extras import RealDictCursor

            conn = psycopg2.connect(
                host=config.get("DB_HOST", "localhost"),
                port=config.get("DB_PORT") or "5432",
                database=config.get("DB_NAME", ""),
                user=config.get("DB_USER", ""),
                password=config.get("DB_PASSWORD", ""),
                connect_timeout=DB_CONNECT_TIMEOUT_SEC,
            )
            cur = conn.cursor(cursor_factory=RealDictCursor)
            cur.execute("SET statement_timeout = %s", (DB_QUERY_TIMEOUT_MS,))

            cur.execute(
                """
                SELECT column_name, data_type, character_maximum_length, is_nullable, column_default
                FROM information_schema.columns
                WHERE table_schema = %s AND table_name = %s
                ORDER BY ordinal_position
                """,
                (schema_name, table_name),
            )
            columns = [dict(row) for row in cur.fetchall()]

            cur.execute(
                """
                SELECT a.attname AS column_name
                FROM pg_index i
                JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
                WHERE i.indrelid = %s::regclass AND i.indisprimary
                """,
                (f"{schema_name}.{table_name}",),
            )
            primary_keys = [row["column_name"] for row in cur.fetchall()]

            cur.execute(
                """
                SELECT kcu.column_name,
                       ccu.table_name AS foreign_table_name,
                       ccu.column_name AS foreign_column_name
                FROM information_schema.table_constraints AS tc
                JOIN information_schema.key_column_usage AS kcu
                  ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
                JOIN information_schema.constraint_column_usage AS ccu
                  ON ccu.constraint_name = tc.constraint_name AND ccu.table_schema = tc.table_schema
                WHERE tc.constraint_type = 'FOREIGN KEY'
                  AND tc.table_schema = %s
                  AND tc.table_name = %s
                """,
                (schema_name, table_name),
            )
            foreign_keys = [dict(row) for row in cur.fetchall()]

            cur.execute(
                """
                SELECT indexname, indexdef
                FROM pg_indexes
                WHERE schemaname = %s AND tablename = %s
                ORDER BY indexname
                """,
                (schema_name, table_name),
            )
            indexes = [dict(row) for row in cur.fetchall()]

            cur.close()
            conn.close()
            result = _ok(
                {
                    "database_type": "PostgreSQL",
                    "schema": schema_name,
                    "table": table_name,
                    "columns": columns,
                    "primary_keys": primary_keys,
                    "foreign_keys": foreign_keys,
                    "indexes": indexes,
                }
            )
        except Exception as e:
            result = _db_error("PostgreSQL table detail", e)
    elif db_type == "mysql":
        _ensure_driver("pymysql")
        try:
            import pymysql

            conn = pymysql.connect(
                host=config.get("DB_HOST", "localhost"),
                port=int(config.get("DB_PORT") or "3306"),
                database=config.get("DB_NAME", ""),
                user=config.get("DB_USER", ""),
                password=config.get("DB_PASSWORD", ""),
                connect_timeout=DB_CONNECT_TIMEOUT_SEC,
                read_timeout=DB_CONNECT_TIMEOUT_SEC,
                write_timeout=DB_CONNECT_TIMEOUT_SEC,
            )
            cur = conn.cursor(pymysql.cursors.DictCursor)

            safe_table = _safe_ident(table_name)
            cur.execute(f"DESCRIBE `{safe_table}`")
            columns = [dict(row) for row in cur.fetchall()]

            cur.execute(f"SHOW INDEX FROM `{safe_table}`")
            indexes = [dict(row) for row in cur.fetchall()]

            cur.execute(
                """
                SELECT COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
                FROM INFORMATION_SCHEMA.KEY_COLUMN_USAGE
                WHERE TABLE_SCHEMA = %s
                  AND TABLE_NAME = %s
                  AND REFERENCED_TABLE_NAME IS NOT NULL
                """,
                (schema_name, table_name),
            )
            foreign_keys = [dict(row) for row in cur.fetchall()]
            primary_keys = [col["Field"] for col in columns if col.get("Key") == "PRI"]

            cur.close()
            conn.close()
            result = _ok(
                {
                    "database_type": "MySQL",
                    "schema": schema_name,
                    "table": table_name,
                    "columns": columns,
                    "primary_keys": primary_keys,
                    "foreign_keys": foreign_keys,
                    "indexes": indexes,
                }
            )
        except Exception as e:
            result = _db_error("MySQL table detail", e)
    elif db_type == "sqlite":
        try:
            import sqlite3

            db_path = config.get("DB_PATH", "")
            if not db_path:
                return _error("INVALID_INPUT", "DB_PATH is required for sqlite.")

            conn = sqlite3.connect(db_path, timeout=DB_CONNECT_TIMEOUT_SEC)
            conn.row_factory = sqlite3.Row
            cur = conn.cursor()
            cur.execute(f"PRAGMA busy_timeout = {DB_QUERY_TIMEOUT_MS}")

            safe_table = _safe_ident(table_name)
            cur.execute(f"PRAGMA table_info({safe_table})")
            columns = [dict(row) for row in cur.fetchall()]

            cur.execute(f"PRAGMA foreign_key_list({safe_table})")
            foreign_keys = [dict(row) for row in cur.fetchall()]

            cur.execute(f"PRAGMA index_list({safe_table})")
            indexes = [dict(row) for row in cur.fetchall()]

            primary_keys = [col["name"] for col in columns if col.get("pk", 0) > 0]

            cur.close()
            conn.close()
            result = _ok(
                {
                    "database_type": "SQLite",
                    "schema": "main",
                    "table": table_name,
                    "columns": columns,
                    "primary_keys": primary_keys,
                    "foreign_keys": foreign_keys,
                    "indexes": indexes,
                }
            )
        except Exception as e:
            result = _db_error("SQLite table detail", e)
    elif db_type == "oracle":
        _ensure_driver("oracledb")
        try:
            import oracledb

            dsn = (
                oracledb.makedsn(
                    config.get("DB_HOST", "localhost"),
                    config.get("DB_PORT") or "1521",
                    sid=config.get("DB_SID", ""),
                )
                if config.get("DB_SID")
                else oracledb.makedsn(
                    config.get("DB_HOST", "localhost"),
                    config.get("DB_PORT") or "1521",
                    service_name=config.get("DB_NAME", ""),
                )
            )
            conn = oracledb.connect(
                user=config.get("DB_USER", ""),
                password=config.get("DB_PASSWORD", ""),
                dsn=dsn,
            )
            try:
                conn.call_timeout = DB_QUERY_TIMEOUT_MS
            except Exception:
                pass

            cur = conn.cursor()
            table_upper = table_name.upper()

            cur.execute(
                """
                SELECT column_name, data_type, data_length, data_precision, data_scale, nullable, data_default
                FROM user_tab_columns
                WHERE table_name = :table_name
                ORDER BY column_id
                """,
                {"table_name": table_upper},
            )
            columns = []
            for row in cur.fetchall():
                columns.append(
                    {
                        "column_name": row[0],
                        "data_type": row[1],
                        "data_length": row[2],
                        "data_precision": row[3],
                        "data_scale": row[4],
                        "nullable": row[5],
                        "data_default": row[6].read() if row[6] else None,
                    }
                )

            cur.execute(
                """
                SELECT cols.column_name
                FROM user_constraints cons
                JOIN user_cons_columns cols ON cons.constraint_name = cols.constraint_name
                WHERE cons.constraint_type = 'P' AND cons.table_name = :table_name
                ORDER BY cols.position
                """,
                {"table_name": table_upper},
            )
            primary_keys = [row[0] for row in cur.fetchall()]

            cur.execute(
                """
                SELECT cols.column_name, ref_cons.table_name, ref_cols.column_name, cons.constraint_name
                FROM user_constraints cons
                JOIN user_cons_columns cols ON cons.constraint_name = cols.constraint_name
                JOIN user_constraints ref_cons ON cons.r_constraint_name = ref_cons.constraint_name
                JOIN user_cons_columns ref_cols ON ref_cons.constraint_name = ref_cols.constraint_name
                WHERE cons.constraint_type = 'R' AND cons.table_name = :table_name
                ORDER BY cols.position
                """,
                {"table_name": table_upper},
            )
            foreign_keys = [
                {
                    "column_name": row[0],
                    "foreign_table_name": row[1],
                    "foreign_column_name": row[2],
                    "constraint_name": row[3],
                }
                for row in cur.fetchall()
            ]

            cur.execute(
                """
                SELECT index_name, index_type, uniqueness
                FROM user_indexes
                WHERE table_name = :table_name
                ORDER BY index_name
                """,
                {"table_name": table_upper},
            )
            indexes = [
                {"index_name": row[0], "index_type": row[1], "uniqueness": row[2]}
                for row in cur.fetchall()
            ]

            cur.close()
            conn.close()
            result = _ok(
                {
                    "database_type": "Oracle",
                    "schema": schema_name,
                    "table": table_upper,
                    "columns": columns,
                    "primary_keys": primary_keys,
                    "foreign_keys": foreign_keys,
                    "indexes": indexes,
                }
            )
        except Exception as e:
            result = _db_error("Oracle table detail", e)
    else:
        result = _error("UNSUPPORTED_DB_TYPE", f"Unsupported DB_TYPE: {db_type}")

    if result.get("ok"):
        _cache[cache_key] = result
    return result


@mcp.resource("rules://db-schemas")
@log_access
def resource_db_schemas() -> Dict[str, Any]:
    return _execute_tool(lambda: _list_schemas(load_env()))


@mcp.tool()
@log_access
def list_schemas() -> Dict[str, Any]:
    """DB 내 스키마(네임스페이스) 목록을 조회합니다."""
    return _execute_tool(lambda: _list_schemas(load_env()))


@mcp.tool()
@log_access
def list_tables(schema_name: str) -> Dict[str, Any]:
    """특정 스키마에 속한 테이블 목록을 조회합니다."""
    return _execute_tool(lambda: _list_tables(load_env(), schema_name))


@mcp.tool()
@log_access
def get_table_detail(schema_name: str, table_name: str) -> Dict[str, Any]:
    """테이블의 컬럼, PK, FK, 인덱스 상세 정보를 조회합니다."""
    return _execute_tool(lambda: _table_detail(load_env(), schema_name, table_name))


@mcp.tool()
@log_access
def refresh_schema() -> Dict[str, str]:
    """인메모리 스키마 캐시를 초기화합니다."""
    _cache.clear()
    return {"status": "ok", "message": "Cache cleared."}


def _open_tty():
    """stdin/stdout 리다이렉션과 무관하게 TTY를 직접 엽니다."""
    if sys.platform == "win32":
        return open("CONOUT$", "w", encoding="utf-8"), open("CONIN$", "r", encoding="utf-8")
    return open("/dev/tty", "w"), open("/dev/tty", "r")


def _tty_read(tty_out, tty_in, prompt: str, default: str = "", secret: bool = False) -> str:
    """TTY로 프롬프트를 출력하고 입력값을 읽습니다."""
    display_default = "****" if (secret and default) else default
    full_prompt = f"  {prompt}"
    if display_default:
        full_prompt += f" [{display_default}]"
    full_prompt += ": "

    tty_out.write(full_prompt)
    tty_out.flush()

    if secret:
        import getpass
        value = getpass.getpass(prompt="", stream=tty_out)
    else:
        value = tty_in.readline().rstrip("\n")

    return value.strip() or default


def _save_env(env_path: Path, values: Dict[str, str]) -> None:
    """입력받은 값을 .env 파일로 저장합니다."""
    lines = []
    for key, value in values.items():
        if value:
            if any(c in value for c in (' ', '"', "'", '#', '$')):
                value = f'"{value}"'
            lines.append(f"{key}={value}")

    env_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _prompt_env_setup() -> None:
    """필수 환경변수가 없으면 MCP 시작 전 TTY로 대화형 입력을 받아 .env에 저장합니다."""
    env_path = PLUGIN_ROOT / ".env"
    config = load_env()

    db_type = (config.get("DB_TYPE") or "").strip().lower()
    if db_type == "sqlite":
        required = ["DB_TYPE", "DB_PATH"]
    elif db_type in ("postgresql", "mysql", "oracle"):
        required = ["DB_TYPE", "DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD"]
    else:
        required = ["DB_TYPE"]

    missing = [k for k in required if not config.get(k)]
    if not missing:
        return

    tty_out, tty_in = _open_tty()
    try:
        tty_out.write("\n")
        tty_out.write("=" * 52 + "\n")
        tty_out.write("  DB Schema Inspector — 초기 설정\n")
        tty_out.write("=" * 52 + "\n")
        if env_path.exists():
            tty_out.write(f"  일부 필수 항목이 누락되었습니다: {', '.join(missing)}\n")
        else:
            tty_out.write(f"  .env 파일이 없습니다. 설정값을 입력해주세요.\n")
        tty_out.write("  (기존 값이 있으면 Enter로 유지)\n")
        tty_out.write("-" * 52 + "\n\n")
        tty_out.flush()

        values: Dict[str, str] = dict(config)

        # DB_TYPE
        tty_out.write(" [DB 타입]\n")
        tty_out.write("  postgresql / mysql / sqlite / oracle\n")
        tty_out.flush()
        db_type_input = _tty_read(tty_out, tty_in, "DB_TYPE", config.get("DB_TYPE", "postgresql"))
        values["DB_TYPE"] = db_type_input
        db_type = db_type_input.strip().lower()

        tty_out.write("\n")
        tty_out.flush()

        if db_type == "sqlite":
            tty_out.write(" [SQLite 설정]\n")
            tty_out.flush()
            values["DB_PATH"] = _tty_read(tty_out, tty_in, "DB_PATH", config.get("DB_PATH", ""))

        elif db_type in ("postgresql", "mysql"):
            default_port = "5432" if db_type == "postgresql" else "3306"
            tty_out.write(f" [{'PostgreSQL' if db_type == 'postgresql' else 'MySQL'} 설정]\n")
            tty_out.flush()
            values["DB_HOST"] = _tty_read(tty_out, tty_in, "DB_HOST", config.get("DB_HOST", "localhost"))
            values["DB_PORT"] = _tty_read(tty_out, tty_in, "DB_PORT", config.get("DB_PORT", default_port))
            values["DB_NAME"] = _tty_read(tty_out, tty_in, "DB_NAME", config.get("DB_NAME", ""))
            values["DB_USER"] = _tty_read(tty_out, tty_in, "DB_USER", config.get("DB_USER", ""))
            values["DB_PASSWORD"] = _tty_read(tty_out, tty_in, "DB_PASSWORD", config.get("DB_PASSWORD", ""), secret=True)

        elif db_type == "oracle":
            tty_out.write(" [Oracle 설정]\n")
            tty_out.flush()
            values["DB_HOST"] = _tty_read(tty_out, tty_in, "DB_HOST", config.get("DB_HOST", "localhost"))
            values["DB_PORT"] = _tty_read(tty_out, tty_in, "DB_PORT", config.get("DB_PORT", "1521"))
            tty_out.write("  (서비스명 방식: DB_NAME 입력 / SID 방식: DB_SID 입력)\n")
            tty_out.flush()
            values["DB_NAME"] = _tty_read(tty_out, tty_in, "DB_NAME (서비스명)", config.get("DB_NAME", ""))
            values["DB_SID"] = _tty_read(tty_out, tty_in, "DB_SID (선택)", config.get("DB_SID", ""))
            values["DB_USER"] = _tty_read(tty_out, tty_in, "DB_USER", config.get("DB_USER", ""))
            values["DB_PASSWORD"] = _tty_read(tty_out, tty_in, "DB_PASSWORD", config.get("DB_PASSWORD", ""), secret=True)

        _save_env(env_path, values)

        tty_out.write("\n")
        tty_out.write(f"  .env 저장 완료: {env_path}\n")
        tty_out.write("=" * 52 + "\n\n")
        tty_out.flush()

    finally:
        tty_out.close()
        tty_in.close()


if __name__ == "__main__":
    _prompt_env_setup()
    logger.info("DB-Schema-Inspector MCP server starting (stdio transport)")
    mcp.run(transport="stdio")
