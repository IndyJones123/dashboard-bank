Declare @tgltrn varchar(15)
Set @tgltrn = ( SELECT SUBSTRING(tgl,5,4)+SUBSTRING(tgl,3,2) + SUBSTRING(tgl,1,2) as tgl FROM Tanggal)


-- Nasabah Jatuh Tempo By Lokasi dan produk
SELECT A.kdloc,
		A.nmcabang,
		A.kdprd,
		A.nmprd,
		COUNT(A.kdprd) as qty,
		SUM(A.osmdlc) as osmdlc,
		SUM(A.osmgnc) as osmgnc
FROM (
SELECT TOFLMB.nokontrak as nokontrak,
	TOFLMB.nocif as nocif,
	TOFLMB.nama as nama,
	TOFLMB.kdprd as kdprd,
	SETUPLOAN.ket as nmprd,
	TOFLMB.kdloc as kdloc,
	CABANG.nama AS nmcabang,
	TOFLMB.pokpby as pokpby,
	TOFLMB.colbaru as colbaru,
	TOFLMB.mdlawal as mdlawal,
	TOFLMB.mgnawal as mgnawal,
	TOFLMB.osmdlc as osmdlc,
	TOFLMB.osmgnc as osmgnc,
	TOFLMB.jw as jw,
	TOFLMB.kdjw as kdjw,
	TOFLMB.tgleff as tgleff,
	TOFLMB.tglexp as tglexp,
	Case When ISDATE(TOFLMB.tglexp) = 1 Then DATEDIFF(day, TOFLMB.tglexp, @tgltrn) End as tgkhari,
	TOFLMB.kdaoh as kdaoh,
	AO.nmao as nmao
FROM { Oj TOFLMB 
		LEFT JOIN AO ON AO.kdao = TOFLMB.kdaoh 
		INNER JOIN CABANG ON CABANG.kdloc = TOFLMB.kdloc
		INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd }
WHERE TOFLMB.stsrec in ('A','N') AND ISDATE(TOFLMB.tglexp) = 1 AND TOFLMB.tglexp <= @tgltrn
) A	
GROUP BY A.kdloc, A.nmcabang, A.kdprd, A.nmprd
ORDER BY A.kdloc, A.kdprd

-- Nasabah Jatuh Tempo By AO
SELECT A.kdaoh as kdaoh,
		IsNull(A.nmao,'') as nmao,
		COUNT(A.kdaoh) as qty,
		SUM(A.osmdlc) as osmdlc,
		SUM(A.osmgnc) as osmgnc
FROM (
SELECT TOFLMB.nokontrak as nokontrak,
	TOFLMB.nocif as nocif,
	TOFLMB.nama as nama,
	TOFLMB.kdprd as kdprd,
	TOFLMB.kdloc as kdloc,
	TOFLMB.pokpby as pokpby,
	TOFLMB.colbaru as colbaru,
	TOFLMB.mdlawal as mdlawal,
	TOFLMB.mgnawal as mgnawal,
	TOFLMB.osmdlc as osmdlc,
	TOFLMB.osmgnc as osmgnc,
	TOFLMB.jw as jw,
	TOFLMB.kdjw as kdjw,
	TOFLMB.tgleff as tgleff,
	TOFLMB.tglexp as tglexp,
	Case When ISDATE(TOFLMB.tglexp) = 1 Then DATEDIFF(day, TOFLMB.tglexp, @tgltrn) End as tgkhari,
	TOFLMB.kdaoh as kdaoh,
	AO.nmao as nmao
FROM { Oj TOFLMB LEFT JOIN AO ON AO.kdao = TOFLMB.kdaoh }
WHERE TOFLMB.stsrec in ('A','N') AND ISDATE(TOFLMB.tglexp) = 1 AND TOFLMB.tglexp <= @tgltrn
) A	
GROUP BY A.kdaoh , A.nmao 
ORDER BY A.nmao

-- Daftar Nasabah Jatuh tempo
SELECT TOFLMB.nokontrak as nokontrak,
	TOFLMB.nama as nama,
	TOFLMB.kdprd as kdprd,
	TOFLMB.kdloc as kdloc,
	TOFLMB.colbaru as colbaru,
	TOFLMB.osmdlc as osmdlc,
	TOFLMB.osmgnc as osmgnc,
	TOFLMB.jw as jw,
	TOFLMB.kdjw as kdjw,
	SUBSTRING(TOFLMB.tglexp,7,2)+'-'+SUBSTRING(TOFLMB.tglexp,5,2)+'-'+SUBSTRING(TOFLMB.tglexp,1,4) as tglexp,
	Case When ISDATE(TOFLMB.tglexp) = 1 Then DATEDIFF(day, TOFLMB.tglexp, @tgltrn) End as tgkhari
FROM TOFLMB 
WHERE TOFLMB.stsrec in ('A','N') AND ISDATE(TOFLMB.tglexp) = 1 AND TOFLMB.tglexp <= @tgltrn
ORDER BY TOFLMB.nokontrak