"""Database layer — SQL Server via pyodbc (parameterised '?').

MOCK_MODE=1 -> query tidak menyentuh DB, dijawab mock_rows() di queries.py.
MOCK_MODE=0 -> konek ke SQL Server (ODBC Driver 17) pakai MYSQL_* di .env
(kunci env MYSQL_* dipertahankan agar file .env yang ada tetap berlaku).
"""
from __future__ import annotations

import os
from typing import Any


def _load_env() -> None:
    """Load .env — prioritas: env proses (shell/CLI) > be/.env > .env root.

    dotenv tidak menimpa env yang sudah ter-set, jadi shell menang;
    di antara dua file, `be/.env` (dibaca pertama) yang menentukan.
    """
    try:
        from dotenv import load_dotenv
    except ImportError:
        return
    base = os.path.dirname(os.path.abspath(__file__))
    for path in (os.path.join(base, ".env"), os.path.join(os.path.dirname(base), ".env")):
        if os.path.isfile(path):
            load_dotenv(path, override=False)


_load_env()

# Mock HANYA mati kalau eksplisit "0"/"false"/"no"/"off" — nilai kosong
# atau tak dikenal tetap mock (default aman, jangan nyasar ke DB asli).
_FALSEY = {"0", "false", "no", "off"}
MOCK_MODE = os.getenv("MOCK_MODE", "1").strip().lower() not in _FALSEY

# Nama variabel + kunci env lama (MYSQL_*) dipertahankan agar file .env yang
# sudah ada tetap berlaku — targetnya sekarang SQL Server, bukan MySQL.
MYSQL_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "127.0.0.1"),
    "port": int(os.getenv("MYSQL_PORT", "1433")),
    "user": os.getenv("MYSQL_USER", ""),
    "password": os.getenv("MYSQL_PASSWORD", ""),
    "database": os.getenv("MYSQL_DATABASE", "bank_dashboard"),
    "driver": os.getenv("MSSQL_DRIVER", "ODBC Driver 17 for SQL Server"),
    "login_timeout": 15,  # batas handshake/login — JANGAN pernah tanpa batas
    "query_timeout": 60,  # batas eksekusi per query
}


def get_conn():
    import pyodbc  # lazy: mode mock & verifier ad-hoc tanpa driver tetap bisa import db

    cfg = MYSQL_CONFIG
    conn_str = (
        f"DRIVER={{{cfg['driver']}}};"
        f"SERVER={cfg['host']},{cfg['port']};"
        f"DATABASE={cfg['database']};"
        f"UID={cfg['user']};"
        f"PWD={cfg['password']};"
        "TrustServerCertificate=yes;"
        f"LoginTimeout={cfg['login_timeout']};"
    )
    conn = pyodbc.connect(conn_str, autocommit=True, timeout=cfg["login_timeout"])
    conn.timeout = cfg["query_timeout"]  # query timeout (SQL_ATTR_QUERY_TIMEOUT)
    return conn


def _rows(cur) -> list[dict[str, Any]]:
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def run_query(sql: str, params: tuple | list = ()) -> list[dict[str, Any]]:
    """Jalankan SELECT (parameterised) -> list of dict."""
    if MOCK_MODE:
        from queries import mock_rows  # lokal, hindari circular import

        return mock_rows(sql, params)
    sql = sql.replace("%s", "?")  # kompat query lama — pyodbc memakai qmark
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return _rows(cur)


def run_sql(sql: str, params: tuple | list = ()) -> int:
    """Jalankan INSERT/UPDATE/DELETE -> affected rows."""
    if MOCK_MODE:
        from queries import mock_write

        return mock_write(sql, params)
    sql = sql.replace("%s", "?")
    with get_conn() as conn:
        with conn.cursor() as cur:
            return cur.execute(sql, params).rowcount
