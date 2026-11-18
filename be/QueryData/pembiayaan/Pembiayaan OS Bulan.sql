Declare @thn varchar(15)
Declare @kdloc varchar(15)
Declare @kdloc1 varchar(15)
Declare @kdloc2 varchar(15)

Set @thn = '2025'
Set @kdloc = '00'
Set @kdloc1 = Case When @kdloc = '00' Then '01' else @kdloc End
Set @kdloc2 = Case When @kdloc = '00' Then '99' else @kdloc End

-- Base ON Lokasi dan produk
SELECT B.kdloc as kdloc,
		B.nmcabang as nmcabang,
		B.kdprd as kdprd,
		SETUPLOAN.ket as ket,
		SUM(B.bln01) as bln01,
		SUM(B.bln02) as bln02,
		SUM(B.bln03) as bln03,
		SUM(B.bln04) as bln04,
		SUM(B.bln05) as bln05,
		SUM(B.bln06) as bln06,
		SUM(B.bln07) as bln07,
		SUM(B.bln08) as bln08,
		SUM(B.bln09) as bln09,
		SUM(B.bln10) as bln10,
		SUM(B.bln11) as bln11,
		SUM(B.bln12) as bln12
FROM { oj (
	SELECT A.nokontrak as nokontrak, 
		A.nocif as nocif, 
		A.nama as nama, 
		A.pokpby as pokpby, 
		A.kdloc as kdloc, 
		CABANG.nama as nmcabang,
		A.kdprd as kdprd, 
		A.kdaoh as kdaoh,
		SUM(A.bln01) as bln01,
		SUM(A.bln02) as bln02,
		SUM(A.bln03) as bln03,
		SUM(A.bln04) as bln04,
		SUM(A.bln05) as bln05,
		SUM(A.bln06) as bln06,
		SUM(A.bln07) as bln07,
		SUM(A.bln08) as bln08,
		SUM(A.bln09) as bln09,
		SUM(A.bln10) as bln10,
		SUM(A.bln11) as bln11,
		SUM(A.bln12) as bln12
	FROM { oj (
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			osmdlc as bln01,
			CAST(0 as decimal(18,2)) as bln02,
			CAST(0 as decimal(18,2)) as bln03,
			CAST(0 as decimal(18,2)) as bln04,
			CAST(0 as decimal(18,2)) as bln05,
			CAST(0 as decimal(18,2)) as bln06,
			CAST(0 as decimal(18,2)) as bln07,
			CAST(0 as decimal(18,2)) as bln08,
			CAST(0 as decimal(18,2)) as bln09,
			CAST(0 as decimal(18,2)) as bln10,
			CAST(0 as decimal(18,2)) as bln11,
			CAST(0 as decimal(18,2)) as bln12
		FROM TOFLMBEOM
		WHERE periode = @thn + '01'
			AND STSREC in ('A','N') 
			AND stsacc <> 'W' 
			AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			CAST(0 as decimal(18,2)) as bln01,
			osmdlc as bln02,
			CAST(0 as decimal(18,2)) as bln03,
			CAST(0 as decimal(18,2)) as bln04,
			CAST(0 as decimal(18,2)) as bln05,
			CAST(0 as decimal(18,2)) as bln06,
			CAST(0 as decimal(18,2)) as bln07,
			CAST(0 as decimal(18,2)) as bln08,
			CAST(0 as decimal(18,2)) as bln09,
			CAST(0 as decimal(18,2)) as bln10,
			CAST(0 as decimal(18,2)) as bln11,
			CAST(0 as decimal(18,2)) as bln12
		FROM TOFLMBEOM
		WHERE periode = @thn + '02'
			AND STSREC in ('A','N') 
			AND stsacc <> 'W' 
			AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			CAST(0 as decimal(18,2)) as bln01,
			CAST(0 as decimal(18,2)) as bln02,
			osmdlc as bln03,
			CAST(0 as decimal(18,2)) as bln04,
			CAST(0 as decimal(18,2)) as bln05,
			CAST(0 as decimal(18,2)) as bln06,
			CAST(0 as decimal(18,2)) as bln07,
			CAST(0 as decimal(18,2)) as bln08,
			CAST(0 as decimal(18,2)) as bln09,
			CAST(0 as decimal(18,2)) as bln10,
			CAST(0 as decimal(18,2)) as bln11,
			CAST(0 as decimal(18,2)) as bln12
		FROM TOFLMBEOM
		WHERE periode = @thn + '03'
			AND STSREC in ('A','N') 
			AND stsacc <> 'W' 
			AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			CAST(0 as decimal(18,2)) as bln01,
			CAST(0 as decimal(18,2)) as bln02,
			CAST(0 as decimal(18,2)) as bln03,
			osmdlc as bln04,
			CAST(0 as decimal(18,2)) as bln05,
			CAST(0 as decimal(18,2)) as bln06,
			CAST(0 as decimal(18,2)) as bln07,
			CAST(0 as decimal(18,2)) as bln08,
			CAST(0 as decimal(18,2)) as bln09,
			CAST(0 as decimal(18,2)) as bln10,
			CAST(0 as decimal(18,2)) as bln11,
			CAST(0 as decimal(18,2)) as bln12
		FROM TOFLMBEOM
		WHERE periode = @thn + '04'
			AND STSREC in ('A','N') 
			AND stsacc <> 'W' 
			AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			CAST(0 as decimal(18,2)) as bln01,
			CAST(0 as decimal(18,2)) as bln02,
			CAST(0 as decimal(18,2)) as bln03,
			CAST(0 as decimal(18,2)) as bln04,
			osmdlc as bln05,
			CAST(0 as decimal(18,2)) as bln06,
			CAST(0 as decimal(18,2)) as bln07,
			CAST(0 as decimal(18,2)) as bln08,
			CAST(0 as decimal(18,2)) as bln09,
			CAST(0 as decimal(18,2)) as bln10,
			CAST(0 as decimal(18,2)) as bln11,
			CAST(0 as decimal(18,2)) as bln12
		FROM TOFLMBEOM
		WHERE periode = @thn + '05'
			AND STSREC in ('A','N') 
			AND stsacc <> 'W' 
			AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			CAST(0 as decimal(18,2)) as bln01,
			CAST(0 as decimal(18,2)) as bln02,
			CAST(0 as decimal(18,2)) as bln03,
			CAST(0 as decimal(18,2)) as bln04,
			CAST(0 as decimal(18,2)) as bln05,
			osmdlc as bln06,
			CAST(0 as decimal(18,2)) as bln07,
			CAST(0 as decimal(18,2)) as bln08,
			CAST(0 as decimal(18,2)) as bln09,
			CAST(0 as decimal(18,2)) as bln10,
			CAST(0 as decimal(18,2)) as bln11,
			CAST(0 as decimal(18,2)) as bln12
		FROM TOFLMBEOM
		WHERE periode = @thn + '06'
			AND STSREC in ('A','N') 
			AND stsacc <> 'W' 
			AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			CAST(0 as decimal(18,2)) as bln01,
			CAST(0 as decimal(18,2)) as bln02,
			CAST(0 as decimal(18,2)) as bln03,
			CAST(0 as decimal(18,2)) as bln04,
			CAST(0 as decimal(18,2)) as bln05,
			CAST(0 as decimal(18,2)) as bln06,
			osmdlc as bln07,
			CAST(0 as decimal(18,2)) as bln08,
			CAST(0 as decimal(18,2)) as bln09,
			CAST(0 as decimal(18,2)) as bln10,
			CAST(0 as decimal(18,2)) as bln11,
			CAST(0 as decimal(18,2)) as bln12
		FROM TOFLMBEOM
		WHERE periode = @thn + '07'
			AND STSREC in ('A','N') 
			AND stsacc <> 'W' 
			AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			CAST(0 as decimal(18,2)) as bln01,
			CAST(0 as decimal(18,2)) as bln02,
			CAST(0 as decimal(18,2)) as bln03,
			CAST(0 as decimal(18,2)) as bln04,
			CAST(0 as decimal(18,2)) as bln05,
			CAST(0 as decimal(18,2)) as bln06,
			CAST(0 as decimal(18,2)) as bln07,
			osmdlc as bln08,
			CAST(0 as decimal(18,2)) as bln09,
			CAST(0 as decimal(18,2)) as bln10,
			CAST(0 as decimal(18,2)) as bln11,
			CAST(0 as decimal(18,2)) as bln12
		FROM TOFLMBEOM
		WHERE periode = @thn + '08'
			AND STSREC in ('A','N') 
			AND stsacc <> 'W' 
			AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			CAST(0 as decimal(18,2)) as bln01,
			CAST(0 as decimal(18,2)) as bln02,
			CAST(0 as decimal(18,2)) as bln03,
			CAST(0 as decimal(18,2)) as bln04,
			CAST(0 as decimal(18,2)) as bln05,
			CAST(0 as decimal(18,2)) as bln06,
			CAST(0 as decimal(18,2)) as bln07,
			CAST(0 as decimal(18,2)) as bln08,
			osmdlc as bln09,
			CAST(0 as decimal(18,2)) as bln10,
			CAST(0 as decimal(18,2)) as bln11,
			CAST(0 as decimal(18,2)) as bln12
		FROM TOFLMBEOM
		WHERE periode = @thn + '09'
			AND STSREC in ('A','N') 
			AND stsacc <> 'W' 
			AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			CAST(0 as decimal(18,2)) as bln01,
			CAST(0 as decimal(18,2)) as bln02,
			CAST(0 as decimal(18,2)) as bln03,
			CAST(0 as decimal(18,2)) as bln04,
			CAST(0 as decimal(18,2)) as bln05,
			CAST(0 as decimal(18,2)) as bln06,
			CAST(0 as decimal(18,2)) as bln07,
			CAST(0 as decimal(18,2)) as bln08,
			CAST(0 as decimal(18,2)) as bln09,
			osmdlc as bln10,
			CAST(0 as decimal(18,2)) as bln11,
			CAST(0 as decimal(18,2)) as bln12
		FROM TOFLMBEOM
		WHERE periode = @thn + '10'
			AND STSREC in ('A','N') 
			AND stsacc <> 'W' 
			AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			CAST(0 as decimal(18,2)) as bln01,
			CAST(0 as decimal(18,2)) as bln02,
			CAST(0 as decimal(18,2)) as bln03,
			CAST(0 as decimal(18,2)) as bln04,
			CAST(0 as decimal(18,2)) as bln05,
			CAST(0 as decimal(18,2)) as bln06,
			CAST(0 as decimal(18,2)) as bln07,
			CAST(0 as decimal(18,2)) as bln08,
			CAST(0 as decimal(18,2)) as bln09,
			CAST(0 as decimal(18,2)) as bln10,
			osmdlc as bln11,
			CAST(0 as decimal(18,2)) as bln12
		FROM TOFLMBEOM
		WHERE periode = @thn + '11'
			AND STSREC in ('A','N') 
			AND stsacc <> 'W' 
			AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		UNION ALL
		SELECT periode as periode, colbaru as colbaru,  nokontrak as nokontrak, nocif as nocif, nama as nama, pokpby as pokpby, kdloc as kdloc, kdprd as kdprd, osmdlc as osmdlc, osmgnc as osmgnc,kdaoh as kdaoh,
			CAST(0 as decimal(18,2)) as bln01,
			CAST(0 as decimal(18,2)) as bln02,
			CAST(0 as decimal(18,2)) as bln03,
			CAST(0 as decimal(18,2)) as bln04,
			CAST(0 as decimal(18,2)) as bln05,
			CAST(0 as decimal(18,2)) as bln06,
			CAST(0 as decimal(18,2)) as bln07,
			CAST(0 as decimal(18,2)) as bln08,
			CAST(0 as decimal(18,2)) as bln09,
			CAST(0 as decimal(18,2)) as bln10,
			CAST(0 as decimal(18,2)) as bln11,
			osmdlc as bln12
		FROM TOFLMBEOM
		WHERE periode = @thn + '12'
			AND STSREC in ('A','N') 
			AND stsacc <> 'W' 
			AND kdloc >= @kdloc1 AND kdloc <= @kdloc2
		) A	
	INNER JOIN CABANG ON A.kdloc = CABANG.kdloc }
	GROUP BY A.nokontrak, A.nocif, A.nama, A.pokpby, A.kdloc, CABANG.nama, A.kdprd, A.kdaoh
) B
INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = B.kdprd }
GROUP BY B.kdloc, B.nmcabang,  B.kdprd, SETUPLOAN.ket
ORDER BY B.kdloc, B.kdprd

