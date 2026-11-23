Declare @tgltrn varchar(15)
Set @tgltrn = ( SELECT SUBSTRING(tgl,5,4)+SUBSTRING(tgl,3,2) + SUBSTRING(tgl,1,2) as tgl FROM Tanggal)

-- Tunggakan Base On Lokasi dan Produk
SELECT A.kdloc,
		A.nmcabang,
		A.kdprd,
		A.nmprd,
		SUM(A.osmdlc) as osmdlc,
		SUM(A.osmgnc) as osmgnc,
		SUM(A.tgkmdl) as tgkmdl,
		SUM(A.tgkmgn) as tgkmgn,
		SUM(A.tgk) as tgk
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
		TOFLMB.kdaoh as kdaoh,
		AO.nmao as nmao,
		IsNull(AA.qty,0) as qty,
		IsNull(AA.tgkmdl,0) as tgkmdl,
		IsNull(AA.tgkmgn,0) as tgkmgn,
		IsNull(AA.tgk,0) as tgk
	FROM { Oj TOFLMB 
			INNER JOIN CABANG ON CABANG.kdloc = TOFLMB.kdloc
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd
			LEFT JOIN (
			SELECT nokontrak, COUNT(nokontrak) as qty, SUM(tagmdl - byrmdl) as tgkmdl, SUM(tagmgn - byrmgn) as tgkmgn, SUM(( tagmdl - byrmdl ) + (tagmgn - byrmgn )) AS tgk 
			FROM TOFRS 
			WHERE ( tagmdl - byrmdl ) + (tagmgn - byrmgn ) > 0 AND tgltagih <= @tgltrn 
			GROUP BY nokontrak ) AA
			ON AA.nokontrak = TOFLMB.nokontrak
			LEFT JOIN AO ON AO.kdao = TOFLMB.kdaoh }
	WHERE TOFLMB.stsrec in ('A','N') AND AA.tgk > 0
) A
GROUP BY A.kdloc,A.nmcabang, A.kdprd, A.nmprd
ORDER BY A.kdloc

-- Tunggakan Base On AO
SELECT A.kdloc,
		A.kdaoh,
		IsNull(A.nmao,'') as nmao,
		SUM(A.osmdlc) as osmdlc,
		SUM(A.osmgnc) as osmgnc,
		SUM(A.tgkmdl) as tgkmdl,
		SUM(A.tgkmgn) as tgkmgn,
		SUM(A.tgk) as tgk
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
		TOFLMB.kdaoh as kdaoh,
		AO.nmao as nmao,
		IsNull(AA.qty,0) as qty,
		IsNull(AA.tgkmdl,0) as tgkmdl,
		IsNull(AA.tgkmgn,0) as tgkmgn,
		IsNull(AA.tgk,0) as tgk
	FROM { Oj TOFLMB 
			LEFT JOIN (
			SELECT nokontrak, COUNT(nokontrak) as qty, SUM(tagmdl - byrmdl) as tgkmdl, SUM(tagmgn - byrmgn) as tgkmgn, SUM(( tagmdl - byrmdl ) + (tagmgn - byrmgn )) AS tgk 
			FROM TOFRS 
			WHERE ( tagmdl - byrmdl ) + (tagmgn - byrmgn ) > 0 AND tgltagih <= @tgltrn 
			GROUP BY nokontrak ) AA
			ON AA.nokontrak = TOFLMB.nokontrak
			LEFT JOIN AO ON AO.kdao = TOFLMB.kdaoh }
	WHERE TOFLMB.stsrec in ('A','N') AND AA.tgk > 0
) A
GROUP BY A.kdloc, A.kdaoh, A.nmao
ORDER BY A.nmao

-- Tunggakan Nasabah
SELECT TOFLMB.nokontrak as nokontrak,
	TOFLMB.nocif as nocif,
	TOFLMB.nama as nama,
	TOFLMB.kdprd as kdprd,
	TOFLMB.kdloc as kdloc,
	TOFLMB.colbaru as colbaru,
	TOFLMB.osmdlc as osmdlc,
	TOFLMB.osmgnc as osmgnc,
	IsNull(AA.qty,0) as qty,
	IsNull(AA.tgkmdl,0) as tgkmdl,
	IsNull(AA.tgkmgn,0) as tgkmgn,
	IsNull(AA.tgk,0) as tgk
FROM { Oj TOFLMB 
		LEFT JOIN (
		SELECT nokontrak, COUNT(nokontrak) as qty, SUM(tagmdl - byrmdl) as tgkmdl, SUM(tagmgn - byrmgn) as tgkmgn, SUM(( tagmdl - byrmdl ) + (tagmgn - byrmgn )) AS tgk 
		FROM TOFRS 
		WHERE ( tagmdl - byrmdl ) + (tagmgn - byrmgn ) > 0 AND tgltagih <= @tgltrn 
		GROUP BY nokontrak ) AA
		ON AA.nokontrak = TOFLMB.nokontrak
		LEFT JOIN AO ON AO.kdao = TOFLMB.kdaoh }
WHERE TOFLMB.stsrec in ('A','N') AND AA.tgk > 0
