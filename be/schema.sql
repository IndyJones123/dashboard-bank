-- Skema contoh bila ingin beralih dari mock ke MySQL asli.
-- Jalankan file ini di MySQL, lalu set MOCK_MODE=0 di .env

CREATE DATABASE IF NOT EXISTS bank_dashboard CHARACTER SET utf8mb4;
USE bank_dashboard;

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(50) UNIQUE NOT NULL,
  password_hash CHAR(64) NOT NULL,          -- sha256 hex
  full_name VARCHAR(100) NOT NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'member'
);

CREATE TABLE IF NOT EXISTS nasabah (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nama VARCHAR(100) NOT NULL,
  kota VARCHAR(50) NOT NULL
);

CREATE TABLE IF NOT EXISTS rekening (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nasabah_id INT NOT NULL,
  no_rekening VARCHAR(20) UNIQUE NOT NULL,
  jenis VARCHAR(30) NOT NULL,
  saldo BIGINT NOT NULL DEFAULT 0,
  dibuka_pada DATE NOT NULL,
  FOREIGN KEY (nasabah_id) REFERENCES nasabah(id)
);

CREATE TABLE IF NOT EXISTS transaksi (
  id INT AUTO_INCREMENT PRIMARY KEY,
  rekening_id INT NOT NULL,
  tanggal DATE NOT NULL,
  jenis VARCHAR(10) NOT NULL,               -- SETOR | TARIK
  nominal BIGINT NOT NULL,
  berita VARCHAR(200) DEFAULT '',
  FOREIGN KEY (rekening_id) REFERENCES rekening(id)
);

CREATE TABLE IF NOT EXISTS kredit (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nasabah_id INT NOT NULL,
  sisa_pokok BIGINT NOT NULL DEFAULT 0,
  status VARCHAR(20) NOT NULL DEFAULT 'berjalan',
  FOREIGN KEY (nasabah_id) REFERENCES nasabah(id)
);

-- Tabel GL untuk Query1-Aset.sql (port SQL Server -> MySQL).
-- M_NERACA03: saldo harian per rekening (tgl08..tgl11 = saldo tgl 28..31).
--   thn/bln CHAR agar cocok dengan filter @yyyy/@yyold ('2023'/'12').
-- TBLGL: master akun (jnsgol='C' = neraca, golac='1' = aset, stsac='S' = laba rugi).
CREATE TABLE IF NOT EXISTS TBLGL (
  nosbb VARCHAR(20) PRIMARY KEY,
  jnsgol VARCHAR(5) NOT NULL DEFAULT '',
  golac VARCHAR(5) NOT NULL DEFAULT '',
  stsac VARCHAR(5) NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS M_NERACA03 (
  id INT AUTO_INCREMENT PRIMARY KEY,
  nosbb VARCHAR(20) NOT NULL,
  kodeloc VARCHAR(5) NOT NULL DEFAULT '01',
  thn CHAR(4) NOT NULL,
  bln CHAR(2) NOT NULL,
  tgl08 DECIMAL(20,2) NOT NULL DEFAULT 0,
  tgl09 DECIMAL(20,2) NOT NULL DEFAULT 0,
  tgl10 DECIMAL(20,2) NOT NULL DEFAULT 0,
  tgl11 DECIMAL(20,2) NOT NULL DEFAULT 0,
  KEY idx_neraca (thn, bln, kodeloc),
  FOREIGN KEY (nosbb) REFERENCES TBLGL(nosbb)
);
