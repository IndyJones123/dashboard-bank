Declare @periode varchar(15)
Declare @kdloc varchar(15)
Declare @kdloc1 varchar(15)
Declare @kdloc2 varchar(15)

Set @periode = '202503'
Set @kdloc = '00'
Set @kdloc1 = Case When @kdloc = '00' Then '01' else @kdloc End
Set @kdloc2 = Case When @kdloc = '00' Then '99' else @kdloc End

-- Base ON Lokasi dan produk
SELECT B.kdloc as kdloc,
		B.nmcabang as nmcabang,
		B.kdprd as kdprd,
		SETUPLOAN.ket as ket,
		SUM(B.coll1) as coll1, 
		SUM(B.coll2) as coll2, 
		SUM(B.coll3) as coll3, 
		SUM(B.coll4) as coll4, 
		SUM(B.coll5) as coll5,
		SUM(B.coll1) + SUM(B.coll2) + SUM(B.coll3) + SUM(B.coll4) + SUM(B.coll5) as os,
		(SUM(B.coll3) + SUM(B.coll4) + SUM(B.coll5)) /
		(SUM(B.coll1) + SUM(B.coll2) + SUM(B.coll3) + SUM(B.coll4) + SUM(B.coll5)) * 100 as npf
FROM { oj (
	SELECT A.periode as periode, 
		A.nokontrak as nokontrak, 
		A.nocif as nocif, 
		A.nama as nama, 
		A.pokpby as pokpby, 
		A.kdloc as kdloc, 
		CABANG.nama as nmcabang,
		A.kdprd as kdprd, 
		A.kdaoh as kdaoh,
		SUM(A.coll1) as coll1, 
		SUM(A.coll2) as coll2, 
		SUM(A.coll3) as coll3, 
		SUM(A.coll4) as coll4, 
		SUM(A.coll5) as coll5
	FROM { oj (
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			osmdlc as coll1,
			Cast(0 as decimal(18,2)) as coll2,
			Cast(0 as decimal(18,2)) as coll3,
			Cast(0 as decimal(18,2)) as coll4,
			Cast(0 as decimal(18,2)) as coll5
		FROM TOFLMBEOM
		WHERE periode = @periode AND STSREC in ('A','N') AND stsacc <> 'W' and colbaru = 1 AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			Cast(0 as decimal(18,2)) as coll1,
			osmdlc as coll2,
			Cast(0 as decimal(18,2)) as coll3,
			Cast(0 as decimal(18,2)) as coll4,
			Cast(0 as decimal(18,2)) as coll5
		FROM TOFLMBEOM
		WHERE periode = @periode AND STSREC in ('A','N') AND stsacc <> 'W' and colbaru = 2 AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			Cast(0 as decimal(18,2)) as coll1,
			Cast(0 as decimal(18,2)) as coll2,
			osmdlc as coll3,
			Cast(0 as decimal(18,2)) as coll4,
			Cast(0 as decimal(18,2)) as coll5
		FROM TOFLMBEOM
		WHERE periode = @periode AND STSREC in ('A','N') AND stsacc <> 'W' and colbaru = 3 AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			Cast(0 as decimal(18,2)) as coll1,
			Cast(0 as decimal(18,2)) as coll2,
			Cast(0 as decimal(18,2)) as coll3,
			osmdlc as coll4,
			Cast(0 as decimal(18,2)) as coll5
		FROM TOFLMBEOM
		WHERE periode = @periode AND STSREC in ('A','N') AND stsacc <> 'W' and colbaru = 4 AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			Cast(0 as decimal(18,2)) as coll1,
			Cast(0 as decimal(18,2)) as coll2,
			Cast(0 as decimal(18,2)) as coll3,
			Cast(0 as decimal(18,2)) as coll4,
			osmdlc as coll5
		FROM TOFLMBEOM
		WHERE periode = @periode AND STSREC in ('A','N') AND stsacc <> 'W' and colbaru = 5 AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
	) A	
	INNER JOIN CABANG ON A.kdloc = CABANG.kdloc }
	GROUP BY A.periode, A.nokontrak, A.nocif, A.nama, A.pokpby, A.kdloc, CABANG.nama, A.kdprd, A.kdaoh
) B
INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = B.kdprd }
GROUP BY B.kdloc, B.nmcabang,  B.kdprd, SETUPLOAN.ket
ORDER BY B.kdloc, B.kdprd

-- Base On AO Handle
SELECT B.kdaoh as kdaoh,
		AO.nmao as nmao,
		SUM(B.coll1) as coll1, 
		SUM(B.coll2) as coll2, 
		SUM(B.coll3) as coll3, 
		SUM(B.coll4) as coll4, 
		SUM(B.coll5) as coll5,
		SUM(B.coll1) + SUM(B.coll2) + SUM(B.coll3) + SUM(B.coll4) + SUM(B.coll5) as os,
		(SUM(B.coll3) + SUM(B.coll4) + SUM(B.coll5)) /
		(SUM(B.coll1) + SUM(B.coll2) + SUM(B.coll3) + SUM(B.coll4) + SUM(B.coll5)) * 100 as npf
FROM { oj (
	SELECT A.periode as periode, 
		A.nokontrak as nokontrak, 
		A.nocif as nocif, 
		A.nama as nama, 
		A.pokpby as pokpby, 
		A.kdloc as kdloc, 
		CABANG.nama as nmcabang,
		A.kdprd as kdprd, 
		A.kdaoh as kdaoh,
		SUM(A.coll1) as coll1, 
		SUM(A.coll2) as coll2, 
		SUM(A.coll3) as coll3, 
		SUM(A.coll4) as coll4, 
		SUM(A.coll5) as coll5
	FROM { oj (
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			osmdlc as coll1,
			Cast(0 as decimal(18,2)) as coll2,
			Cast(0 as decimal(18,2)) as coll3,
			Cast(0 as decimal(18,2)) as coll4,
			Cast(0 as decimal(18,2)) as coll5
		FROM TOFLMBEOM
		WHERE periode = @periode AND STSREC in ('A','N') AND stsacc <> 'W' and colbaru = 1 
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			Cast(0 as decimal(18,2)) as coll1,
			osmdlc as coll2,
			Cast(0 as decimal(18,2)) as coll3,
			Cast(0 as decimal(18,2)) as coll4,
			Cast(0 as decimal(18,2)) as coll5
		FROM TOFLMBEOM
		WHERE periode = @periode AND STSREC in ('A','N') AND stsacc <> 'W' and colbaru = 2 
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			Cast(0 as decimal(18,2)) as coll1,
			Cast(0 as decimal(18,2)) as coll2,
			osmdlc as coll3,
			Cast(0 as decimal(18,2)) as coll4,
			Cast(0 as decimal(18,2)) as coll5
		FROM TOFLMBEOM
		WHERE periode = @periode AND STSREC in ('A','N') AND stsacc <> 'W' and colbaru = 3 
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			Cast(0 as decimal(18,2)) as coll1,
			Cast(0 as decimal(18,2)) as coll2,
			Cast(0 as decimal(18,2)) as coll3,
			osmdlc as coll4,
			Cast(0 as decimal(18,2)) as coll5
		FROM TOFLMBEOM
		WHERE periode = @periode AND STSREC in ('A','N') AND stsacc <> 'W' and colbaru = 4 
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			Cast(0 as decimal(18,2)) as coll1,
			Cast(0 as decimal(18,2)) as coll2,
			Cast(0 as decimal(18,2)) as coll3,
			Cast(0 as decimal(18,2)) as coll4,
			osmdlc as coll5
		FROM TOFLMBEOM
		WHERE periode = @periode AND STSREC in ('A','N') AND stsacc <> 'W' and colbaru = 5 
	) A	
	INNER JOIN CABANG ON A.kdloc = CABANG.kdloc }
	GROUP BY A.periode, A.nokontrak, A.nocif, A.nama, A.pokpby, A.kdloc, CABANG.nama, A.kdprd, A.kdaoh
) B
INNER JOIN AO ON AO.kdao = B.kdaoh }
GROUP BY B.kdaoh, AO.nmao
ORDER BY AO.nmao