Declare @tgltrn varchar(15)
Set @tgltrn = ( SELECT SUBSTRING(tgl,5,4)+SUBSTRING(tgl,3,2) + SUBSTRING(tgl,1,2) as tgl FROM Tanggal)

-- Day Past Due (DPD) Base On AO
SELECT D.kdaoh, IsNull(D.nmao,'') as nmao,
		SUM(D.Q1) as Q1,
		SUM(D.D000_030) as D000_030,
		SUM(D.Q2) as Q2,
		SUM(D.D031_090) as D031_090,
		SUM(D.Q3) as Q3,
		SUM(D.D091_180) as D091_180,
		SUM(D.Q4) as Q4,
		SUM(D.D181_360) as D181_360,
		SUM(D.Q5) as Q5,
		SUM(D.D361_999) as D361_999
FROM (
SELECT C.kdaoh, C.nmao,
		CASE WHEN C.tgkhari Between 000 AND 030 THEN 1 ELSE 0 END AS Q1,
		CASE WHEN C.tgkhari Between 000 AND 030 THEN SUM(C.osmdlc) ELSE 0 END AS D000_030,
		CASE WHEN C.tgkhari Between 031 AND 090 THEN 1 ELSE 0 END AS Q2,
		CASE WHEN C.tgkhari Between 031 AND 090 THEN SUM(C.osmdlc) ELSE 0 END AS D031_090,
		CASE WHEN C.tgkhari Between 091 AND 180 THEN 1 ELSE 0 END AS Q3,
		CASE WHEN C.tgkhari Between 091 AND 180 THEN SUM(C.osmdlc) ELSE 0 END AS D091_180,
		CASE WHEN C.tgkhari Between 181 AND 360 THEN 1 ELSE 0 END AS Q4,
		CASE WHEN C.tgkhari Between 181 AND 360 THEN SUM(C.osmdlc) ELSE 0 END AS D181_360,
		CASE WHEN C.tgkhari > 360 THEN 1 ELSE 0 END AS Q5,
		CASE WHEN C.tgkhari > 360 THEN SUM(C.osmdlc) ELSE 0 END AS D361_999
FROM ( SELECT B.nokontrak,
				B.nocif,
				B.nama,
				B.osmdlc,
				B.osmgnc,
				B.kdprd,
				B.nmprd,
				B.kdloc,
				B.nmkantor,
				B.qtymdl,
				B.tgkmdl,
				B.tglmdl,
				B.tgkmdlhari,
				B.qtymgn,
				B.tgkmgn,
				B.tglmgn,
				B.tgkmgnhari,
				CASE WHEN B.tgkmdlhari > B.tgkmgnhari THEN B.tgkmdlhari ELSE B.tgkmgnhari END AS tgkhari,
				B.coll,
				B.kdaoh,
				B.kdaop,
				B.nmao
		FROM ( SELECT A.nokontrak as nokontrak,
						A.nocif as nocif,
						A.nama as nama,
						A.osmdlc as osmdlc,
						A.osmgnc as osmgnc,
						A.kdprd as kdprd,
						SETUPLOAN.ket as nmprd,
						A.kdloc as kdloc,
						CABANG.nama as nmkantor,
						CAST(SUM(A.tglmdl) as varchar) AS tglmdl,
						SUM(A.qtymdl) as qtymdl,
						CASE WHEN ISDATE(CAST(SUM(A.tglmdl) as varchar)) = 1 THEN DATEDIFF(day, CAST(SUM(A.tglmdl) as varchar), @tgltrn)
						WHEN CAST(SUM(A.tglmdl) as varchar) = 0 THEN 0 ELSE 0 
						END AS tgkmdlhari,
						SUM(A.tgkmdl) as tgkmdl,
						CAST(SUM(A.tglmgn) as varchar) AS tglmgn,
						CASE WHEN ISDATE(CAST(SUM(A.tglmgn) as varchar)) = 1 THEN DATEDIFF(day, CAST(SUM(A.tglmgn) as varchar), @tgltrn)
						WHEN CAST(SUM(A.tglmgn) as varchar) = 0 THEN 0 ELSE 0 
						END AS tgkmgnhari,
						SUM(A.qtymgn) as qtymgn,
						SUM(A.tgkmgn) as tgkmgn,
						A.coll as coll,
						A.kdaop as kdaop,
						A.kdaoh as kdaoh,
						AO.nmao as nmao
				FROM { oj (
						SELECT TOFRS.nokontrak AS nokontrak,
								TOFLMB.nocif as nocif,
								TOFLMB.nama AS nama,
								TOFLMB.colbaru as coll,
								TOFLMB.osmdlc as osmdlc,
								TOFLMB.osmgnc as osmgnc,
								TOFLMB.kdprd as kdprd,
								TOFLMB.kdloc as kdloc,
								min(TOFRS.tgltagih) as tglmdl,
								0 as tglmgn,
								COUNT( TOFRS.tagmdl - TOFRS.byrmdl ) as qtymdl,
								SUM( TOFRS.tagmdl - TOFRS.byrmdl ) as tgkmdl,
								0 AS qtymgn,
								0 AS tgkmgn,
								TOFLMB.kdaoh as kdaoh,
								TOFLMB.kdaop as kdaop
						FROM { oj TOFRS
								INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFRS.nokontrak }
						WHERE ( TOFRS.tagmdl - TOFRS.byrmdl > 0 )
								AND ( TOFRS.tgltagih <= @tgltrn )
								AND ( TOFLMB.stsacc <> 'W' )
						GROUP BY TOFRS.nokontrak, TOFRS.nokontrak ,TOFLMB.nama , TOFLMB.nocif,TOFLMB.colbaru, TOFLMB.osmdlc, TOFLMB.osmgnc, TOFLMB.kdprd, TOFLMB.kdloc, TOFLMB.kdaoh, TOFLMB.kdaop 

						UNION ALL
						SELECT TOFRS.nokontrak AS nokontrak,
								TOFLMB.nocif as nocif,
								TOFLMB.nama AS nama,
								TOFLMB.colbaru as coll,
								TOFLMB.osmdlc as osmdlc,
								TOFLMB.osmgnc as osmgnc,
								TOFLMB.kdprd as kdprd,
								TOFLMB.kdloc as kdloc,
								0 as tglmdl,
								min(TOFRS.tgltagih) as tglmgn, 
								0 as qtymdl,
								0 as tgkmdl,
								COUNT(TOFRS.tagmgn - TOFRS.byrmgn ) AS qtymgn,
								SUM(TOFRS.tagmgn - TOFRS.byrmgn ) AS tgkmgn,
								TOFLMB.kdaoh as kdaoh,
								TOFLMB.kdaop as kdaop
						FROM { oj TOFRS
								INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFRS.nokontrak }
						WHERE ( TOFRS.tagmgn - TOFRS.byrmgn > 0 )
								AND ( TOFRS.tgltagih <= @tgltrn )
								AND ( TOFLMB.stsacc <> 'W' )
						GROUP BY TOFRS.nokontrak, TOFRS.nokontrak ,TOFLMB.nama , TOFLMB.nocif,TOFLMB.colbaru, TOFLMB.osmdlc, TOFLMB.osmgnc, TOFLMB.kdprd, TOFLMB.kdloc, TOFLMB.kdaoh, TOFLMB.kdaop  
				) A
				INNER JOIN CABANG ON CABANG.kdloc = A.kdloc
				INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = A.kdprd
				LEFT JOIN AO ON AO.kdao = A.kdaoh }
				GROUP BY A.nokontrak, A.nocif, A.nama,A.coll,a.osmdlc,A.osmgnc,A.kdprd, SETUPLOAN.ket, A.kdloc, 
						CABANG.nama, A.kdaop, A.kdaoh, AO.nmao
		) B
) C
GROUP BY C.kdaoh,C.nmao, C.tgkhari
) D
GROUP BY D.kdaoh,D.nmao
ORDER BY D.nmao

-- Day Past Due (DPD) Base On Lokasi dan Produk
SELECT D.kdloc, D.nmkantor, D.kdprd, D.nmprd,
		SUM(D.Q1) as Q1,
		SUM(D.D000_030) as D000_030,
		SUM(D.Q2) as Q2,
		SUM(D.D031_090) as D031_090,
		SUM(D.Q3) as Q3,
		SUM(D.D091_180) as D091_180,
		SUM(D.Q4) as Q4,
		SUM(D.D181_360) as D181_360,
		SUM(D.Q5) as Q5,
		SUM(D.D361_999) as D361_999
FROM (
SELECT C.kdloc, C.nmkantor, C.kdprd, C.nmprd,
		CASE WHEN C.tgkhari Between 000 AND 030 THEN 1 ELSE 0 END AS Q1,
		CASE WHEN C.tgkhari Between 000 AND 030 THEN SUM(C.osmdlc) ELSE 0 END AS D000_030,
		CASE WHEN C.tgkhari Between 031 AND 090 THEN 1 ELSE 0 END AS Q2,
		CASE WHEN C.tgkhari Between 031 AND 090 THEN SUM(C.osmdlc) ELSE 0 END AS D031_090,
		CASE WHEN C.tgkhari Between 091 AND 180 THEN 1 ELSE 0 END AS Q3,
		CASE WHEN C.tgkhari Between 091 AND 180 THEN SUM(C.osmdlc) ELSE 0 END AS D091_180,
		CASE WHEN C.tgkhari Between 181 AND 360 THEN 1 ELSE 0 END AS Q4,
		CASE WHEN C.tgkhari Between 181 AND 360 THEN SUM(C.osmdlc) ELSE 0 END AS D181_360,
		CASE WHEN C.tgkhari > 360 THEN 1 ELSE 0 END AS Q5,
		CASE WHEN C.tgkhari > 360 THEN SUM(C.osmdlc) ELSE 0 END AS D361_999
FROM ( SELECT B.nokontrak,
				B.nocif,
				B.nama,
				B.osmdlc,
				B.osmgnc,
				B.kdprd,
				B.nmprd,
				B.kdloc,
				B.nmkantor,
				B.qtymdl,
				B.tgkmdl,
				B.tglmdl,
				B.tgkmdlhari,
				B.qtymgn,
				B.tgkmgn,
				B.tglmgn,
				B.tgkmgnhari,
				CASE WHEN B.tgkmdlhari > B.tgkmgnhari THEN B.tgkmdlhari ELSE B.tgkmgnhari END AS tgkhari,
				B.coll,
				B.kdaoh,
				B.kdaop,
				B.nmao
		FROM ( SELECT A.nokontrak as nokontrak,
						A.nocif as nocif,
						A.nama as nama,
						A.osmdlc as osmdlc,
						A.osmgnc as osmgnc,
						A.kdprd as kdprd,
						SETUPLOAN.ket as nmprd,
						A.kdloc as kdloc,
						CABANG.nama as nmkantor,
						CAST(SUM(A.tglmdl) as varchar) AS tglmdl,
						SUM(A.qtymdl) as qtymdl,
						CASE WHEN ISDATE(CAST(SUM(A.tglmdl) as varchar)) = 1 THEN DATEDIFF(day, CAST(SUM(A.tglmdl) as varchar), @tgltrn)
						WHEN CAST(SUM(A.tglmdl) as varchar) = 0 THEN 0 ELSE 0 
						END AS tgkmdlhari,
						SUM(A.tgkmdl) as tgkmdl,
						CAST(SUM(A.tglmgn) as varchar) AS tglmgn,
						CASE WHEN ISDATE(CAST(SUM(A.tglmgn) as varchar)) = 1 THEN DATEDIFF(day, CAST(SUM(A.tglmgn) as varchar), @tgltrn)
						WHEN CAST(SUM(A.tglmgn) as varchar) = 0 THEN 0 ELSE 0 
						END AS tgkmgnhari,
						SUM(A.qtymgn) as qtymgn,
						SUM(A.tgkmgn) as tgkmgn,
						A.coll as coll,
						A.kdaop as kdaop,
						A.kdaoh as kdaoh,
						AO.nmao as nmao
				FROM { oj (
						SELECT TOFRS.nokontrak AS nokontrak,
								TOFLMB.nocif as nocif,
								TOFLMB.nama AS nama,
								TOFLMB.colbaru as coll,
								TOFLMB.osmdlc as osmdlc,
								TOFLMB.osmgnc as osmgnc,
								TOFLMB.kdprd as kdprd,
								TOFLMB.kdloc as kdloc,
								min(TOFRS.tgltagih) as tglmdl,
								0 as tglmgn,
								COUNT( TOFRS.tagmdl - TOFRS.byrmdl ) as qtymdl,
								SUM( TOFRS.tagmdl - TOFRS.byrmdl ) as tgkmdl,
								0 AS qtymgn,
								0 AS tgkmgn,
								TOFLMB.kdaoh as kdaoh,
								TOFLMB.kdaop as kdaop
						FROM { oj TOFRS
								INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFRS.nokontrak }
						WHERE ( TOFRS.tagmdl - TOFRS.byrmdl > 0 )
								AND ( TOFRS.tgltagih <= @tgltrn )
								AND ( TOFLMB.stsacc <> 'W' )
						GROUP BY TOFRS.nokontrak, TOFRS.nokontrak ,TOFLMB.nama , TOFLMB.nocif,TOFLMB.colbaru, TOFLMB.osmdlc, TOFLMB.osmgnc, TOFLMB.kdprd, TOFLMB.kdloc, TOFLMB.kdaoh, TOFLMB.kdaop 

						UNION ALL
						SELECT TOFRS.nokontrak AS nokontrak,
								TOFLMB.nocif as nocif,
								TOFLMB.nama AS nama,
								TOFLMB.colbaru as coll,
								TOFLMB.osmdlc as osmdlc,
								TOFLMB.osmgnc as osmgnc,
								TOFLMB.kdprd as kdprd,
								TOFLMB.kdloc as kdloc,
								0 as tglmdl,
								min(TOFRS.tgltagih) as tglmgn, 
								0 as qtymdl,
								0 as tgkmdl,
								COUNT(TOFRS.tagmgn - TOFRS.byrmgn ) AS qtymgn,
								SUM(TOFRS.tagmgn - TOFRS.byrmgn ) AS tgkmgn,
								TOFLMB.kdaoh as kdaoh,
								TOFLMB.kdaop as kdaop
						FROM { oj TOFRS
								INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFRS.nokontrak }
						WHERE ( TOFRS.tagmgn - TOFRS.byrmgn > 0 )
								AND ( TOFRS.tgltagih <= @tgltrn )
								AND ( TOFLMB.stsacc <> 'W' )
						GROUP BY TOFRS.nokontrak, TOFRS.nokontrak ,TOFLMB.nama , TOFLMB.nocif,TOFLMB.colbaru, TOFLMB.osmdlc, TOFLMB.osmgnc, TOFLMB.kdprd, TOFLMB.kdloc, TOFLMB.kdaoh, TOFLMB.kdaop  
				) A
				INNER JOIN CABANG ON CABANG.kdloc = A.kdloc
				INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = A.kdprd
				LEFT JOIN AO ON AO.kdao = A.kdaoh }
				GROUP BY A.nokontrak, A.nocif, A.nama,A.coll,a.osmdlc,A.osmgnc,A.kdprd, SETUPLOAN.ket, A.kdloc, 
						CABANG.nama, A.kdaop, A.kdaoh, AO.nmao
		) B
) C
GROUP BY C.kdloc,C.nmkantor,C.kdprd,C.nmprd, C.tgkhari
) D
GROUP BY D.kdloc, D.nmkantor, D.kdprd, D.nmprd
ORDER BY D.kdloc, D.kdprd