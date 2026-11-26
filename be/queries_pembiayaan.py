"""Query Pembiayaan — dibaca LANGSUNG dari be/QueryData/pembiayaan/*.sql.

File .sql adalah sumber kebenaran: edit query di folder itu, BE memakai versi
terbaru tanpa porting ulang (cache di-refresh saat mtime file berubah).

Transformasi minimal saat dimuat (isi query tidak diubah):
  - escape ODBC outer-join `{ oj ... }` dilepas (JOIN di dalamnya tetap sama)
  - SET literal utk parameter filter (@periode / @thn / @kdloc) -> qmark '?'
    (urutan params = urutan baris SET di file)
  - file dipecah per komentar seksi level atas ("-- ..."): tiap seksi
    dijalankan sbg batch sendiri = blok DECLARE/SET + 1 SELECT
  - prefiks SET NOCOUNT ON + ANSI_WARNINGS/ARITHABORT OFF: pembagian nol
    (mis. NPF saat OS = 0) menghasilkan NULL, bukan membatalkan laporan

Nama seksi dari teks komentar: 'nasabah' / 'lokasi' (lokasi & produk) / 'ao'.
"""
from __future__ import annotations

import os
import re
from typing import Any

_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "QueryData", "pembiayaan")

# key -> nama file di be/QueryData/pembiayaan
FILES: dict[str, str] = {
    "realisasi_berjalan": "001 Pembiayaan Realisasi Berjalan.sql",
    "realisasi_bulan": "002 Pembiayaan Realisasi Perbulan.sql",
    "dpd": "Pembiayaan DPD Revisi.sql",
    "npf_berjalan": "Pembiayaan NPF berjalan.sql",
    "npf_bulan": "Pembiayaan NPF Bulan.sql",
    "os_bulan": "Pembiayaan OS Bulan.sql",
    "os_berjalan": "004 Pembiayaan OS Berjalan.sql",
    "tunggakan": "Pembiayaan Tunggakan.sql",
    "jatuh_tempo": "Pembiayaan JatuhTempo.sql",
    "target_ao": "003 Pembiayaan Target AO.sql",
}

# Tanggal sistem (ddmmyyyy) — sama dgn sumber @tgltrn di query 'berjalan'
Q_TANGGAL = "/* name:pby_tanggal */ SELECT TOP 1 tgl FROM Tanggal"

_PARAM_VARS =("@periode", "@thn", "@kdloc")
_SET_LITERAL = re.compile(r"(?im)^[ \t]*set[ \t]+(@\w+)[ \t]*=[ \t]*'[^']*'[ \t]*$")
_OJ_OPEN = re.compile(r"\{\s*oj\b", re.I)
_SECTION = re.compile(r"(?m)^--[ \t]*(.+?)[ \t]*$")
_PRELUDE = "SET NOCOUNT ON;\nSET ANSI_WARNINGS OFF;\nSET ARITHABORT OFF;\n"

_cache: dict[str, tuple[float, dict[str, tuple[str, tuple[str, ...]]]]] = {}


def _section_name(comment: str) -> str:
    c = comment.lower()
    # lokasi/AO dulu: komentar seperti "Nasabah Jatuh Tempo By AO" juga
    # memuat kata 'nasabah' tapi seksinya per AO, bukan daftar nasabah
    if "lokasi" in c:
        return "lokasi"
    if re.search(r"\bao\b", c):
        return "ao"
    if "nasabah" in c:
        return "nasabah"
    return re.sub(r"[^a-z0-9]+", "_", c).strip("_") or "data"


def _parse(key: str, raw: str) -> dict[str, tuple[str, tuple[str, ...]]]:
    """-> {seksi: (sql siap eksekusi, urutan nama variabel param)}."""
    text = _OJ_OPEN.sub("", raw.replace("\r\n", "\n")).replace("}", "")
    order: list[str] = []

    def to_qmark(m: re.Match) -> str:
        var = m.group(1)
        if var.lower() not in _PARAM_VARS:
            return m.group(0)
        order.append(var.lower())
        return f"SET {var} = ?"

    text = _SET_LITERAL.sub(to_qmark, text)
    marks = list(_SECTION.finditer(text))
    if not marks:
        return {"data": (f"/* name:pby_{key}_data */\n{_PRELUDE}{text}", tuple(order))}
    header = text[: marks[0].start()]
    out: dict[str, tuple[str, tuple[str, ...]]] = {}
    for i, m in enumerate(marks):
        end = marks[i + 1].start() if i + 1 < len(marks) else len(text)
        body = text[m.end():end].strip()
        if not body:
            continue
        name = _section_name(m.group(1))
        sql = f"/* name:pby_{key}_{name} */\n{_PRELUDE}{header}\n-- {m.group(1)}\n{body}\n"
        out[name] = (sql, tuple(order))
    if not out:
        # Semua komentar tanpa isi (mis. 003 Target AO: query utama di atas,
        # sisanya baris SQL yg di-comment) -> seluruh file = 1 seksi 'data'
        return {"data": (f"/* name:pby_{key}_data */\n{_PRELUDE}{text}", tuple(order))}
    return out


def sections(key: str) -> dict[str, tuple[str, tuple[str, ...]]]:
    """Seksi query utk file `key` (cache per mtime; file diubah -> dibaca ulang)."""
    path = os.path.join(_DIR, FILES[key])
    mtime = os.path.getmtime(path)
    hit = _cache.get(key)
    if hit and hit[0] == mtime:
        return hit[1]
    with open(path, encoding="utf-8-sig", errors="replace") as fh:
        parsed = _parse(key, fh.read())
    _cache[key] = (mtime, parsed)
    return parsed


def build_params(order: tuple[str, ...], values: dict[str, str]) -> tuple[str, ...]:
    return tuple(values[v] for v in order)


def clean_rows(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Kolom char SQL Server berisi spasi ekor -> dirapikan utk tampilan."""
    return [{k: (v.strip() if isinstance(v, str) else v) for k, v in r.items()} for r in rows]


# ---------------------------------------------------------------------------
# MOCK (MOCK_MODE=1) — bentuk kolom PERSIS hasil SELECT tiap seksi.
# Deterministik dari seed supaya stabil antar request.
# ---------------------------------------------------------------------------
_M_KANTOR = [
    ("01", "KANTOR PUSAT"), ("02", "CABANG UTARA"), ("03", "CABANG SELATAN"),
    ("04", "CABANG BARAT"), ("05", "CABANG TIMUR"), ("06", "CABANG TENGAH"),
    ("07", "CABANG BOGOR"), ("08", "CABANG DEPOK"), ("09", "CABANG BEKASI"), ("10", "CABANG TANGERANG"),
]
_M_PRODUK = [("101", "MURABAHAH"), ("102", "MUSYARAKAH"), ("103", "IJARAH"), ("104", "QARDH")]
_M_AO = [("A01", "AHMAD FAUZI"), ("A02", "BUDI SANTOSO"), ("A03", "CITRA LESTARI"),
         ("A04", "DEWI RAHMA"), ("A05", "EKO PRASETYO")]
_M_AO_BY_CODE = dict(_M_AO)
_M_W = {"01": 1.0, "02": 0.7, "03": 0.5, "04": 0.62, "05": 0.45, "06": 0.38,
        "07": 0.33, "08": 0.41, "09": 0.36, "10": 0.29}


def _rnd(*seed: object) -> float:
    h = 2166136261
    for ch in "|".join(map(str, seed)):
        h = ((h ^ ord(ch)) * 16777619) & 0xFFFFFFFF
    return (h % 10_000) / 10_000


def _lp() -> list[tuple[str, str, str, str]]:
    return [(k, nk, p, np) for k, nk in _M_KANTOR for p, np in _M_PRODUK
            if not (k == "03" and p == "104")]


def _kdloc_ok(params: tuple, order_has_kdloc: bool, kdloc: str) -> bool:
    if not order_has_kdloc or not params:
        return True
    f = str(params[-1])
    return f in ("", "00") or f == kdloc


def _m_realisasi(sec: str, params: tuple) -> list[dict[str, Any]]:
    seed = params[0] if params else "berjalan"
    def row(*key: str) -> dict[str, Any]:
        r = _rnd(seed, *key)
        qn, ql = int(2 + r * 9), int(1 + _rnd(key, seed) * 14)
        return {"qty_noa": qn, "plf_noa": qn * int(18_000_000 + r * 40_000_000),
                "qty": ql, "plf": ql * int(22_000_000 + _rnd(seed, key) * 55_000_000)}
    if sec == "ao":
        return [{"kdaoh": a, "nmao": n, **row(a)} for a, n in _M_AO]
    return [{"kdloc": k, "nmkantor": nk, "kdprd": p, "nmprd": np, **row(k, p)}
            for k, nk, p, np in _lp()]


def _coll(seed: tuple, scale: float) -> dict[str, Any]:
    base = (4_000_000_000 + _rnd(*seed) * 9_000_000_000) * scale
    shares = [0.86, 0.07, 0.025, 0.02, 0.025]
    c = [round(base * s * (0.7 + _rnd(*seed, i) * 0.6), 2) for i, s in enumerate(shares)]
    os_ = sum(c)
    return {"coll1": c[0], "coll2": c[1], "coll3": c[2], "coll4": c[3], "coll5": c[4],
            "os": os_, "npf": (c[2] + c[3] + c[4]) / os_ * 100 if os_ else None}


def _m_npf(sec: str, params: tuple, has_kdloc: bool) -> list[dict[str, Any]]:
    seed = params[0] if params and len(params) > 1 else "berjalan"
    if sec == "ao":
        f = str(params[-1]) if has_kdloc and params else "00"
        scale = 1.6 if f in ("", "00") else 1.6 * _M_W.get(f, 0.5) / 5
        return [{"kdaoh": a, "nmao": n, **_coll((seed, a, f), scale)} for a, n in _M_AO]
    return [{"kdloc": k, "nmcabang": nk, "kdprd": p, "ket": np, **_coll((seed, k, p), _M_W[k])}
            for k, nk, p, np in _lp() if _kdloc_ok(params, has_kdloc, k)]


def _m_os(params: tuple) -> list[dict[str, Any]]:
    thn = str(params[0]) if params else "2025"
    out = []
    for k, nk, p, np in _lp():
        if not _kdloc_ok(params, True, k):
            continue
        base = (5_000_000_000 + _rnd(thn, k, p) * 8_000_000_000) * _M_W[k]
        row: dict[str, Any] = {"kdloc": k, "nmcabang": nk, "kdprd": p, "ket": np}
        for m in range(1, 13):
            row[f"bln{m:02d}"] = round(base * (1 + 0.012 * m + (_rnd(thn, k, p, m) - 0.5) * 0.03), 2)
        out.append(row)
    return out


def _m_os_berjalan(params: tuple) -> list[dict[str, Any]]:
    """004 — OS pokok + margin per kantor x produk, posisi berjalan.
    Pokoknya sengaja diambil dari _coll() milik NPF berjalan supaya di mock
    jumlahnya persis sama dgn angka hero (di DB asli juga sama)."""
    out = []
    for k, nk, p, np in _lp():
        if not _kdloc_ok(params, True, k):
            continue
        pokok = _coll(("berjalan", k, p), _M_W[k])["os"]
        out.append({"kdloc": k, "nmkantor": nk, "kdprd": p, "nmprd": np,
                    "osmdlc": pokok, "osmgnc": round(pokok * (0.08 + _rnd("osbm", k, p) * 0.12), 2)})
    return out


def _m_dpd(sec: str) -> list[dict[str, Any]]:
    def buckets(*key: str) -> dict[str, Any]:
        d: dict[str, Any] = {}
        for i, (q, col, n0, amt) in enumerate((
            ("Q1", "D000_030", 40, 3_500_000_000), ("Q2", "D031_090", 9, 700_000_000),
            ("Q3", "D091_180", 4, 320_000_000), ("Q4", "D181_360", 3, 260_000_000),
            ("Q5", "D361_999", 2, 210_000_000),
        )):
            r = _rnd("dpd", i, *key)
            d[q] = int(n0 * (0.4 + r))
            d[col] = round(amt * (0.4 + r), 2)
        return d
    if sec == "ao":
        return [{"kdaoh": a, "nmao": n, **buckets(a)} for a, n in _M_AO]
    return [{"kdloc": k, "nmkantor": nk, "kdprd": p, "nmprd": np, **buckets(k, p)}
            for k, nk, p, np in _lp()]


_M_NAMA = ["SITI AMINAH", "RUDI HARTONO", "NURUL HUDA", "AGUS SALIM", "LINA MARLINA",
           "HENDRA GUNAWAN", "YULIANI", "M. RIZKY", "SRI WAHYUNI", "TAUFIK HIDAYAT",
           "RATNA SARI", "BAMBANG S", "FITRIANI", "JOKO WIDODO", "INDAH PERMATA",
           "SURYADI", "MAYA ANGGRAINI", "IRFAN HAKIM", "WATI SUSANTI", "ANDI PRATAMA"]


def _m_nasabah() -> list[dict[str, Any]]:
    out = []
    lp = _lp()
    for i in range(46):
        k, _, p, _ = lp[i % len(lp)]
        r = _rnd("nsb", i)
        osm = round(15_000_000 + r * 180_000_000, 2)
        qty = 1 + int(_rnd("q", i) * 8)
        tm = round(osm * 0.03 * qty, 2)
        tg = round(tm * 0.28, 2)
        out.append({
            "nokontrak": f"{k}{p}{240000 + i * 37:07d}", "nocif": f"{k}{510000 + i * 13:07d}",
            "nama": _M_NAMA[i % len(_M_NAMA)], "kdprd": p, "kdloc": k,
            "kdaoh": _M_AO[i % len(_M_AO)][0],
            "colbaru": 1 + min(4, qty // 2), "osmdlc": osm, "osmgnc": round(osm * 0.22, 2),
            "qty": qty, "tgkmdl": tm, "tgkmgn": tg, "tgk": round(tm + tg, 2),
        })
    return out


def _m_tunggakan(sec: str) -> list[dict[str, Any]]:
    nsb = _m_nasabah()
    if sec == "nasabah":
        return nsb
    cols = ("osmdlc", "osmgnc", "tgkmdl", "tgkmgn", "tgk")
    if sec == "ao":
        # per (kdloc, AO) — sama dgn GROUP BY kdloc, kdaoh di SQL asli
        agg: dict[tuple[str, str], dict[str, Any]] = {}
        for x in nsb:
            key = (x["kdloc"], x["kdaoh"])
            a = agg.setdefault(key, {"kdloc": key[0], "kdaoh": key[1],
                                     "nmao": _M_AO_BY_CODE.get(key[1], ""), **{c: 0.0 for c in cols}})
            for c in cols:
                a[c] = round(a[c] + x[c], 2)
        return sorted(agg.values(), key=lambda r: (r["nmao"], r["kdloc"]))
    names = {(k, p): (nk, np) for k, nk, p, np in _lp()}
    agg: dict[tuple[str, str], dict[str, Any]] = {}
    for x in nsb:
        key = (x["kdloc"], x["kdprd"])
        nk, np = names[key]
        a = agg.setdefault(key, {"kdloc": key[0], "nmcabang": nk, "kdprd": key[1], "nmprd": np,
                                 **{c: 0.0 for c in cols}})
        for c in cols:
            a[c] = round(a[c] + x[c], 2)
    return [agg[k] for k in sorted(agg)]


def _m_jatuh_tempo(sec: str) -> list[dict[str, Any]]:
    """Pembiayaan JatuhTempo — kontrak aktif dgn tglexp <= tanggal sistem."""
    from datetime import date, timedelta

    today = date.today()
    lp = _lp()
    nsb = []
    for i in range(38):
        k, _, p, _ = lp[int(_rnd("jt", i) * len(lp))]
        hari = int(_rnd("jth", i) ** 2 * 420)
        exp = today - timedelta(days=hari)
        osm = round(4_000_000 + _rnd("jto", i) * 120_000_000, 2)
        nsb.append({
            "nokontrak": f"{k}{p}{180000 + i * 41:07d}", "nama": _M_NAMA[(i * 7) % len(_M_NAMA)],
            "kdprd": p, "kdloc": k, "colbaru": 1 + min(4, hari // 90),
            "osmdlc": osm, "osmgnc": round(osm * (0.05 + _rnd("jtm", i) * 0.1), 2),
            "jw": 12 * (1 + int(_rnd("jtw", i) * 3)), "kdjw": "B",
            "tglexp": exp.strftime("%d-%m-%Y"), "tgkhari": hari,
            "_ao": _M_AO[i % len(_M_AO)][0],
        })
    if sec == "nasabah":
        return [{k: v for k, v in x.items() if k != "_ao"} for x in sorted(nsb, key=lambda r: r["nokontrak"])]
    agg: dict[tuple[str, ...], dict[str, Any]] = {}
    if sec == "ao":
        for x in nsb:
            a = agg.setdefault((x["_ao"],), {"kdaoh": x["_ao"], "nmao": _M_AO_BY_CODE[x["_ao"]],
                                             "qty": 0, "osmdlc": 0.0, "osmgnc": 0.0})
            a["qty"] += 1
            a["osmdlc"] = round(a["osmdlc"] + x["osmdlc"], 2)
            a["osmgnc"] = round(a["osmgnc"] + x["osmgnc"], 2)
        return sorted(agg.values(), key=lambda r: r["nmao"])
    names = {(k, p): (nk, np) for k, nk, p, np in lp}
    for x in nsb:
        key = (x["kdloc"], x["kdprd"])
        nk, np = names[key]
        a = agg.setdefault(key, {"kdloc": key[0], "nmcabang": nk, "kdprd": key[1], "nmprd": np,
                                 "qty": 0, "osmdlc": 0.0, "osmgnc": 0.0})
        a["qty"] += 1
        a["osmdlc"] = round(a["osmdlc"] + x["osmdlc"], 2)
        a["osmgnc"] = round(a["osmgnc"] + x["osmgnc"], 2)
    return [agg[k] for k in sorted(agg)]


def _m_target_ao(params: tuple) -> list[dict[str, Any]]:
    """003 Target AO — target & realisasi tabungan/deposito/pembiayaan per AO,
    periode YYYYMM. rtab memang 0 di query asli (Cast(0 ...) as rtab)."""
    per = str(params[0]) if params else "202511"
    kd = ["01", "02", "03", "01", "04"]
    out = []
    for i, (a, n) in enumerate(_M_AO):
        tab = 20_000_000 * (1 + int(_rnd("tt", a) * 3))
        dep = 100_000_000 * (1 + int(_rnd("td", a) * 4))
        loan = 400_000_000 * (1 + int(_rnd("tl", a) * 3))
        rdep = round(dep * (0.3 + _rnd("rd", a, per) * 0.95), 2)
        rloan = round(loan * (0.35 + _rnd("rl", a, per) * 0.9), 2)
        out.append({
            "kdao": a, "nmao": n, "kdloc": kd[i % len(kd)], "stsrec": "A",
            "thn": per[:4], "bln": per[4:6],
            "tab": float(tab), "rtab": 0.0,
            "dep": float(dep), "rdep": rdep, "bdr_dep": rdep / dep * 100,
            "loan": float(loan), "rloan": rloan, "bdr_loan": rloan / loan * 100,
        })
    return sorted(out, key=lambda r: r["nmao"])


def mock_rows(name: str, params: tuple | list = ()) -> list[dict[str, Any]]:
    """name = 'pby_<key>_<seksi>' (tag di SQL)."""
    params = tuple(params)
    for key in sorted(FILES, key=len, reverse=True):
        prefix = f"pby_{key}_"
        if not name.startswith(prefix):
            continue
        sec = name[len(prefix):]
        if key.startswith("realisasi"):
            return _m_realisasi(sec, params)
        if key == "npf_berjalan":
            return _m_npf(sec, ("berjalan", *params), True)
        if key == "npf_bulan":
            return _m_npf(sec, params, True)
        if key == "os_bulan":
            return _m_os(params)
        if key == "os_berjalan":
            return _m_os_berjalan(params)
        if key == "dpd":
            return _m_dpd(sec)
        if key == "tunggakan":
            return _m_tunggakan(sec)
        if key == "jatuh_tempo":
            return _m_jatuh_tempo(sec)
        if key == "target_ao":
            return _m_target_ao(params)
    return []
