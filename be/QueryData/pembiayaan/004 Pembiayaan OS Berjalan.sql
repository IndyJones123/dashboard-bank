Declare @thn varchar(15)
Declare @kdloc varchar(15)
Declare @kdloc1 varchar(15)
Declare @kdloc2 varchar(15)

Set @kdloc = '00'
Set @kdloc1 = Case When @kdloc = '00' Then '01' else @kdloc End
Set @kdloc2 = Case When @kdloc = '00' Then '99' else @kdloc End

-- Realisasi Bulan Berjalan Pembiayaan Berdasarkan Lokasi dan produk
SELECT A.kdloc, A.nmkantor, A.kdprd, A.nmprd,
		SUM(A.osmdlc) as osmdlc,
		SUM(A.osmgnc) as osmgnc
FROM (
SELECT TOFLMB.nokontrak,
		TOFLMB.nama,
		TOFLMB.kdprd as kdprd,
		SETUPLOAN.ket as nmprd,
		TOFLMB.kdloc as kdloc,
		CABANG.nama as nmkantor,
		TOFLMB.pokpby,
		TOFLMB.mdlawal,
		TOFLMB.mgnawal,
		TOFLMB.osmdlc as osmdlc,
		TOFLMB.osmgnc as osmgnc,
		TOFLMB.jw,
		TOFLMB.kdjw,
		TOFLMB.tgleff,
		TOFLMB.tglexp,
		TOFLMB.tgllunas,
		TOFLMB.stsrec,
		TOFLMB.kdaoh as kdaoh,
		AO.nmao as nmao
FROM { oj TOFLMB 
		INNER JOIN CABANG ON CABANG.kdloc = TOFLMB.kdloc
		INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd
		LEFT JOIN AO ON AO.kdao = TOFLMB.kdaoh }
WHERE TOFLMB.stsrec in ('A','N') 
			AND TOFLMB.stsacc <> 'W' 
			AND TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2

) A
GROUP BY A.kdloc, A.nmkantor, A.kdprd, A.nmprd
ORDER BY A.kdloc, A.kdprd

