-- =============================================================================
-- MIGRATIONS — aplikasi idempoten dari app.py::_ensure_theme_table()
-- (lazy: dijalankan saat pertama dipakai; boot TIDAK pernah menunggu DB).
-- Aturan: setiap batch wajib idempoten (guard IF OBJECT_ID ... IS NULL)
-- supaya aman diulang tiap proses.
--
-- 001: app_settings — store CMS (tema global palet fitlink).
--      kkey = nama entri: 'theme' (sval = JSON 9 hex token warna),
--      'bank_name' (sval = teks nama bank), 'bank_logo' dan 'bank_favicon'
--      (sval = data URL base64, kosong = gambar bawaan).
-- =============================================================================
IF OBJECT_ID(N'dbo.app_settings', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.app_settings (
    kkey NVARCHAR(64)  NOT NULL PRIMARY KEY,
    sval NVARCHAR(MAX) NOT NULL
  )
END
