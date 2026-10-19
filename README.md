# Dashboard Bank — BE + FE

Dashboard bank dengan login. FE Vue 3 + TypeScript, BE FastAPI + MySQL (raw query parameterised).
Mode mock tersedia supaya BE bisa jalan tanpa install MySQL dulu.

```
Dashboard-Show/
  be/            BE FastAPI (app.py, db.py, queries.py, auth.py, schema.sql)
  fe/            FE Vue 3 + TS (vite)
  .env.example   contoh env BE (copy jadi .env di root)
```

---

## Cara jalanin BE (mock — tanpa MySQL)

Paling cepat buat coba. Data dari fixture di `be/queries.py`.

1. Masuk ke root project + siapkan env:

```bash
cd "D:/@MGP-development/Dashboard-Show"
cp .env.example .env
# biarkan MOCK_MODE=1 di .env
```

2. Bikin venv + install (pakai uv karena pip hilang di laptop ini):

```bash
unset PYTHONHOME
uv venv .venv --python 3.11
source .venv/Scripts/activate
uv pip install --python .venv/Scripts/python.exe -r be/requirements.txt
```

Alternatif tanpa uv:

```bash
unset PYTHONHOME
python -m venv .venv
source .venv/Scripts/activate
python -m pip install -r be/requirements.txt
```

3. Jalanin server (dari folder `be/` karena import-nya top-level):

```bash
cd be
uvicorn app:app --reload --port 8000
```

4. Cek:

- Swagger: http://localhost:8000/docs
- Health: http://localhost:8000/api/health → `{"ok": true, "mock_mode": true}`

Berhentiin: `Ctrl+C`. Balik ke root: `cd ..`.

---

## Cara jalanin BE (MySQL asli)

1. Import skema:

```bash
mysql -u root -p < be/schema.sql
```

Isi tabel `users, nasabah, rekening, transaksi, kredit` sesuai skema itu.
Password user simpan sebagai sha256 hex (64 char). Contoh bikin hash:

```bash
python -c "import hashlib; print(hashlib.sha256('admin123'.encode()).hexdigest())"
```

2. Edit `.env` di root:

```
MOCK_MODE=0
MYSQL_HOST=127.0.0.1
MYSQL_PORT=3306
MYSQL_USER=root
MYSQL_PASSWORD=isi-password-mysql-kamu
MYSQL_DATABASE=bank_dashboard
SECRET_KEY=ganti-min-32-karakter-random
CORS_ORIGIN=http://localhost:5173
```

3. Restart uvicorn (langkah 3 di atas). Cek `/api/health` → `mock_mode` harus `false`.

---

## Akun mock (MOCK_MODE=1)

| username | password | role   |
| -------- | -------- | ------ |
| admin    | admin123 | admin  |
| user     | user123  | member |

---

## Endpoint BE

Publik (tanpa login):

- `GET /api/health`
- `GET /api/dashboard/stats`
- `GET /api/dashboard/monthly-flow`
- `GET /api/dashboard/recent-transactions?limit=6`
- `POST /api/login` body: `{"username":"admin","password":"admin123"}` → balikin `token` + `user`

Khusus login (header `Authorization: Bearer <token>`):

- `GET /api/me`
- `GET /api/accounts?limit=10`
- `GET /api/dashboard/top-deposits?limit=5`

Tes cepat dari git-bash:

```bash
curl -s http://localhost:8000/api/health
curl -s -X POST http://localhost:8000/api/login -H "Content-Type: application/json" -d '{"username":"admin","password":"admin123"}'
# ganti TOKEN dengan token dari login:
curl -s http://localhost:8000/api/accounts -H "Authorization: Bearer TOKEN"
```

---

## Cara jalanin FE (singkat)

```bash
cd fe
cp .env.example .env
npm install
npm run dev
# buka http://localhost:5173
```

FE ngomong ke BE via `VITE_API_BASE_URL` (default `http://localhost:8000`).

---

## Troubleshooting

- `ModuleNotFoundError: auth/db/queries` → kamu jalanin dari root. Harus `cd be` dulu baru `uvicorn app:app`.
- `pip: command not found` / `No module named pip` → pakai jalur uv di atas, jangan `pip install` langsung.
- `(PYTHONHOME) ignored` / venv aneh → `unset PYTHONHOME` dulu sebelum bikin/aktifkan venv.
- `mock_mode` masih true padahal mau MySQL → cek `.env` ada di root (sejajar folder `be/`, bukan di dalam `be/`), lalu restart uvicorn.
- FE `Gagal memuat dashboard` → BE belum jalan di port 8000, atau `VITE_API_BASE_URL` salah. Restart `npm run dev` setelah ubah `.env`.
- `401 Token wajib/tidak valid` → login ulang, token default kedaluwarsa 12 jam (`TOKEN_EXPIRE_HOURS`).
