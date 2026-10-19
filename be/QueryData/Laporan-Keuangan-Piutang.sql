Declare @yyyy varchar(15)
Declare @yyold varchar(15)
Declare @kdloc varchar(15)
Declare @kdloc1 varchar(15)
Declare @kdloc2 varchar(15)

Set @yyyy = '2024'
Set @yyold = (Cast(@yyyy as numeric) - 1)
Set @kdloc = '00'
Set @kdloc1 = (Case When @kdloc = '00' Then '01' Else @kdloc End )
Set @kdloc2 = (Case When @kdloc = '00' Then '99' Else @kdloc End )

	SELECT TBLGL.golac, 
			M_NERACA03.kodeloc as kdloc,
			M_NERACA03.thn as thn,
			M_NERACA03.bln as bln, 
			SUM(M_NERACA03.tgl11) as tgl31
	FROM { oj M_NERACA03
			INNER JOIN TBLGL ON TBLGL.nosbb = M_NERACA03.nosbb }
	WHERE ( thn = @yyold AND bln ='12'  ) 
			AND ( TBLGL.jnsgol = 'C' )
			AND ( M_NERACA03.kodeloc >= @kdloc1 AND M_NERACA03.kodeloc <= @kdloc2 )
			AND M_NERACA03.nosbb IN ( SELECT A.nosbb FROM (SELECT nosbb01 as nosbb FROM SETUPLOAN 
				UNION ALL
				SELECT nosbb03 as nosbb FROM SETUPLOAN WHERE pokpby IN ('04','05','06','07','08', '13','17')
				UNION ALL
				SELECT nosbb as nosbb FROM { OJ SETUPLOAN INNER JOIN SETUPASET ON SETUPASET.pokaset = SETUPLOAN.pokpby and SETUPASET.kdbiaya='21' }) A GROUP BY A.nosbb )
	GROUP BY TBLGL.golac, M_NERACA03.kodeloc, M_NERACA03.bln, M_NERACA03.thn


SELECT 'Piutang' as ket,
		B.*
FROM (
	SELECT M_NERACA03.kodeloc as kdloc,
			M_NERACA03.thn as thn,
			M_NERACA03.bln as bln, 
			SUM(M_NERACA03.tgl11) as tgl31
	FROM { oj M_NERACA03
			INNER JOIN TBLGL ON TBLGL.nosbb = M_NERACA03.nosbb }
	WHERE ( thn = @yyold AND bln ='12'  ) 
			AND ( TBLGL.jnsgol = 'C' )
			AND ( M_NERACA03.kodeloc >= @kdloc1 AND M_NERACA03.kodeloc <= @kdloc2 )
			AND M_NERACA03.nosbb IN ( SELECT A.nosbb FROM (SELECT nosbb01 as nosbb FROM SETUPLOAN 
				UNION ALL
				SELECT nosbb03 as nosbb FROM SETUPLOAN WHERE pokpby IN ('04','05','06','07','08', '13','17')
				UNION ALL
				SELECT nosbb as nosbb FROM { OJ SETUPLOAN INNER JOIN SETUPASET ON SETUPASET.pokaset = SETUPLOAN.pokpby and SETUPASET.kdbiaya='21' }) A GROUP BY A.nosbb )
	GROUP BY M_NERACA03.kodeloc, M_NERACA03.bln, M_NERACA03.thn

	UNION ALL	
	SELECT A.kdloc as kdloc,
			A.thn as thn,
			A.bln as bln,
			CASE 
			WHEN A.bln = '01' THEN SUM(A.tgl31)
			WHEN A.bln = '02' AND A.ket = 'Kabisat' THEN SUM(A.tgl29)
			WHEN A.bln = '02' AND A.ket = 'Bukan' THEN SUM(A.tgl28)
			WHEN A.bln = '03' THEN SUM(A.tgl31)
			WHEN A.bln = '04' THEN SUM(A.tgl30)
			WHEN A.bln = '05' THEN SUM(A.tgl31)
			WHEN A.bln = '06' THEN SUM(A.tgl30)
			WHEN A.bln = '07' THEN SUM(A.tgl31)
			WHEN A.bln = '08' THEN SUM(A.tgl31)
			WHEN A.bln = '09' THEN SUM(A.tgl30)
			WHEN A.bln = '10' THEN SUM(A.tgl31)
			WHEN A.bln = '11' THEN SUM(A.tgl30)
			WHEN A.bln = '12' THEN SUM(A.tgl31)
			ELSE 0
			END as Saldo
	FROM (
	SELECT TBLGL.golac as golac,
			M_NERACA03.nosbb as nosbb,
			M_NERACA03.kodeloc as kdloc,
			M_NERACA03.thn as thn,
			M_NERACA03.bln as bln, 
			Case When @yyyy % 400 = 0 Then 'Kabisat'
			When @yyyy % 4 = 0 AND @yyyy % 100 <> 0 Then 'Kabisat'
			Else 'Bukan' End as ket,
			SUM(M_NERACA03.tgl08) as tgl28,
			SUM(M_NERACA03.tgl09) as tgl29,
			SUM(M_NERACA03.tgl10) as tgl30,
			SUM(M_NERACA03.tgl11) as tgl31
	FROM { oj M_NERACA03
			INNER JOIN TBLGL ON TBLGL.nosbb = M_NERACA03.nosbb }
	WHERE ( thn = @yyyy ) 
			AND ( TBLGL.jnsgol = 'C' )
			AND ( M_NERACA03.kodeloc >= @kdloc1 AND M_NERACA03.kodeloc <= @kdloc2 )
			AND M_NERACA03.nosbb IN ( SELECT A.nosbb FROM (SELECT nosbb01 as nosbb FROM SETUPLOAN 
				UNION ALL
				SELECT nosbb03 as nosbb FROM SETUPLOAN WHERE pokpby IN ('04','05','06','07','08', '13','17')
				UNION ALL
				SELECT nosbb as nosbb FROM { OJ SETUPLOAN INNER JOIN SETUPASET ON SETUPASET.pokaset = SETUPLOAN.pokpby and SETUPASET.kdbiaya='21' }) A GROUP BY A.nosbb )
	GROUP BY TBLGL.golac , M_NERACA03.kodeloc , M_NERACA03.bln, M_NERACA03.thn, M_NERACA03.nosbb 
	) A
	GROUP BY A.kdloc, A.bln, A.ket, A.thn
) B
ORDER BY B.kdloc, B.thn, B.bln