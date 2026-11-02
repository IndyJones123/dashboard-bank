"""BE Bank Dashboard — FastAPI + MySQL (parameterised query) + mode mock.

Jalankan:  uvicorn app:app --reload --port 8000  (dari folder be/)
Akun mock: admin/admin123 (admin) | user/user123 (member)
"""
from __future__ import annotations

import asyncio
import base64
import json
import os
import re
import unicodedata

from concurrent.futures import ThreadPoolExecutor
from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel

try:
    import pyodbc  # tersedia di .venv project; tanpa driver (verifier ad-hoc) -> None
except ImportError:  # pragma: no cover
    pyodbc = None

import auth
import db
import queries as Q
import queries_laporan as QL

app = FastAPI(title="Bank Dashboard API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[os.getenv("CORS_ORIGIN", "http://localhost:5173")],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

bearer = HTTPBearer(auto_error=False)


# ------------------------------------------- error DB -> respons yang jelas
def _db_error_state(exc: Exception) -> str:
    args = getattr(exc, "args", None)
    return args[0] if args and isinstance(args[0], str) else ""


def _db_detail(exc: Exception) -> str:
    """Bedaakan SQL/schema (SQLSTATE 42xxx) vs koneksi/autentikasi."""
    cfg = db.MYSQL_CONFIG
    tgt = f"{cfg['host']}:{cfg['port']}/{cfg['database']}"
    if _db_error_state(exc).startswith("42"):
        return (
            f"SQL gagal dieksekusi di {tgt} — {exc}. "
            "Cek nama tabel/kolom & bahasa query (be/queries.py)."
        )
    return (
        f"Database tidak terjangkau ({tgt}) — {type(exc).__name__}: {exc}. "
        "Cek VPN/host/port di be/.env, atau set MOCK_MODE=1 untuk mode mock."
    )


if pyodbc is not None:

    @app.exception_handler(pyodbc.Error)
    async def _db_error(request, exc):  # noqa: ANN001
        code = 500 if _db_error_state(exc).startswith("42") else 503
        return JSONResponse(status_code=code, content={"detail": _db_detail(exc)})


@app.exception_handler(OSError)
async def _io_error(request, exc):  # noqa: ANN001
    # socket timeout/error jaringan DB (bocor apa adanya dari driver)
    cfg = db.MYSQL_CONFIG
    tgt = f"{cfg['host']}:{cfg['port']}"
    return JSONResponse(
        status_code=503,
        content={"detail": f"Koneksi jaringan ke DB ({tgt}) gagal — {type(exc).__name__}: {exc}"},
    )


# ---------------------------------------------------------------- models
class LoginIn(BaseModel):
    username: str
    password: str


class LoginOut(BaseModel):
    token: str
    user: dict


# ---------------------------------------------------------------- helpers
def current_user(creds: HTTPAuthorizationCredentials | None = Depends(bearer)) -> dict:
    if creds is None or not creds.credentials:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token wajib")
    payload = auth.decode_token(creds.credentials)
    if payload is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token tidak valid/kadaluarsa")
    return payload


# ---------------------------------------------------------------- routes
@app.get("/api/health")
def health():
    return {"ok": True, "mock_mode": db.MOCK_MODE}


@app.post("/api/login", response_model=LoginOut)
def login(body: LoginIn):
    try:
        rows = db.run_query(Q.Q_USER_BY_USERNAME, (body.username,))
    except Exception as exc:
        if "42S02" not in str(exc):
            raise  # selain "objek tak ada" -> handler 503/500 dengan pesan asli
        # Tabel users tidak ada di DB asli -> autentikasi memakai akun mock
        rows = Q.mock_rows(Q.Q_USER_BY_USERNAME, (body.username,))
    if not rows:
        raise HTTPException(status_code=401, detail="Username atau password salah")
    user = rows[0]
    if not auth.verify_password(body.password, user.get("password_hash") or user.get("password") or ""):
        raise HTTPException(status_code=401, detail="Username atau password salah")
    token = auth.create_token(user)
    return {
        "token": token,
        "user": {
            "id": user["id"],
            "username": user["username"],
            "full_name": user.get("full_name", ""),
            "role": user.get("role", "member"),
        },
    }


# --- publik: boleh dilihat tanpa login
@app.get("/api/dashboard/stats")
def dashboard_stats():
    return db.run_query(Q.Q_DASHBOARD_STATS)[0]


@app.get("/api/dashboard/monthly-flow")
def monthly_flow():
    return db.run_query(Q.Q_MONTHLY_FLOW)


@app.get("/api/dashboard/recent-transactions")
def recent_transactions(limit: int = Query(5, ge=1, le=50)):
    return db.run_query(Q.Q_RECENT_TRANSACTIONS, (limit,))


# --- khusus login: butuh Authorization: Bearer <token>
@app.get("/api/accounts")
def accounts(limit: int = Query(10, ge=1, le=100), _me: dict = Depends(current_user)):
    return db.run_query(Q.Q_ACCOUNTS, (limit,))


@app.get("/api/dashboard/top-deposits")
def top_deposits(limit: int = Query(5, ge=1, le=50), _me: dict = Depends(current_user)):
    return db.run_query(Q.Q_TOP_DEPOSITS, (limit,))


@app.get("/api/dashboard/monthly-profit")
def monthly_profit(_me: dict = Depends(current_user)):
    return db.run_query(Q.Q_MONTHLY_PROFIT)


@app.get("/api/me")
def me(user: dict = Depends(current_user)):
    return {"id": user["sub"], "username": user["username"], "role": user.get("role"), "full_name": user.get("full_name")}


# ---------------------------------------------------------------- GL (Query1-Aset.sql)
_GL_KINDS = {
    "aset-konsolidasi": Q.Q_GL_ASET_KONSOLIDASI,
    "aset-perkantor": Q.Q_GL_ASET_PERKANTOR,
    "laba-rugi-konsolidasi": Q.Q_GL_PENDAPATAN_KONSOLIDASI,
    "laba-rugi-perkantor": Q.Q_GL_PENDAPATAN_PERKANTOR,
}


def _gl_range(kdloc: str) -> tuple[str, str]:
    kdloc = (kdloc or "00").strip() or "00"
    if kdloc == "00":
        return "01", "99"
    return kdloc, kdloc


@app.get("/api/gl/offices")
def gl_offices():
    return db.run_query(Q.Q_GL_OFFICES)


def _gl_as_tahunan(raw: list[dict], kind: str, is_aset: bool, yyyy: str) -> list[dict]:
    """Rekap per tahun utk granular=tahunan — 1 baris per (tahun, unit)."""
    if is_aset:
        # Aset = posisi: ambil saldo Desember tahun berjalan
        return [r for r in raw if r.get("thn") == yyyy and r.get("bln") == "12"]
    # Laba rugi = arus: totalkan setahun
    yr = [r for r in raw if r.get("thn") == yyyy]
    if not yr:
        return []
    if kind.endswith("konsolidasi"):
        total = sum(int(r.get("saldo") or 0) for r in yr)
        return [{
            "keterangan": yr[0].get("keterangan") or "Pendapatan Bulanan Konsolidasi",
            "judul": "Laba Rugi Konsolidasi", "thn": yyyy, "bln": "12",
            "saldo": total, "view": "tahunan",
        }]
    agg: dict[str, int] = {}
    ket = yr[0].get("keterangan") or "Pendapatan Bulanan Perkantor"
    for r in yr:
        k = r.get("kdloc")
        agg[k] = agg.get(k, 0) + int(r.get("saldo") or 0)
    return [{
        "keterangan": ket, "judul": "Laba Rugi Perkantor",
        "kdloc": k, "thn": yyyy, "bln": "12", "saldo": v, "view": "tahunan",
    } for k, v in sorted(agg.items())]


@app.get("/api/gl/{kind}")
def gl_report(
    kind: str,
    tahun: str = Query("2023", pattern=r"^\d{4}$"),
    kdloc: str = Query("00"),
    granular: str = Query("bulanan", pattern="^(bulanan|tahunan)$"),
    mulai: str | None = Query(None, pattern=r"^\d{4}$"),
    akhir: str | None = Query(None, pattern=r"^\d{4}$"),
):
    """GL report. bulanan = 1 tahun (param tahun). tahunan = RANGE tahun
    (mulai..akhir, default tahun..tahun) — 1 baris per tahun per unit."""
    sql = _GL_KINDS.get(kind)
    if sql is None:
        raise HTTPException(status_code=404, detail="Jenis laporan tidak dikenal")
    kdloc1, kdloc2 = _gl_range(kdloc)
    is_aset = kind.startswith("aset")

    y0, y1 = mulai or tahun, akhir or (mulai or tahun)
    if int(y1) < int(y0):
        y0, y1 = y1, y0
    if granular != "tahunan":
        y0 = y1 = tahun  # bulanan = 1 tahun saja, abaikan mulai/akhir

    rows: list[dict] = []
    for y in range(int(y0), int(y1) + 1):
        yyyy = str(y)
        yyold = str(int(yyyy) - 1)
        if is_aset:
            params = (yyold, kdloc1, kdloc2, yyyy, yyyy, yyyy, yyyy, kdloc1, kdloc2)
        else:
            params = (yyyy, yyyy, yyyy, yyyy, kdloc1, kdloc2)
        raw = db.run_query(sql, params)
        if granular == "tahunan":
            rows.extend(_gl_as_tahunan(raw, kind, is_aset, yyyy))
        else:
            rows.extend(raw)
    if kdloc != "00":
        rows = [r for r in rows if r.get("kdloc", kdloc) == kdloc]
    return {
        "kind": kind, "tahun": tahun, "mulai": y0, "akhir": y1,
        "kdloc": kdloc, "granular": granular, "rows": rows,
    }


# ---------------------------------------------------------------------------
# LAPORAN KEUANGAN BARU — port dari be/QueryData/Laporan-Keuangan-*.sql
# (file sumber legacy IBA, skrg jadi query resmi lewat db.run_query:
#  MOCK_MODE=1 -> fixtures queries.py, MOCK_MODE=0 -> SQL Server asli)
# ---------------------------------------------------------------------------

def _norm_saldo_series(raw: list[dict]) -> list[dict]:
    """Kolom hasil UNION ALL query DPK/Piutang bernama 'tgl31' (nama kolom dari
    SELECT pertama) — dinamai ulang 'saldo' biar konsisten dgn laporan GL."""
    out: list[dict] = []
    for r in raw:
        d = {k: r.get(k) for k in ("ket", "golac", "kdloc", "thn", "bln") if k in r}
        d["saldo"] = r.get("saldo", r.get("tgl31"))
        out.append(d)
    return out


@app.get("/api/laporan/harian")
def laporan_harian(
    tanggal: str = Query(..., pattern=r"^\d{4}-\d{2}-\d{2}$"),
    kdloc: str = Query("00", pattern=r"^\d{2}$"),
):
    """Laporan Keuangan Harian (Laporan-Keuangan-Harian.sql) — 18 baris posisi
    harian: Kas, Bank, dropping, outstanding pokok, angsuran/pelunasan
    (hari ini & bulan ini), NPL/NPF OJK+internal, pendapatan/biaya/laba rugi.
    Filter kantor dilakukan di SQL (range kodeloc); NPF (urut 12 & 14) = persen."""
    tglf = tanggal.replace("-", "")  # format query lama: YYYYMMDD
    rows = db.run_query(QL.Q_LAPORAN_HARIAN, (tglf, kdloc))
    return {"tanggal": tanggal, "kdloc": kdloc, "rows": rows}


@app.get("/api/laporan/dpk")
def laporan_dpk(
    tahun: str = Query(..., pattern=r"^\d{4}$"),
    kdloc: str = Query("00", pattern=r"^\d{2}$"),
):
    """Laporan DPK (Laporan-Keuangan-DPK.sql) — Tabungan + Deposito per kantor,
    bulanan: carry-over Des tahun lalu + 12 bulan tahun berjalan."""
    tab = _norm_saldo_series(db.run_query(QL.Q_LAPORAN_DPK_TABUNGAN, (tahun, kdloc)))
    dep = _norm_saldo_series(db.run_query(QL.Q_LAPORAN_DPK_DEPOSITO, (tahun, kdloc)))
    return {"tahun": tahun, "kdloc": kdloc, "rows": tab + dep}


@app.get("/api/laporan/piutang")
def laporan_piutang(
    tahun: str = Query(..., pattern=r"^\d{4}$"),
    kdloc: str = Query("00", pattern=r"^\d{2}$"),
):
    """Laporan Piutang (Laporan-Keuangan-Piutang.sql) — total piutang bulanan
    per kantor + rincian per golongan akun (golac) dari SETUPLOAN/SETUPASET."""
    rows = _norm_saldo_series(db.run_query(QL.Q_LAPORAN_PIUTANG, (tahun, kdloc)))
    golac = _norm_saldo_series(db.run_query(QL.Q_LAPORAN_PIUTANG_GOLAC, (tahun, kdloc)))
    return {"tahun": tahun, "kdloc": kdloc, "rows": rows, "golac": golac}


# ---------------------------------------------------------------------------
#  THEME GLOBAL (palet fitlink) — app_settings(key='theme', value=JSON 9 hex)
#  GET  : publik (semua user/tamu butuh warna saat load); gagal DB -> default.
#  PUT  : admin only; tabel dibuat idempoten saat pertama dipakai (lazy —
#         boot tidak pernah menunggu DB).
#  Token = 9 hex solid (FE menghitung var turunan: ring/soft/deret rgba).
# ---------------------------------------------------------------------------

THEME_KEY = "theme"
THEME_TOKENS = (
    "bg", "surface", "surface-2", "ink", "muted",
    "primary", "accent", "green", "red",
)
_HEX6 = re.compile(r"^#[0-9a-fA-F]{6}$")
# Nilai default = palet fitlink persis seperti :root fe/src/style.css
DEFAULT_THEME = {
    "bg": "#f8fafc",
    "surface": "#ffffff",
    "surface-2": "#f2f4f6",
    "ink": "#0f172a",
    "muted": "#475569",
    "primary": "#1e5fa3",
    "accent": "#4cb5ff",
    "green": "#22c55e",
    "red": "#dc2626",
}

_theme_ready = False


def _ensure_theme_table() -> None:
    """CREATE app_settings bila belum ada — idempoten, aman dipanggil ulang."""
    global _theme_ready
    if _theme_ready:
        return
    db.run_sql(Q.Q_APP_SETTINGS_CREATE)
    _theme_ready = True


def _load_theme() -> dict[str, str]:
    """Baca tema tersimpan, merge ke default; baris rusak/hilang -> default."""
    out = dict(DEFAULT_THEME)
    rows = db.run_query(Q.Q_THEME_GET, (THEME_KEY,))
    if not rows:
        return out
    try:
        saved = json.loads(rows[0].get("value") or "")
    except (ValueError, TypeError):
        return out
    if isinstance(saved, dict):
        for k, v in saved.items():
            if k in THEME_TOKENS and isinstance(v, str) and _HEX6.match(v):
                out[k] = v.lower()
    return out


class ThemeIn(BaseModel):
    tokens: dict[str, str]


@app.get("/api/theme")
def get_theme():
    """Palet tema global. Publik; DB/tabel tak tersedia -> palet default
    fitlink (JANGAN 500 — warna wajib tetap terkirim ke UI)."""
    try:
        if not db.MOCK_MODE:
            _ensure_theme_table()
        return {"tokens": _load_theme(), "source": "db"}
    except Exception:
        return {"tokens": dict(DEFAULT_THEME), "source": "default"}


@app.put("/api/theme")
def put_theme(body: ThemeIn, user: dict = Depends(current_user)):
    """Simpan palet (admin only). Hanya token dikenal dgn #RRGGBB valid;
    token lain diabaikan. Parsial di-merge dgn tema tersimpan."""
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Hanya admin yang boleh mengubah tema")
    tokens = {
        k: v.strip().lower()
        for k, v in body.tokens.items()
        if k in THEME_TOKENS and isinstance(v, str) and _HEX6.match(v.strip())
    }
    if not tokens:
        raise HTTPException(status_code=422, detail="Tidak ada token warna valid (format #RRGGBB)")
    try:
        if not db.MOCK_MODE:
            _ensure_theme_table()
        merged = {**_load_theme(), **tokens}
        value = json.dumps(merged, separators=(",", ":"))
        affected = db.run_sql(Q.Q_THEME_UPDATE, (value, THEME_KEY))
        if not affected:
            db.run_sql(Q.Q_THEME_INSERT, (THEME_KEY, value))
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Gagal menyimpan tema — {_db_detail(exc)}")
    return {"ok": True, "tokens": merged}


# ---------------------------------------------------------------------------
#  IDENTITAS BANK — app_settings(key='bank_name', value=teks nama bank)
#  GET  : publik (nama tampil di halaman login & untuk tamu); gagal DB -> default.
#  PUT  : admin only; spasi dirapikan, wajib terisi, maks BANK_NAME_MAX karakter.
# ---------------------------------------------------------------------------

BANK_NAME_KEY = "bank_name"
BANK_NAME_MAX = 60
DEFAULT_BANK_NAME = "BankDash"


def _clean_bank_name(raw: str) -> str:
    """Rapikan spasi; karakter kontrol ditolak (nilai tampil di UI & judul tab)."""
    name = " ".join(raw.split())
    return "" if any(unicodedata.category(c) == "Cc" for c in name) else name


def _load_bank_name() -> str:
    rows = db.run_query(Q.Q_THEME_GET, (BANK_NAME_KEY,))
    saved = _clean_bank_name(str(rows[0].get("value") or "")) if rows else ""
    return saved[:BANK_NAME_MAX] or DEFAULT_BANK_NAME


#  Logo & favicon: data URL base64 di app_settings (kkey bank_logo/bank_favicon).
#  Tipe ditentukan dari ISI file (bukan label kiriman) lalu data URL disusun ulang.
#  FE hanya memakainya lewat <img>/<link rel=icon>, tempat skrip SVG tidak jalan;
#  SVG berisi skrip tetap ditolak sebagai lapisan kedua.
BRAND_IMAGES = {
    "logo": {"key": "bank_logo", "max": 500 * 1024,
             "types": ("image/png", "image/jpeg", "image/webp", "image/svg+xml")},
    "favicon": {"key": "bank_favicon", "max": 100 * 1024,
                "types": ("image/png", "image/svg+xml", "image/x-icon")},
}
_DATA_URL = re.compile(r"^data:[^;,]*;base64,([A-Za-z0-9+/=\s]+)$")
_SVG_UNSAFE = re.compile(rb"<script|<foreignobject|<iframe|<embed|javascript:|\son\w+\s*=", re.I)


def _sniff_image(raw: bytes) -> str | None:
    """Tipe gambar dari byte awal; None bila bukan format yang didukung."""
    if raw.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if raw.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if raw[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        return "image/webp"
    if raw[:4] == b"\x00\x00\x01\x00":
        return "image/x-icon"
    head = raw[:2048].lstrip(b"\xef\xbb\xbf \t\r\n").lower()
    if (head.startswith(b"<svg") or head.startswith(b"<?xml")) and b"<svg" in raw.lower():
        return "image/svg+xml"
    return None


def _load_brand_image(kind: str) -> str | None:
    rows = db.run_query(Q.Q_THEME_GET, (BRAND_IMAGES[kind]["key"],))
    value = str(rows[0].get("value") or "") if rows else ""
    return value if value.startswith("data:image/") else None


class BrandingIn(BaseModel):
    bank_name: str


class BrandImageIn(BaseModel):
    kind: str
    data_url: str = ""  # kosong = hapus, kembali ke gambar bawaan


@app.get("/api/branding")
def get_branding():
    """Identitas bank. Publik; DB/tabel tak tersedia -> default (JANGAN 500)."""
    try:
        if not db.MOCK_MODE:
            _ensure_theme_table()
        return {
            "bank_name": _load_bank_name(),
            "logo": _load_brand_image("logo"),
            "favicon": _load_brand_image("favicon"),
            "source": "db",
        }
    except Exception:
        return {"bank_name": DEFAULT_BANK_NAME, "logo": None, "favicon": None, "source": "default"}


@app.put("/api/branding/image")
def put_brand_image(body: BrandImageIn, user: dict = Depends(current_user)):
    """Simpan/hapus logo atau favicon (admin only)."""
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Hanya admin yang boleh mengubah logo dan favicon")
    spec = BRAND_IMAGES.get(body.kind)
    if not spec:
        raise HTTPException(status_code=422, detail="Jenis gambar harus logo atau favicon")
    value = ""
    if body.data_url:
        limit_kb = spec["max"] // 1024
        too_big = f"Ukuran file maksimal {limit_kb} KB"
        if len(body.data_url) > spec["max"] * 2:
            raise HTTPException(status_code=422, detail=too_big)
        match = _DATA_URL.match(body.data_url)
        try:
            raw = base64.b64decode(match.group(1), validate=False) if match else b""
        except ValueError:
            raw = b""
        if len(raw) > spec["max"]:
            raise HTTPException(status_code=422, detail=too_big)
        mime = _sniff_image(raw)
        if mime not in spec["types"]:
            raise HTTPException(status_code=422, detail="Format file tidak didukung atau file rusak")
        if mime == "image/svg+xml" and _SVG_UNSAFE.search(raw):
            raise HTTPException(status_code=422, detail="File SVG berisi skrip dan ditolak")
        value = f"data:{mime};base64,{base64.b64encode(raw).decode('ascii')}"
    try:
        if not db.MOCK_MODE:
            _ensure_theme_table()
        affected = db.run_sql(Q.Q_THEME_UPDATE, (value, spec["key"]))
        if not affected:
            db.run_sql(Q.Q_THEME_INSERT, (spec["key"], value))
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Gagal menyimpan gambar: {_db_detail(exc)}")
    return {"ok": True, "kind": body.kind, "data_url": value or None}


@app.put("/api/branding")
def put_branding(body: BrandingIn, user: dict = Depends(current_user)):
    """Simpan nama bank (admin only)."""
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Hanya admin yang boleh mengubah nama bank")
    name = _clean_bank_name(body.bank_name)
    if not name:
        raise HTTPException(status_code=422, detail="Nama bank wajib diisi")
    if len(name) > BANK_NAME_MAX:
        raise HTTPException(status_code=422, detail=f"Nama bank maksimal {BANK_NAME_MAX} karakter")
    try:
        if not db.MOCK_MODE:
            _ensure_theme_table()
        affected = db.run_sql(Q.Q_THEME_UPDATE, (name, BANK_NAME_KEY))
        if not affected:
            db.run_sql(Q.Q_THEME_INSERT, (BANK_NAME_KEY, name))
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Gagal menyimpan nama bank: {_db_detail(exc)}")
    return {"ok": True, "bank_name": name}


# ---------------------------------------------------------------------------
#  MIGRASI — be/migrations.sql dijalankan saat boot (latar, threadpool).
#  Setiap batch WAJIB idempoten (guard IF OBJECT_ID ... IS NULL) supaya aman
#  diulang tiap start. Gagal/DB mati TIDAK memblokir boot (health & login
#  tetap jalan); lazy _ensure_theme_table tetap sbg jaring saat pertama
#  dipakai. MOCK_MODE dilewati (store in-memory via queries._MOCK_THEME).
# ---------------------------------------------------------------------------
def _ensure_schema() -> None:
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "migrations.sql")
    with open(path, encoding="utf-8") as fh:
        raw = fh.read()
    for part in raw.split("\nGO\n"):
        part = part.strip()
        if part:
            db.run_sql(part)


@app.on_event("startup")
async def run_migrations() -> None:
    if db.MOCK_MODE:
        return
    try:
        loop = asyncio.get_running_loop()
        await loop.run_in_executor(ThreadPoolExecutor(max_workers=1), _ensure_schema)
    except Exception as exc:
        # Jangan tahan boot — cetak sebabnya, jaring lazy menangani nanti.
        print(f"[migrasi] migrations.sql gagal diterapkan (lanjut boot): {exc}")
