"""Kumpulan query SQL + data mock (MOCK_MODE=1).

Setiap query diberi tag `/* name:xxx */` — mock_rows() memakai tag itu
untuk mengembalikan fixture. Saat MOCK_MODE=0 tag diabaikan dan query
jalan asli ke SQL Server (pyodbc, placeholder `?`).
"""
from __future__ import annotations

import re
from typing import Any

# ---------------------------------------------------------------------------
# QUERY (parameterised — jangan pernah f-string input user ke SQL)
# ---------------------------------------------------------------------------

Q_USER_BY_USERNAME = """
/* name:user_by_username */
SELECT TOP 1 id, username, password_hash, full_name, role
FROM users
WHERE username = ?
"""

Q_DASHBOARD_STATS = """
/* name:dashboard_stats */
SELECT
  (SELECT COUNT(*) FROM nasabah)                              AS total_nasabah,
  (SELECT COALESCE(SUM(saldo), 0) FROM rekening)              AS total_simpanan,
  (SELECT COUNT(*) FROM transaksi WHERE tanggal = CAST(GETDATE() AS DATE))  AS transaksi_hari_ini,
  (SELECT COALESCE(SUM(sisa_pokok), 0) FROM kredit WHERE status = 'berjalan') AS kredit_berjalan
"""

Q_MONTHLY_FLOW = """
/* name:monthly_flow */
SELECT
  FORMAT(tanggal, 'yyyy-MM') AS bulan,
  SUM(CASE WHEN jenis = 'SETOR'  THEN nominal ELSE 0 END) AS setor,
  SUM(CASE WHEN jenis = 'TARIK'  THEN nominal ELSE 0 END) AS tarik
FROM transaksi
WHERE tanggal >= DATEADD(MONTH, -6, CAST(GETDATE() AS DATE))
GROUP BY FORMAT(tanggal, 'yyyy-MM')
ORDER BY bulan
"""

Q_RECENT_TRANSACTIONS = """
/* name:recent_transactions */
SELECT TOP (?) t.id, t.tanggal, t.jenis, t.nominal, t.berita,
       r.no_rekening, n.nama AS nasabah
FROM transaksi t
JOIN rekening r ON r.id = t.rekening_id
JOIN nasabah n  ON n.id  = r.nasabah_id
ORDER BY t.tanggal DESC, t.id DESC
"""

Q_ACCOUNTS = """
/* name:accounts */
SELECT TOP (?) r.id, r.no_rekening, r.jenis, r.saldo, r.dibuka_pada,
       n.nama AS nasabah, n.kota
FROM rekening r
JOIN nasabah n ON n.id = r.nasabah_id
ORDER BY r.saldo DESC
"""

Q_TOP_DEPOSITS = """
/* name:top_deposits */
SELECT TOP (?) n.nama, n.kota, COUNT(r.id) AS jumlah_rekening, SUM(r.saldo) AS total_saldo
FROM nasabah n
JOIN rekening r ON r.nasabah_id = n.id
GROUP BY n.id, n.nama, n.kota
ORDER BY total_saldo DESC
"""


Q_MONTHLY_PROFIT = """
/* name:monthly_profit */
SELECT FORMAT(tanggal, 'yyyy-MM') AS bulan,
       SUM(CASE WHEN jenis = 'SETOR' THEN nominal ELSE 0 END) AS setor,
       SUM(CASE WHEN jenis = 'TARIK' THEN nominal ELSE 0 END) AS tarik,
       SUM(CASE WHEN jenis = 'SETOR' THEN nominal ELSE -nominal END) AS laba
FROM transaksi
WHERE tanggal >= DATEADD(MONTH, -6, CAST(GETDATE() AS DATE))
GROUP BY FORMAT(tanggal, 'yyyy-MM')
ORDER BY bulan
"""


# ---------------------------------------------------------------------------
# GL (M_NERACA03 + TBLGL) — port dari be/QueryData/Query1-Aset.sql (SQL Server)
# Parameter: (yyold, kdloc1, kdloc2, yyyy, yyyy, yyyy, yyyy, kdloc1, kdloc2)
# untuk aset; (yyyy, yyyy, yyyy, yyyy, kdloc1, kdloc2) untuk pendapatan.
# kdloc='00' -> kdloc1='01', kdloc2='99' (semua kantor).
# ---------------------------------------------------------------------------

Q_GL_ASET_KONSOLIDASI = """
/* name:gl_aset_konsolidasi */
SELECT 'Aset Konsolidasi PerBulan' AS keterangan, B.thn AS thn, B.bln AS bln, B.saldo AS saldo
FROM (
  SELECT n.thn AS thn, n.bln AS bln, SUM(n.tgl11) AS saldo
  FROM M_NERACA03 n
  INNER JOIN TBLGL g ON g.nosbb = n.nosbb
  WHERE n.thn = ? AND n.bln = '12'
    AND g.jnsgol = 'C' AND g.golac = '1'
    AND n.kodeloc BETWEEN ? AND ?
  GROUP BY n.thn, n.bln
  UNION ALL
  SELECT A.thn AS thn, A.bln AS bln,
    CASE
      WHEN A.bln = '01' THEN SUM(A.tgl31)
      WHEN A.bln = '02' AND A.ket = 'Kabisat' THEN SUM(A.tgl29)
      WHEN A.bln = '02' AND A.ket = 'Bukan' THEN SUM(A.tgl28)
      WHEN A.bln = '03' THEN SUM(A.tgl31)
      WHEN A.bln = '04' THEN SUM(A.tgl30)
      WHEN A.bln = '05' THEN SUM(A.tgl31)
      WHEN A.bln = '06' THEN SUM(A.tgl30)
      WHEN A.bln = '07' THEN SUM(A.tgl31)
      WHEN A.bln = '08' THEN SUM(A.tgl31)
      WHEN A.bln = '09' THEN SUM(A.tgl30)
      WHEN A.bln = '10' THEN SUM(A.tgl31)
      WHEN A.bln = '11' THEN SUM(A.tgl30)
      WHEN A.bln = '12' THEN SUM(A.tgl31)
      ELSE 0
    END AS saldo
  FROM (
    SELECT n.thn AS thn, n.bln AS bln,
      CASE WHEN CAST(? AS INT) % 400 = 0 THEN 'Kabisat'
           WHEN CAST(? AS INT) % 4 = 0 AND CAST(? AS INT) % 100 <> 0 THEN 'Kabisat'
           ELSE 'Bukan' END AS ket,
      SUM(n.tgl08) AS tgl28, SUM(n.tgl09) AS tgl29,
      SUM(n.tgl10) AS tgl30, SUM(n.tgl11) AS tgl31
    FROM M_NERACA03 n
    INNER JOIN TBLGL g ON g.nosbb = n.nosbb
    WHERE n.thn = ?
      AND g.jnsgol = 'C' AND g.golac = '1'
      AND n.kodeloc BETWEEN ? AND ?
    GROUP BY n.thn, n.bln
  ) A
  GROUP BY A.thn, A.bln, A.ket
) B
ORDER BY B.thn, B.bln
"""

Q_GL_ASET_PERKANTOR = """
/* name:gl_aset_perkantor */
SELECT 'Aset Perlokasi PerBulan' AS keterangan, B.kdloc AS kdloc, B.thn AS thn, B.bln AS bln, B.saldo AS saldo
FROM (
  SELECT n.kodeloc AS kdloc, n.thn AS thn, n.bln AS bln, SUM(n.tgl11) AS saldo
  FROM M_NERACA03 n
  INNER JOIN TBLGL g ON g.nosbb = n.nosbb
  WHERE n.thn = ? AND n.bln = '12'
    AND g.jnsgol = 'C' AND g.golac = '1'
    AND n.kodeloc BETWEEN ? AND ?
  GROUP BY n.kodeloc, n.thn, n.bln
  UNION ALL
  SELECT A.kdloc AS kdloc, A.thn AS thn, A.bln AS bln,
    CASE
      WHEN A.bln = '01' THEN SUM(A.tgl31)
      WHEN A.bln = '02' AND A.ket = 'Kabisat' THEN SUM(A.tgl29)
      WHEN A.bln = '02' AND A.ket = 'Bukan' THEN SUM(A.tgl28)
      WHEN A.bln = '03' THEN SUM(A.tgl31)
      WHEN A.bln = '04' THEN SUM(A.tgl30)
      WHEN A.bln = '05' THEN SUM(A.tgl31)
      WHEN A.bln = '06' THEN SUM(A.tgl30)
      WHEN A.bln = '07' THEN SUM(A.tgl31)
      WHEN A.bln = '08' THEN SUM(A.tgl31)
      WHEN A.bln = '09' THEN SUM(A.tgl30)
      WHEN A.bln = '10' THEN SUM(A.tgl31)
      WHEN A.bln = '11' THEN SUM(A.tgl30)
      WHEN A.bln = '12' THEN SUM(A.tgl31)
      ELSE 0
    END AS saldo
  FROM (
    SELECT n.kodeloc AS kdloc, n.thn AS thn, n.bln AS bln,
      CASE WHEN CAST(? AS INT) % 400 = 0 THEN 'Kabisat'
           WHEN CAST(? AS INT) % 4 = 0 AND CAST(? AS INT) % 100 <> 0 THEN 'Kabisat'
           ELSE 'Bukan' END AS ket,
      SUM(n.tgl08) AS tgl28, SUM(n.tgl09) AS tgl29,
      SUM(n.tgl10) AS tgl30, SUM(n.tgl11) AS tgl31
    FROM M_NERACA03 n
    INNER JOIN TBLGL g ON g.nosbb = n.nosbb
    WHERE n.thn = ?
      AND g.jnsgol = 'C' AND g.golac = '1'
      AND n.kodeloc BETWEEN ? AND ?
    GROUP BY n.kodeloc, n.thn, n.bln
  ) A
  GROUP BY A.kdloc, A.thn, A.bln, A.ket
) B
ORDER BY B.kdloc, B.thn, B.bln
"""

Q_GL_PENDAPATAN_KONSOLIDASI = """
/* name:gl_pendapatan_konsolidasi */
SELECT 'Pendapatan Bulanan Konsolidasi' AS keterangan, A.thn AS thn, A.bln AS bln,
  CASE
    WHEN A.bln = '01' THEN SUM(A.tgl31)
    WHEN A.bln = '02' AND A.ket = 'Kabisat' THEN SUM(A.tgl29)
    WHEN A.bln = '02' AND A.ket = 'Bukan' THEN SUM(A.tgl28)
    WHEN A.bln = '03' THEN SUM(A.tgl31)
    WHEN A.bln = '04' THEN SUM(A.tgl30)
    WHEN A.bln = '05' THEN SUM(A.tgl31)
    WHEN A.bln = '06' THEN SUM(A.tgl30)
    WHEN A.bln = '07' THEN SUM(A.tgl31)
    WHEN A.bln = '08' THEN SUM(A.tgl31)
    WHEN A.bln = '09' THEN SUM(A.tgl30)
    WHEN A.bln = '10' THEN SUM(A.tgl31)
    WHEN A.bln = '11' THEN SUM(A.tgl30)
    WHEN A.bln = '12' THEN SUM(A.tgl31)
    ELSE 0
  END AS saldo
FROM (
  SELECT n.thn AS thn, n.bln AS bln,
    CASE WHEN CAST(? AS INT) % 400 = 0 THEN 'Kabisat'
         WHEN CAST(? AS INT) % 4 = 0 AND CAST(? AS INT) % 100 <> 0 THEN 'Kabisat'
         ELSE 'Bukan' END AS ket,
    SUM(n.tgl08) AS tgl28, SUM(n.tgl09) AS tgl29,
    SUM(n.tgl10) AS tgl30, SUM(n.tgl11) AS tgl31
  FROM M_NERACA03 n
  INNER JOIN TBLGL g ON g.nosbb = n.nosbb
  WHERE n.thn = ?
    AND g.jnsgol = 'C' AND g.stsac = 'S'
    AND n.kodeloc BETWEEN ? AND ?
  GROUP BY n.thn, n.bln
) A
GROUP BY A.thn, A.bln, A.ket
ORDER BY A.thn, A.bln
"""

Q_GL_PENDAPATAN_PERKANTOR = """
/* name:gl_pendapatan_perkantor */
SELECT 'Pendapatan Bulanan Perkantor' AS keterangan, A.kdloc AS kdloc, A.thn AS thn, A.bln AS bln,
  CASE
    WHEN A.bln = '01' THEN SUM(A.tgl31)
    WHEN A.bln = '02' AND A.ket = 'Kabisat' THEN SUM(A.tgl29)
    WHEN A.bln = '02' AND A.ket = 'Bukan' THEN SUM(A.tgl28)
    WHEN A.bln = '03' THEN SUM(A.tgl31)
    WHEN A.bln = '04' THEN SUM(A.tgl30)
    WHEN A.bln = '05' THEN SUM(A.tgl31)
    WHEN A.bln = '06' THEN SUM(A.tgl30)
    WHEN A.bln = '07' THEN SUM(A.tgl31)
    WHEN A.bln = '08' THEN SUM(A.tgl31)
    WHEN A.bln = '09' THEN SUM(A.tgl30)
    WHEN A.bln = '10' THEN SUM(A.tgl31)
    WHEN A.bln = '11' THEN SUM(A.tgl30)
    WHEN A.bln = '12' THEN SUM(A.tgl31)
    ELSE 0
  END AS saldo
FROM (
  SELECT n.kodeloc AS kdloc, n.thn AS thn, n.bln AS bln,
    CASE WHEN CAST(? AS INT) % 400 = 0 THEN 'Kabisat'
         WHEN CAST(? AS INT) % 4 = 0 AND CAST(? AS INT) % 100 <> 0 THEN 'Kabisat'
         ELSE 'Bukan' END AS ket,
    SUM(n.tgl08) AS tgl28, SUM(n.tgl09) AS tgl29,
    SUM(n.tgl10) AS tgl30, SUM(n.tgl11) AS tgl31
  FROM M_NERACA03 n
  INNER JOIN TBLGL g ON g.nosbb = n.nosbb
  WHERE n.thn = ?
    AND g.jnsgol = 'C' AND g.stsac = 'S'
    AND n.kodeloc BETWEEN ? AND ?
  GROUP BY n.kodeloc, n.thn, n.bln
) A
GROUP BY A.kdloc, A.thn, A.bln, A.ket
ORDER BY A.kdloc, A.thn, A.bln
"""

Q_GL_OFFICES = """
/* name:gl_offices */
SELECT DISTINCT kodeloc AS kdloc FROM M_NERACA03 ORDER BY kodeloc
"""

# ---------------------------------------------------------------------------
# MOCK FIXTURES — data dummy untuk mode mock
# ---------------------------------------------------------------------------

_MOCK_USER = {
    "id": 1,
    "username": "admin",
    "password_hash": "21232f297a57a5a743894a0e4a801fc3",  # sha256/md5? -> auth.hash_password di bawah
    "full_name": "Administrator",
    "role": "admin",
}

# hash dihitung ulang di auth.py; mock cuma menyimpan marker plaintext sementara
_MOCK_USERS = [
    {"id": 1, "username": "admin", "password": "admin123", "full_name": "Budi Santoso", "role": "admin"},
    {"id": 2, "username": "user", "password": "user123", "full_name": "Siti Aminah", "role": "member"},
]

_MOCK_STATS = {
    "total_nasabah": 1284,
    "total_simpanan": 487_650_000_000,
    "transaksi_hari_ini": 3421,
    "kredit_berjalan": 192_400_000_000,
}

_MONTHS = ["2026-05", "2026-06", "2026-07", "2026-08", "2026-09", "2026-10"]
_MOCK_FLOW = [
    {"bulan": _MONTHS[0], "setor": 38_500_000_000, "tarik": 31_200_000_000},
    {"bulan": _MONTHS[1], "setor": 41_300_000_000, "tarik": 33_800_000_000},
    {"bulan": _MONTHS[2], "setor": 39_700_000_000, "tarik": 36_100_000_000},
    {"bulan": _MONTHS[3], "setor": 45_900_000_000, "tarik": 34_500_000_000},
    {"bulan": _MONTHS[4], "setor": 47_200_000_000, "tarik": 38_900_000_000},
    {"bulan": _MONTHS[5], "setor": 51_600_000_000, "tarik": 40_300_000_000},
]

_MOCK_TRANSACTIONS = [
    {"id": 101, "tanggal": "2026-10-14", "jenis": "SETOR", "nominal": 12_500_000, "berita": "Transfer masuk gaji", "no_rekening": "0011-2233-4455", "nasabah": "Andi Wijaya"},
    {"id": 100, "tanggal": "2026-10-14", "jenis": "TARIK", "nominal": 2_750_000, "berita": "Tarik tunai ATM", "no_rekening": "0099-8877-6655", "nasabah": "Dewi Lestari"},
    {"id": 99, "tanggal": "2026-10-13", "jenis": "SETOR", "nominal": 45_000_000, "berita": "Setoran tunai cabang", "no_rekening": "0011-2233-4455", "nasabah": "Andi Wijaya"},
    {"id": 98, "tanggal": "2026-10-13", "jenis": "TARIK", "nominal": 8_900_000, "berita": "Bayar supplier", "no_rekening": "0044-5566-7788", "nasabah": "Rudi Hartono"},
    {"id": 97, "tanggal": "2026-10-12", "jenis": "SETOR", "nominal": 6_200_000, "berita": "Setoran bisnis", "no_rekening": "0044-5566-7788", "nasabah": "Rudi Hartono"},
    {"id": 96, "tanggal": "2026-10-12", "jenis": "TARIK", "nominal": 15_000_000, "berita": "Penarikan rekening koran", "no_rekening": "0099-8877-6655", "nasabah": "Dewi Lestari"},
]

_MOCK_ACCOUNTS = [
    {"id": 1, "no_rekening": "0044-5566-7788", "jenis": "Giro Bisnis", "saldo": 985_400_000, "dibuka_pada": "2019-03-11", "nasabah": "Rudi Hartono", "kota": "Jakarta"},
    {"id": 2, "no_rekening": "0011-2233-4455", "jenis": "Tabungan Gold", "saldo": 642_150_000, "dibuka_pada": "2020-07-02", "nasabah": "Andi Wijaya", "kota": "Bandung"},
    {"id": 3, "no_rekening": "0099-8877-6655", "jenis": "Deposito", "saldo": 512_000_000, "dibuka_pada": "2021-01-19", "nasabah": "Dewi Lestari", "kota": "Surabaya"},
    {"id": 4, "no_rekening": "0022-3344-5566", "jenis": "Tabungan Reguler", "saldo": 87_320_000, "dibuka_pada": "2022-09-30", "nasabah": "Maya Putri", "kota": "Semarang"},
    {"id": 5, "no_rekening": "0077-6655-4433", "jenis": "Tabungan Pelajar", "saldo": 5_640_000, "dibuka_pada": "2024-02-14", "nasabah": "Joko Susilo", "kota": "Yogyakarta"},
]

_MOCK_TOP_DEPOSITS = [
    {"nama": "Rudi Hartono", "kota": "Jakarta", "jumlah_rekening": 3, "total_saldo": 1_420_600_000},
    {"nama": "Andi Wijaya", "kota": "Bandung", "jumlah_rekening": 2, "total_saldo": 891_300_000},
    {"nama": "Dewi Lestari", "kota": "Surabaya", "jumlah_rekening": 2, "total_saldo": 655_900_000},
    {"nama": "Maya Putri", "kota": "Semarang", "jumlah_rekening": 1, "total_saldo": 87_320_000},
    {"nama": "Joko Susilo", "kota": "Yogyakarta", "jumlah_rekening": 1, "total_saldo": 5_640_000},
]

_MOCK_PROFIT = [
    {"bulan": m, "laba_bunga": round(f * 0.015, 2)}
    for m, f in zip(_MONTHS, [x["setor"] for x in _MOCK_FLOW])
]

# ---------------------------------------------------------------------------
# MOCK GL — mensimulasikan hasil 4 query Query1-Aset.sql per (tahun, kantor).
# Saldo akhir bulan dihitung deterministik dari seed agar stabil antar request.
# ---------------------------------------------------------------------------

_MOCK_GL_BASE = [
    {"kdloc": "01", "aset_base": 1_420_600_000_000, "aset_grow": 8_500_000_000, "pl_base": 12_400_000_000, "pl_grow": 320_000_000},
    {"kdloc": "02", "aset_base": 891_300_000_000, "aset_grow": 5_100_000_000, "pl_base": 7_800_000_000, "pl_grow": 190_000_000},
    {"kdloc": "03", "aset_base": 655_900_000_000, "aset_grow": 3_700_000_000, "pl_base": 5_600_000_000, "pl_grow": 140_000_000},
]

_MOCK_GL_KET = {
    "gl_aset_konsolidasi": "Aset Konsolidasi PerBulan",
    "gl_aset_perkantor": "Aset Perlokasi PerBulan",
    "gl_pendapatan_konsolidasi": "Pendapatan Bulanan Konsolidasi",
    "gl_pendapatan_perkantor": "Pendapatan Bulanan Perkantor",
}

_MOCK_GL_TITLE = {
    "gl_aset_konsolidasi": "Aset Konsolidasi",
    "gl_aset_perkantor": "Aset Perkantor",
    "gl_pendapatan_konsolidasi": "Laba Rugi Konsolidasi",
    "gl_pendapatan_perkantor": "Laba Rugi Perkantor",
}


def _gl_year(params: tuple | list = ()) -> str:
    years = [str(p) for p in params if len(str(p)) == 4 and str(p).isdigit()]
    # aset mengirim yyold + yyyy — ambil yang terbesar (= tahun berjalan)
    return max(years) if years else "2023"


def _mock_gl(name: str, params: tuple | list = ()) -> list[dict[str, Any]]:
    yyyy = _gl_year(params)
    yyold = str(int(yyyy) - 1)
    konsol = name.endswith("konsolidasi")
    is_aset = "aset" in name
    # hormati rentang kantor dari params (kdloc1..kdloc2 = string 2 digit)
    cands = [str(p) for p in params if len(str(p)) == 2 and str(p).isdigit()]
    offices = [dict(o) for o in _MOCK_GL_BASE]
    if len(cands) >= 2:
        lo, hi = cands[0], cands[-1]
        offices = [o for o in offices if lo <= o["kdloc"] <= hi] or offices

    def saldo(kind: str, kdloc: str, mi: int) -> int:
        o = next(x for x in _MOCK_GL_BASE if x["kdloc"] == kdloc)
        drift = (int(yyyy) - 2023) * (40_000_000_000 if kind == "aset" else 2_000_000_000)
        if kind == "aset":
            return int(o["aset_base"] + o["aset_grow"] * mi + drift)
        return int(o["pl_base"] + o["pl_grow"] * mi + drift)

    rows: list[dict[str, Any]] = []
    if is_aset:
        # baris carry-over: posisi Des tahun lalu
        months = [("12", yyold, 0)] + [(f"{m:02d}", yyyy, m) for m in range(1, 13)]
    else:
        months = [(f"{m:02d}", yyyy, m) for m in range(1, 13)]
    for bln, thn, mi in months:
        if konsol:
            total = sum(saldo("aset" if is_aset else "pl", o["kdloc"], mi) for o in offices)
            rows.append({
                "keterangan": _MOCK_GL_KET[name], "judul": _MOCK_GL_TITLE[name],
                "thn": thn, "bln": bln, "saldo": total,
                "view": "tahunan" if is_aset and mi == 0 else "bulanan",
            })
        else:
            for o in offices:
                rows.append({
                    "keterangan": _MOCK_GL_KET[name], "judul": _MOCK_GL_TITLE[name],
                    "kdloc": o["kdloc"], "thn": thn, "bln": bln,
                    "saldo": saldo("aset" if is_aset else "pl", o["kdloc"], mi),
                    "view": "tahunan" if is_aset and mi == 0 else "bulanan",
                })
    return rows


def _tag(sql: str) -> str | None:
    m = re.search(r"/\*\s*name:([a-z_]+)\s*\*/", sql)
    return m.group(1) if m else None


def mock_users() -> list[dict[str, Any]]:
    return [dict(u) for u in _MOCK_USERS]


def mock_rows(sql: str, params: tuple | list = ()) -> list[dict[str, Any]]:
    """Pengganti eksekusi SQL saat MOCK_MODE=1."""
    name = _tag(sql)

    if name == "user_by_username":
        username = params[0] if params else ""
        return [dict(u) for u in _MOCK_USERS if u["username"] == username]
    if name == "dashboard_stats":
        return [dict(_MOCK_STATS)]
    if name == "monthly_flow":
        return [dict(r) for r in _MOCK_FLOW]
    if name == "recent_transactions":
        limit = int(params[0]) if params else 5
        return [dict(r) for r in _MOCK_TRANSACTIONS[:limit]]
    if name == "accounts":
        limit = int(params[0]) if params else 10
        return [dict(r) for r in _MOCK_ACCOUNTS[:limit]]
    if name == "top_deposits":
        limit = int(params[0]) if params else 5
        return [dict(r) for r in _MOCK_TOP_DEPOSITS[:limit]]
    if name == "monthly_profit":
        return [dict(r) for r in _MOCK_PROFIT]
    if name == "gl_offices":
        return [{"kdloc": k} for k in sorted({r["kdloc"] for r in _MOCK_GL_BASE})]
    if name in ("gl_aset_konsolidasi", "gl_aset_perkantor",
                "gl_pendapatan_konsolidasi", "gl_pendapatan_perkantor"):
        return _mock_gl(name, params)
    if name == "laporan_harian":
        return _mock_lkh(params)
    if name in ("dpk_tabungan", "dpk_deposito", "piutang"):
        return _mock_dpk(params, name)
    if name == "piutang_golac":
        return _mock_piutang_golac(params)

    return []


def mock_write(sql: str, params: tuple | list = ()) -> int:
    return 1


# ---------------------------------------------------------------------------
# MOCK LAPORAN KEUANGAN (queries_laporan.py — Harian / DPK / Piutang)
# Sumber data: be/QueryData/Laporan-Keuangan-{Harian,DPK,Piutang}.sql
# Deterministik dari seed (tglf / yyyy) supaya stabil antar request.
# ---------------------------------------------------------------------------

_OFFICES = ("01", "02", "03")
_OFFICE_W = {"01": 1.0, "02": 0.72, "03": 0.55}  # bobot per kantor utk agregasi konsol


def _offices_from(params: tuple | list) -> list[str]:
    """kdloc param terakhir; '00'/absen -> semua kantor."""
    kdloc = str(params[-1]).strip() if params else "00"
    return list(_OFFICES) if kdloc in ("", "00") else [kdloc if kdloc in _OFFICE_W else _OFFICES[0]]


def _lkh_factor(params: tuple | list) -> float:
    """Skala LKH tergantung filter kantor: '00' -> semua (1.0), sebagian -> proporsional."""
    kdloc = str(params[-1]).strip() if params else "00"
    if kdloc in ("", "00"):
        return 1.0
    total = sum(_OFFICE_W.values())
    return _OFFICE_W.get(kdloc, _OFFICE_W[_OFFICES[0]]) / total


# (urut, ket, base saldo konsolidasi per hari, volatilitas)
_LKH_ROWS: list[tuple[str, str, int, int]] = [
    ("01", "Kas", 2_400_000_000, 150_000_000),
    ("02", "Bank", 85_000_000_000, 900_000_000),
    ("03", "Droping hari ini", 1_750_000_000, 900_000_000),
    ("04", "OS Pokok Harian/Mingguan", 118_500_000_000, 1_200_000_000),
    ("05", "OS Pokok Bulanan", 352_000_000_000, 1_600_000_000),
    ("06", "Total OS Pokok", 470_500_000_000, 2_500_000_000),
    ("07", "Angsuran dan Pelunasan Pokok Hari ini", 2_900_000_000, 1_500_000_000),
    ("08", "Angsuran dan Pelunasan Margin Hari ini", 410_000_000, 210_000_000),
    ("09", "Angsuran dan Pelunasan Pokok Bulan ini", 62_000_000_000, 4_000_000_000),
    ("10", "Angsuran dan Pelunasan Margin Bulan ini", 8_700_000_000, 600_000_000),
    ("11", "NPL OJK", 21_800_000_000, 500_000_000),
    ("12", "NPF OJK (%)", 464, 2),  # x100 — tampil 4.64%
    ("13", "NPL Internal", 15_400_000_000, 400_000_000),
    ("14", "NPF Internal (%)", 328, 2),  # tampil 3.28%
    ("15", "Pendapatan Bulan ini", 14_800_000_000, 900_000_000),
    ("16", "Biaya Bulan ini", 6_100_000_000, 400_000_000),
    ("17", "Rugi Laba Bulan ini", 8_700_000_000, 700_000_000),
    ("18", "Rugi Laba Bulan Berjalan", 9_150_000_000, 800_000_000),
]
_LKH_PERCENT = {"12", "14"}  # NPF persen, bukan Rupiah


def _mock_lkh(params: tuple | list) -> list[dict[str, Any]]:
    """18 baris konsolidasi persis bentuk query asli: {urut, ket, saldo}."""
    tglf = str(params[0]) if params else "20250629"
    n = int(tglf[6:8])
    f = _lkh_factor(params)
    rows: list[dict[str, Any]] = []
    for urut, ket, base, vol in _LKH_ROWS:
        if urut in _LKH_PERCENT:
            jitter = ((n * 17 + 7) % 5) - 2
            rows.append({"urut": urut, "ket": ket, "saldo": round((base + jitter) / 100, 2)})
        else:
            jitter = ((n * 37 + int(urut) * 13) % 15) - 7  # -7..+7 persen
            saldo = int(base * f * (100 + jitter) / 100) + int(vol * f * ((n * 7 + 3) % 9))
            rows.append({"urut": urut, "ket": ket, "saldo": saldo})
    return rows


def _series(kdloc: str, base: float, grow: float, thn: str, ket: str) -> list[dict[str, Any]]:
    """13 baris: carry-over Des thn-1 (tgl11) + 12 bulan thn berjalan (tgl28..31)."""
    y = int(thn)
    w = _OFFICE_W.get(kdloc, 1.0)
    rows = [{
        "ket": ket, "kdloc": kdloc, "thn": str(y - 1), "bln": "12",
        "tgl31": int(base * w * 0.92), "tgl28": 0, "tgl29": 0, "tgl30": 0,
    }]
    for m in range(1, 13):
        v = int((base + grow * m) * w)
        # Bentuk baris = hasil query ASLI pasca-CASE: kolom hasil selalu 'tgl31'
        # (UNION pertama SELECT tgl31 → nama kolom hasil). Bulan 28/29/30 hari
        # sudah dipilih CASE di SQL; mock taruh v langsung di tgl31 — kalau
        # ditulis di tgl28/tgl29, _norm_saldo_series cuma baca tgl31 → Feb=0.
        rows.append({
            "ket": ket, "kdloc": kdloc, "thn": thn, "bln": f"{m:02d}",
            "tgl31": v, "tgl28": 0, "tgl29": 0, "tgl30": 0,
        })
    return rows


def _mock_dpk(params: tuple | list, which: str) -> list[dict[str, Any]]:
    thn = str(params[0]) if params else "2024"
    specs = {
        "dpk_tabungan": ("DPK Tabungan", 210_000_000_000, 3_800_000_000),
        "dpk_deposito": ("DPK Deposito", 96_000_000_000, 1_900_000_000),
        "piutang": ("Piutang", 385_000_000_000, 4_600_000_000),
    }
    ket, base, grow = specs[which]
    rows: list[dict[str, Any]] = []
    for k in _offices_from(params):
        rows.extend(_series(k, base, grow, thn, ket))
    return rows


def _mock_piutang_golac(params: tuple | list) -> list[dict[str, Any]]:
    thn = str(params[0]) if params else "2024"
    rows: list[dict[str, Any]] = []
    for g, base, grow in (("1", 385_000_000_000, 4_600_000_000), ("2", 34_000_000_000, 400_000_000)):
        for k in _offices_from(params):
            for r in _series(k, base, grow, thn, "Rincian Piutang"):
                r["golac"] = g
                rows.append(r)
    return rows
