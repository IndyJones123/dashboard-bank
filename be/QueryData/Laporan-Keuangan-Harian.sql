DECLARE @tglf VARCHAR(10)
DECLARE @tgl  VARCHAR(10)
DECLARE @bln  VARCHAR(10)
DECLARE @thn  VARCHAR(10)
DECLARE @kdloc  VARCHAR(10)
DECLARE @kdloc1  VARCHAR(10)
DECLARE @kdloc2	 VARCHAR(10)
DECLARE @periode VARCHAR(10)
DECLARE @tglc VARCHAR(10)

set @tglf = '20250629'
set @kdloc = '00'
set @tgl = SUBSTRING(@tglf,7,2)
set @bln = SUBSTRING(@tglf,5,2)
set @thn = SUBSTRING(@tglf,1,4)
set @periode = SUBSTRING(@tglf,1,6)
Set @kdloc1 = (Case When @kdloc = '00' Then '01' Else @kdloc End )
Set @kdloc2 = (Case When @kdloc = '00' Then '99' Else @kdloc End )
Set @tglc = ( select substring(tgl,5,4)+substring(tgl,3,2)+substring(tgl,1,2) from TANGGAL)

SELECT '01' as urut,
		'Kas' as ket,
		CASE
		WHEN '01' = @tgl THEN SUM(A.tgl01)
		WHEN '02' = @tgl THEN SUM(A.tgl02)
		WHEN '03' = @tgl THEN SUM(A.tgl03)
		WHEN '04' = @tgl THEN SUM(A.tgl04)
		WHEN '05' = @tgl THEN SUM(A.tgl05)
		WHEN '06' = @tgl THEN SUM(A.tgl06)
		WHEN '07' = @tgl THEN SUM(A.tgl07)
		WHEN '08' = @tgl THEN SUM(A.tgl08)
		WHEN '09' = @tgl THEN SUM(A.tgl09)
		WHEN '10' = @tgl THEN SUM(A.tgl10)
		WHEN '11' = @tgl THEN SUM(A.tgl11)
		WHEN '12' = @tgl THEN SUM(A.tgl12)
		WHEN '13' = @tgl THEN SUM(A.tgl13)
		WHEN '14' = @tgl THEN SUM(A.tgl14)
		WHEN '15' = @tgl THEN SUM(A.tgl15)
		WHEN '16' = @tgl THEN SUM(A.tgl16)
		WHEN '17' = @tgl THEN SUM(A.tgl17)
		WHEN '18' = @tgl THEN SUM(A.tgl18)
		WHEN '19' = @tgl THEN SUM(A.tgl19)
		WHEN '20' = @tgl THEN SUM(A.tgl20)
		WHEN '21' = @tgl THEN SUM(A.tgl21)
		WHEN '22' = @tgl THEN SUM(A.tgl22)
		WHEN '23' = @tgl THEN SUM(A.tgl23)
		WHEN '24' = @tgl THEN SUM(A.tgl24)
		WHEN '25' = @tgl THEN SUM(A.tgl25)
		WHEN '26' = @tgl THEN SUM(A.tgl26)
		WHEN '27' = @tgl THEN SUM(A.tgl27)
		WHEN '28' = @tgl THEN SUM(A.tgl28)
		WHEN '29' = @tgl THEN SUM(A.tgl29)
		WHEN '30' = @tgl THEN SUM(A.tgl30)
		WHEN '31' = @tgl THEN SUM(A.tgl31)
		ELSE 0
		END AS saldo
FROM ( select TBLGL.stsac as stsac,
			TBLGL.nobb as nobb,
			TBLGL.nosbb as nosbb,
			TBLGL.nmsbb as nmsbb,
			M_NERACA01.tgl01 as tgl01,
			M_NERACA01.tgl02 as tgl02,
			M_NERACA01.tgl03 as tgl03,
			M_NERACA01.tgl04 as tgl04,
			M_NERACA01.tgl05 as tgl05,
			M_NERACA01.tgl06 as tgl06,
			M_NERACA01.tgl07 as tgl07,
			M_NERACA01.tgl08 as tgl08,
			M_NERACA01.tgl09 as tgl09,
			M_NERACA01.tgl10 as tgl10,
			0 as tgl11,
			0 as tgl12,
			0 as tgl13,
			0 as tgl14,
			0 as tgl15,
			0 as tgl16,
			0 as tgl17,
			0 as tgl18,
			0 as tgl19,
			0 as tgl20,
			0 as tgl21,
			0 as tgl22,
			0 as tgl23,
			0 as tgl24,
			0 as tgl25,
			0 as tgl26,
			0 as tgl27,
			0 as tgl28,
			0 as tgl29,
			0 as tgl30,
			0 as tgl31
	from { oj TBLGL 
			LEFT JOIN M_NERACA01 ON TBLGL.nosbb = M_NERACA01.nosbb }
	where	M_NERACA01.thn = @thn AND M_NERACA01.bln = @bln
			AND ( M_NERACA01.kodeloc >= @kdloc1 AND M_NERACA01.kodeloc <= @kdloc2 )
	UNION ALL
	select TBLGL.stsac as stsac,
			TBLGL.nobb as nobb,
			TBLGL.nosbb as nosbb,
			TBLGL.nmsbb as nmsbb,
			0 as tgl01,
			0 as tgl02,
			0 as tgl03,
			0 as tgl04,
			0 as tgl05,
			0 as tgl06,
			0 as tgl07,
			0 as tgl08,
			0 as tgl09,
			0 as tgl10,
			M_NERACA02.tgl01 as tgl11,
			M_NERACA02.tgl02 as tgl12,
			M_NERACA02.tgl03 as tgl13,
			M_NERACA02.tgl04 as tgl14,
			M_NERACA02.tgl05 as tgl15,
			M_NERACA02.tgl06 as tgl16,
			M_NERACA02.tgl07 as tgl17,
			M_NERACA02.tgl08 as tgl18,
			M_NERACA02.tgl09 as tgl19,
			M_NERACA02.tgl10 as tgl20,
			0 as tgl21,
			0 as tgl22,
			0 as tgl23,
			0 as tgl24,
			0 as tgl25,
			0 as tgl26,
			0 as tgl27,
			0 as tgl28,
			0 as tgl29,
			0 as tgl30,
			0 as tgl31
	from { oj TBLGL 
			LEFT JOIN M_NERACA02 ON TBLGL.nosbb = M_NERACA02.nosbb }
	WHERE ( M_NERACA02.thn = @thn AND M_NERACA02.bln = @bln )
			AND ( M_NERACA02.kodeloc >= @kdloc1 AND M_NERACA02.kodeloc <= @kdloc2 )
	UNION ALL
	select TBLGL.stsac as stsac,
			TBLGL.nobb as nobb,
			TBLGL.nosbb as nosbb,
			TBLGL.nmsbb as nmsbb,
			0 as tgl01,
			0 as tgl02,
			0 as tgl03,
			0 as tgl04,
			0 as tgl05,
			0 as tgl06,
			0 as tgl07,
			0 as tgl08,
			0 as tgl09,
			0 as tgl10,
			0 as tgl11,
			0 as tgl12,
			0 as tgl13,
			0 as tgl14,
			0 as tgl15,
			0 as tgl16,
			0 as tgl17,
			0 as tgl18,
			0 as tgl19,
			0 as tgl20,
			M_NERACA03.tgl01 as tgl21,
			M_NERACA03.tgl02 as tgl22,
			M_NERACA03.tgl03 as tgl23,
			M_NERACA03.tgl04 as tgl24,
			M_NERACA03.tgl05 as tgl25,
			M_NERACA03.tgl06 as tgl26,
			M_NERACA03.tgl07 as tgl27,
			M_NERACA03.tgl08 as tgl28,
			M_NERACA03.tgl09 as tgl29,
			M_NERACA03.tgl10 as tgl30,
			M_NERACA03.tgl11 as tgl31
	from { oj TBLGL 
		LEFT JOIN M_NERACA03 ON TBLGL.nosbb = M_NERACA03.nosbb	}
	Where ( M_NERACA03.thn = @thn AND M_NERACA03.bln = @bln )
			AND ( M_NERACA03.kodeloc >= @kdloc1 AND M_NERACA03.kodeloc <= @kdloc2 )
	) A
WHERE A.stsac ='K'

UNION ALL
SELECT '02' as urut,
		'Bank' as ket,
		CASE
		WHEN '01' = @tgl THEN SUM(A.tgl01)
		WHEN '02' = @tgl THEN SUM(A.tgl02)
		WHEN '03' = @tgl THEN SUM(A.tgl03)
		WHEN '04' = @tgl THEN SUM(A.tgl04)
		WHEN '05' = @tgl THEN SUM(A.tgl05)
		WHEN '06' = @tgl THEN SUM(A.tgl06)
		WHEN '07' = @tgl THEN SUM(A.tgl07)
		WHEN '08' = @tgl THEN SUM(A.tgl08)
		WHEN '09' = @tgl THEN SUM(A.tgl09)
		WHEN '10' = @tgl THEN SUM(A.tgl10)
		WHEN '11' = @tgl THEN SUM(A.tgl11)
		WHEN '12' = @tgl THEN SUM(A.tgl12)
		WHEN '13' = @tgl THEN SUM(A.tgl13)
		WHEN '14' = @tgl THEN SUM(A.tgl14)
		WHEN '15' = @tgl THEN SUM(A.tgl15)
		WHEN '16' = @tgl THEN SUM(A.tgl16)
		WHEN '17' = @tgl THEN SUM(A.tgl17)
		WHEN '18' = @tgl THEN SUM(A.tgl18)
		WHEN '19' = @tgl THEN SUM(A.tgl19)
		WHEN '20' = @tgl THEN SUM(A.tgl20)
		WHEN '21' = @tgl THEN SUM(A.tgl21)
		WHEN '22' = @tgl THEN SUM(A.tgl22)
		WHEN '23' = @tgl THEN SUM(A.tgl23)
		WHEN '24' = @tgl THEN SUM(A.tgl24)
		WHEN '25' = @tgl THEN SUM(A.tgl25)
		WHEN '26' = @tgl THEN SUM(A.tgl26)
		WHEN '27' = @tgl THEN SUM(A.tgl27)
		WHEN '28' = @tgl THEN SUM(A.tgl28)
		WHEN '29' = @tgl THEN SUM(A.tgl29)
		WHEN '30' = @tgl THEN SUM(A.tgl30)
		WHEN '31' = @tgl THEN SUM(A.tgl31)
		ELSE 0
		END AS saldo
FROM ( select TBLGL.stsac as stsac,
			TBLGL.nobb as nobb,
			TBLGL.nosbb as nosbb,
			TBLGL.nmsbb as nmsbb,
			M_NERACA01.tgl01 as tgl01,
			M_NERACA01.tgl02 as tgl02,
			M_NERACA01.tgl03 as tgl03,
			M_NERACA01.tgl04 as tgl04,
			M_NERACA01.tgl05 as tgl05,
			M_NERACA01.tgl06 as tgl06,
			M_NERACA01.tgl07 as tgl07,
			M_NERACA01.tgl08 as tgl08,
			M_NERACA01.tgl09 as tgl09,
			M_NERACA01.tgl10 as tgl10,
			0 as tgl11,
			0 as tgl12,
			0 as tgl13,
			0 as tgl14,
			0 as tgl15,
			0 as tgl16,
			0 as tgl17,
			0 as tgl18,
			0 as tgl19,
			0 as tgl20,
			0 as tgl21,
			0 as tgl22,
			0 as tgl23,
			0 as tgl24,
			0 as tgl25,
			0 as tgl26,
			0 as tgl27,
			0 as tgl28,
			0 as tgl29,
			0 as tgl30,
			0 as tgl31
	from { oj TBLGL 
			LEFT JOIN M_NERACA01 ON TBLGL.nosbb = M_NERACA01.nosbb }
	where	M_NERACA01.thn = @thn AND M_NERACA01.bln = @bln
			AND ( M_NERACA01.kodeloc >= @kdloc1 AND M_NERACA01.kodeloc <= @kdloc2 )
	UNION ALL
	select TBLGL.stsac as stsac,
			TBLGL.nobb as nobb,
			TBLGL.nosbb as nosbb,
			TBLGL.nmsbb as nmsbb,
			0 as tgl01,
			0 as tgl02,
			0 as tgl03,
			0 as tgl04,
			0 as tgl05,
			0 as tgl06,
			0 as tgl07,
			0 as tgl08,
			0 as tgl09,
			0 as tgl10,
			M_NERACA02.tgl01 as tgl11,
			M_NERACA02.tgl02 as tgl12,
			M_NERACA02.tgl03 as tgl13,
			M_NERACA02.tgl04 as tgl14,
			M_NERACA02.tgl05 as tgl15,
			M_NERACA02.tgl06 as tgl16,
			M_NERACA02.tgl07 as tgl17,
			M_NERACA02.tgl08 as tgl18,
			M_NERACA02.tgl09 as tgl19,
			M_NERACA02.tgl10 as tgl20,
			0 as tgl21,
			0 as tgl22,
			0 as tgl23,
			0 as tgl24,
			0 as tgl25,
			0 as tgl26,
			0 as tgl27,
			0 as tgl28,
			0 as tgl29,
			0 as tgl30,
			0 as tgl31
	from { oj TBLGL 
			LEFT JOIN M_NERACA02 ON TBLGL.nosbb = M_NERACA02.nosbb }
	WHERE ( M_NERACA02.thn = @thn AND M_NERACA02.bln = @bln )
			AND ( M_NERACA02.kodeloc >= @kdloc1 AND M_NERACA02.kodeloc <= @kdloc2 )
	UNION ALL
	select TBLGL.stsac as stsac,
			TBLGL.nobb as nobb,
			TBLGL.nosbb as nosbb,
			TBLGL.nmsbb as nmsbb,
			0 as tgl01,
			0 as tgl02,
			0 as tgl03,
			0 as tgl04,
			0 as tgl05,
			0 as tgl06,
			0 as tgl07,
			0 as tgl08,
			0 as tgl09,
			0 as tgl10,
			0 as tgl11,
			0 as tgl12,
			0 as tgl13,
			0 as tgl14,
			0 as tgl15,
			0 as tgl16,
			0 as tgl17,
			0 as tgl18,
			0 as tgl19,
			0 as tgl20,
			M_NERACA03.tgl01 as tgl21,
			M_NERACA03.tgl02 as tgl22,
			M_NERACA03.tgl03 as tgl23,
			M_NERACA03.tgl04 as tgl24,
			M_NERACA03.tgl05 as tgl25,
			M_NERACA03.tgl06 as tgl26,
			M_NERACA03.tgl07 as tgl27,
			M_NERACA03.tgl08 as tgl28,
			M_NERACA03.tgl09 as tgl29,
			M_NERACA03.tgl10 as tgl30,
			M_NERACA03.tgl11 as tgl31
	from { oj TBLGL 
		LEFT JOIN M_NERACA03 ON TBLGL.nosbb = M_NERACA03.nosbb	}
	Where ( M_NERACA03.thn = @thn AND M_NERACA03.bln = @bln )
		AND ( M_NERACA03.kodeloc >= @kdloc1 AND M_NERACA03.kodeloc <= @kdloc2 )
	) A
WHERE A.stsac ='B'

UNION ALL
SELECT '03' AS urut,
		'Droping hari ini' as ket,
		SUM(TOFLMDROP.modal)  as saldo
FROM { oj TOFLMDROP
		INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFLMDROP.nokontrak}
WHERE ( TOFLMDROP.stsdrop = 'T' )
		AND (TOFLMDROP.tgldrop = @tglf)
		AND ( TOFLMB.kdloc >= @kdloc1 and TOFLMB.kdloc <= @kdloc2 )

UNION ALL
SELECT '04' as urut,
		'OS Pokok Harian/Mingguan' as ket,
		Sum(TOFLMB.osmdlc) as saldo
FROM { oj TOFLMB INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd }	
WHERE TOFLMB.stsrec in ('A','N') 
		AND ( SETUPLOAN.pokpby not in ( '12','16','18','30'))
		AND ( TOFLMB.kdjw in ('H','M') )
		AND ( TOFLMB.kdloc >= @kdloc1 and TOFLMB.kdloc <= @kdloc2 )
		AND ( TOFLMB.stsacc <> 'W')
		AND ( TOFLMB.ststrn = '*' )
UNION ALL
SELECT '05' as urut,
		'OS Pokok Bulanan' as ket,
		Sum(TOFLMB.osmdlc) as saldo
FROM { oj TOFLMB INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd }	
WHERE TOFLMB.stsrec in ('A','N') 
		AND ( SETUPLOAN.pokpby not in ( '12','16','18','30'))
		AND ( TOFLMB.kdjw ='B' )
		AND ( TOFLMB.kdloc >= @kdloc1 and TOFLMB.kdloc <= @kdloc2 )
		AND ( TOFLMB.stsacc <> 'W')
		AND ( TOFLMB.ststrn = '*' )
UNION ALL
SELECT '06' as urut,
		'Total OS Pokok' as ket,
		Sum(TOFLMB.osmdlc) as saldo
FROM { oj TOFLMB INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd }	
WHERE TOFLMB.stsrec in ('A','N') 
		AND ( SETUPLOAN.pokpby not in ( '12','16','18','30'))
		AND ( TOFLMB.kdloc >= @kdloc1 and TOFLMB.kdloc <= @kdloc2 )
		AND ( TOFLMB.stsacc <> 'W')
		AND ( TOFLMB.ststrn = '*' )

UNION ALL
SELECT CASE
		WHEN A.kode = '01' Then '07'
		WHEN A.kode = '02' Then '08'
		Else
			''
		END AS urut,
		CASE
		WHEN A.kode = '01' Then 'Angsuran dan Pelunasan Pokok Hari ini'
		WHEN A.kode = '02' Then 'Angsuran dan Pelunasan Margin Hari ini'
		Else
			''
		END AS ket,
		CASE
		WHEN A.kode = '01' Then SUM(A.angsmdl) + SUM(A.lunasmdl)
		WHEN A.kode = '02' Then SUM(A.angsmgn) + SUM(A.lunasmgn) 
		Else
			0
		END AS saldo
FROM (
	Select '01' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			SUM(H_LOANTRN.pokok) as angsmdl,
			0 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE  ( H_LOANTRN.tgltrn = @tglf )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '01A')
			AND ( TOFLMB.stsacc <> 'W' )
			AND ( SETUPLOAN.pokpby Not in ('01','02','03'))
	
	UNION ALL
	Select '02' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			SUM(H_LOANTRN.margin) as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE  ( H_LOANTRN.tgltrn = @tglf )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '01A')
			AND ( TOFLMB.stsacc <> 'W' )
			AND ( SETUPLOAN.pokpby Not in ('01','02','03'))
	
	UNION ALL
	Select '01' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			SUM(H_LOANTRN.pokok) as angsmdl,
			0 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE  ( H_LOANTRN.tgltrn = @tglf  )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '02A')
			AND ( TOFLMB.stsacc <> 'W' )
			AND ( SETUPLOAN.pokpby in ('01','02','03'))

	UNION ALL
	Select '02' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			SUM(H_LOANTRN.margin) as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE  ( H_LOANTRN.tgltrn = @tglf  )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '02A')
			AND ( TOFLMB.stsacc <> 'W' )
			AND ( SETUPLOAN.pokpby in ('01','02','03','11'))
	
	UNION ALL
	Select '01' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			SUM(H_LOANTRN.pokok) * -1 as angsmdl,
			0 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE ( H_LOANTRN.tgltrn = @tglf )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '01K')
			AND ( TOFLMB.stsacc <> 'W' )
	
	UNION ALL
	Select '02' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			SUM(H_LOANTRN.margin) * -1 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE ( H_LOANTRN.tgltrn = @tglf )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '01K')
			AND ( TOFLMB.stsacc <> 'W' )
	
	UNION ALL
	Select '01' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			0 as angsmgn,
			sum(H_LOANTRN.pokok)  as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE ( H_LOANTRN.tgltrn = @tglf )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '01L')
			AND ( TOFLMB.stsacc <> 'W' )
			AND ( H_LOANTRN.modullawan <> '9' ) 
	
	UNION ALL
	Select '02' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			0 as angsmgn,
			0 as lunasmdl,
			sum(H_LOANTRN.nominal)  as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE ( H_LOANTRN.tgltrn = @tglf )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '02L')
			AND ( TOFLMB.stsacc <> 'W' )
			AND ( H_LOANTRN.modullawan <> '9' ) 
	
	UNION ALL
	select '01' as kode,
			COUNT(cracc) as qty,
			0 as osmdlc,
			0 as osmgnc,
			SUM(TOFTRNC.pokok) as angsmdl,
			0 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	from { oj TOFTRNC
			INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFTRNC.cracc 
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd}
	WHERE ( TOFTRNC.ststrn = '5')
			AND ( TOFTRNC.jnstrnlx in ('01A','01L'))
			AND ( TOFLMB.stsacc <> 'W')
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFTRNC.tgltrn = @tglf )

	UNION ALL
	select '02' as kode,
			COUNT(cracc) as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			sum(TOFTRNC.margin) as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	from { oj TOFTRNC
			INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFTRNC.cracc 
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd}
	WHERE ( TOFTRNC.ststrn = '5')
			AND ( TOFTRNC.jnstrnlx in ('01A','01L'))
			AND ( TOFLMB.stsacc <> 'W')
			AND ( SETUPLOAN.pokpby Not in ('01','02','03'))
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFTRNC.tgltrn = @tglf )

	UNION ALL
	select '02' as kode,
			COUNT(cracc) as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			sum(TOFTRNC.nominalrp) as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	from { oj TOFTRNC
			INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFTRNC.cracc 
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd}
	WHERE ( TOFTRNC.ststrn = '5')
			AND ( TOFTRNC.jnstrnlx in ('02A','02L'))
			AND ( TOFLMB.stsacc <> 'W')
			AND ( SETUPLOAN.pokpby in ('01','02','03','11'))
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFTRNC.tgltrn = @tglf )

	UNION ALL
	select '01' as kode,
			COUNT(dracc) as qty,
			0 as osmdlc,
			0 as osmgnc,
			SUM(TOFTRNC.pokok) * - 1 as angsmdl,
			0 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	from { oj TOFTRNC
			INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFTRNC.dracc 
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd}
	WHERE ( TOFTRNC.ststrn = '5')
			AND ( TOFTRNC.jnstrnlx = '01K')
			AND ( TOFLMB.stsacc <> 'W')
			AND ( SETUPLOAN.pokpby Not in ('01','02','03'))
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFTRNC.tgltrn = @tglf )

	UNION ALL
	select '02' as kode,
			COUNT(dracc) as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			SUM(TOFTRNC.margin) * - 1 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	from { oj TOFTRNC
			INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFTRNC.dracc 
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd}
	WHERE ( TOFTRNC.ststrn = '5')
			AND ( TOFTRNC.jnstrnlx = '01K')
			AND ( TOFLMB.stsacc <> 'W')
			AND ( SETUPLOAN.pokpby Not in ('01','02','03'))
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFTRNC.tgltrn = @tglf )

	UNION ALL
	select '02' as kode,
			COUNT(dracc) as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			sum(TOFTRNC.nominalrp) as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	from { oj TOFTRNC
			INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFTRNC.dracc 
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd}
	WHERE ( TOFTRNC.ststrn = '5')
			AND ( TOFTRNC.jnstrnlx = '02A')
			AND ( TOFLMB.stsacc <> 'W')
			AND ( SETUPLOAN.pokpby in ('01','02','03','11'))
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFTRNC.tgltrn = @tglf )
	
	) A
GROUP BY A.kode

UNION ALL
SELECT CASE
		WHEN A.kode = '01' Then '09'
		WHEN A.kode = '02' Then '10'
		Else
			''
		END AS urut,
		CASE
		WHEN A.kode = '01' Then 'Angsuran dan Pelunasan Pokok Bulan ini'
		WHEN A.kode = '02' Then 'Angsuran dan Pelunasan Margin Bulan ini'
		Else
			''
		END AS ket,
		CASE
		WHEN A.kode = '01' Then SUM(A.angsmdl) + SUM(A.lunasmdl)
		WHEN A.kode = '02' Then SUM(A.angsmgn) + SUM(A.lunasmgn) 
		Else
			0
		END AS saldo
FROM (
	Select '01' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			SUM(H_LOANTRN.pokok) as angsmdl,
			0 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE  ( Left(H_LOANTRN.tgltrn,6) = @periode )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '01A')
			AND ( TOFLMB.stsacc <> 'W' )
			AND ( SETUPLOAN.pokpby Not in ('01','02','03'))
	
	UNION ALL
	Select '02' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			SUM(H_LOANTRN.margin) as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE  ( Left(H_LOANTRN.tgltrn,6) = @periode )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '01A')
			AND ( TOFLMB.stsacc <> 'W' )
			AND ( SETUPLOAN.pokpby Not in ('01','02','03'))
	
	UNION ALL
	Select '01' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			SUM(H_LOANTRN.pokok) as angsmdl,
			0 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE  ( Left(H_LOANTRN.tgltrn,6) = @periode )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '02A')
			AND ( TOFLMB.stsacc <> 'W' )
			AND ( SETUPLOAN.pokpby in ('01','02','03'))

	UNION ALL
	Select '02' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			SUM(H_LOANTRN.margin) as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE  ( Left(H_LOANTRN.tgltrn,6) = @periode )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '02A')
			AND ( TOFLMB.stsacc <> 'W' )
			AND ( SETUPLOAN.pokpby in ('01','02','03','11'))
	
	UNION ALL
	Select '01' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			SUM(H_LOANTRN.pokok) * -1 as angsmdl,
			0 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE ( H_LOANTRN.tgltrn = @tglf )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '01K')
			AND ( TOFLMB.stsacc <> 'W' )
	
	UNION ALL
	Select '02' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			SUM(H_LOANTRN.margin) * -1 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE ( Left(H_LOANTRN.tgltrn,6) = @periode )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '01K')
			AND ( TOFLMB.stsacc <> 'W' )
	
	UNION ALL
	Select '01' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			0 as angsmgn,
			sum(H_LOANTRN.pokok)  as lunasmdl,
			0 as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE ( Left(H_LOANTRN.tgltrn,6) = @periode )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '01L')
			AND ( TOFLMB.stsacc <> 'W' )
			AND ( H_LOANTRN.modullawan <> '9' ) 
	
	UNION ALL
	Select '02' AS kode,
			0 as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			0 as angsmgn,
			0 as lunasmdl,
			sum(H_LOANTRN.nominal)  as lunasmgn
	FROM { oj H_LOANTRN 
			LEFT JOIN TOFLMB ON H_LOANTRN.noacc = TOFLMB.nokontrak 
			LEFT JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.KDPRD }
	WHERE ( Left(H_LOANTRN.tgltrn,6) = @periode )
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( H_LOANTRN.ststrn ='5' )
			AND ( H_LOANTRN.jnstrnlx = '02L')
			AND ( TOFLMB.stsacc <> 'W' )
			AND ( H_LOANTRN.modullawan <> '9' ) 

	UNION ALL
	select '01' as kode,
			COUNT(cracc) as qty,
			0 as osmdlc,
			0 as osmgnc,
			SUM(TOFTRNC.pokok) as angsmdl,
			0 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	from { oj TOFTRNC
			INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFTRNC.cracc 
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd}
	WHERE ( TOFTRNC.ststrn = '5')
			AND ( TOFTRNC.jnstrnlx in ('01A','01L'))
			AND ( TOFLMB.stsacc <> 'W')
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFTRNC.tgltrn <= @tglf )

	UNION ALL
	select '02' as kode,
			COUNT(cracc) as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			sum(TOFTRNC.margin) as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	from { oj TOFTRNC
			INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFTRNC.cracc 
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd}
	WHERE ( TOFTRNC.ststrn = '5')
			AND ( TOFTRNC.jnstrnlx in ('01A','01L'))
			AND ( TOFLMB.stsacc <> 'W')
			AND ( SETUPLOAN.pokpby Not in ('01','02','03'))
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFTRNC.tgltrn <= @tglf )

	UNION ALL
	select '02' as kode,
			COUNT(cracc) as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			sum(TOFTRNC.nominalrp) as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	from { oj TOFTRNC
			INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFTRNC.cracc 
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd}
	WHERE ( TOFTRNC.ststrn = '5')
			AND ( TOFTRNC.jnstrnlx in ('02A','02L'))
			AND ( TOFLMB.stsacc <> 'W')
			AND ( SETUPLOAN.pokpby in ('01','02','03','11'))
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFTRNC.tgltrn <= @tglf )

	UNION ALL
	select '01' as kode,
			COUNT(dracc) as qty,
			0 as osmdlc,
			0 as osmgnc,
			SUM(TOFTRNC.pokok) * - 1 as angsmdl,
			0 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	from { oj TOFTRNC
			INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFTRNC.dracc 
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd}
	WHERE ( TOFTRNC.ststrn = '5')
			AND ( TOFTRNC.jnstrnlx = '01K')
			AND ( TOFLMB.stsacc <> 'W')
			AND ( SETUPLOAN.pokpby Not in ('01','02','03'))
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFTRNC.tgltrn <= @tglf )

	UNION ALL
	select '02' as kode,
			COUNT(dracc) as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			SUM(TOFTRNC.margin) * - 1 as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	from { oj TOFTRNC
			INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFTRNC.dracc 
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd}
	WHERE ( TOFTRNC.ststrn = '5')
			AND ( TOFTRNC.jnstrnlx = '01K')
			AND ( TOFLMB.stsacc <> 'W')
			AND ( SETUPLOAN.pokpby Not in ('01','02','03'))
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFTRNC.tgltrn <= @tglf )

	UNION ALL
	select '02' as kode,
			COUNT(dracc) as qty,
			0 as osmdlc,
			0 as osmgnc,
			0 as angsmdl,
			sum(TOFTRNC.nominalrp) as angsmgn,
			0 as lunasmdl,
			0 as lunasmgn
	from { oj TOFTRNC
			INNER JOIN TOFLMB ON TOFLMB.nokontrak = TOFTRNC.dracc 
			INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd}
	WHERE ( TOFTRNC.ststrn = '5')
			AND ( TOFTRNC.jnstrnlx = '02A')
			AND ( TOFLMB.stsacc <> 'W')
			AND ( SETUPLOAN.pokpby in ('01','02','03','11'))
			AND ( TOFLMB.kdloc >= @kdloc1 AND TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFTRNC.tgltrn <= @tglf )
	) A
GROUP BY A.kode

UNION ALL
SELECT '11' as urut,
		'NPL OJK' as ket,
		(SUM(A.saldo3)+SUM(A.saldo4)+SUM(A.saldo5)) as saldo 
FROM (
	SELECT TOFLMB.colbaru,
			CASE
			WHEN TOFLMB.colbaru = 1 THEN Sum(TOFLMB.osmdlc)
			ELSE 0
			END as saldo1,
			CASE
			WHEN TOFLMB.colbaru = 2 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo2,
			CASE
			WHEN TOFLMB.colbaru = 3 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo3,
			CASE
			WHEN TOFLMB.colbaru = 4 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo4,
			CASE
			WHEN TOFLMB.colbaru = 5 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo5
	FROM { oj TOFLMB INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd }	
	WHERE TOFLMB.stsrec in ('A','N') 
			AND ( SETUPLOAN.pokpby not in ( '12','16','18','30'))
			AND ( TOFLMB.kdloc >= @kdloc1 and TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFLMB.stsacc <> 'W')
			AND ( TOFLMB.ststrn = '*' )
	GROUP BY TOFLMB.colbaru 
	)A
UNION ALL
SELECT '12' as urut,
		'NPF OJK (%)' as ket,
		(SUM(A.saldo3)+SUM(A.saldo4)+SUM(A.saldo5)) / (SUM(A.saldo1)+SUM(A.saldo2)+SUM(A.saldo3)+SUM(A.saldo4)+SUM(A.saldo5)) * 100 as saldo 
FROM (
	SELECT TOFLMB.colbaru,
			CASE
			WHEN TOFLMB.colbaru = 1 THEN Sum(TOFLMB.osmdlc)
			ELSE 0
			END as saldo1,
			CASE
			WHEN TOFLMB.colbaru = 2 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo2,
			CASE
			WHEN TOFLMB.colbaru = 3 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo3,
			CASE
			WHEN TOFLMB.colbaru = 4 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo4,
			CASE
			WHEN TOFLMB.colbaru = 5 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo5
	FROM { oj TOFLMB INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd }	
	WHERE TOFLMB.stsrec in ('A','N') 
			AND ( SETUPLOAN.pokpby not in ( '12','16','18','30'))
			AND ( TOFLMB.kdloc >= @kdloc1 and TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFLMB.stsacc <> 'W')
			AND ( TOFLMB.ststrn = '*' )
	GROUP BY TOFLMB.colbaru 
	)A

UNION ALL
SELECT '13' as urut,
		'NPL Internal' as ket,
		( SUM(A.saldo3)+SUM(A.saldo4)+SUM(A.saldo5)) as saldo 
FROM (
	SELECT TOFLMB.colbaruint,
			CASE
			WHEN TOFLMB.colbaruint = 1 THEN Sum(TOFLMB.osmdlc)
			ELSE 0
			END as saldo1,
			CASE
			WHEN TOFLMB.colbaruint = 2 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo2,
			CASE
			WHEN TOFLMB.colbaruint = 3 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo3,
			CASE
			WHEN TOFLMB.colbaruint = 4 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo4,
			CASE
			WHEN TOFLMB.colbaruint = 5 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo5
	FROM { oj TOFLMB INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd }	
	WHERE TOFLMB.stsrec in ('A','N') 
			AND ( SETUPLOAN.pokpby not in ( '12','16','18','30'))
			AND ( TOFLMB.kdloc >= @kdloc1 and TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFLMB.stsacc <> 'W')
			AND ( TOFLMB.ststrn = '*' )
	GROUP BY TOFLMB.colbaruint  
	)A
UNION ALL
SELECT '14' as urut,
		'NPF Internal (%)' as ket,
		(SUM(A.saldo3)+SUM(A.saldo4)+SUM(A.saldo5)) / (SUM(A.saldo1)+SUM(A.saldo2)+SUM(A.saldo3)+SUM(A.saldo4)+SUM(A.saldo5)) * 100 as saldo 
FROM (
	SELECT TOFLMB.colbaruint,
			CASE
			WHEN TOFLMB.colbaruint = 1 THEN Sum(TOFLMB.osmdlc)
			ELSE 0
			END as saldo1,
			CASE
			WHEN TOFLMB.colbaruint = 2 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo2,
			CASE
			WHEN TOFLMB.colbaruint = 3 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo3,
			CASE
			WHEN TOFLMB.colbaruint = 4 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo4,
			CASE
			WHEN TOFLMB.colbaruint = 5 THEN Sum(TOFLMB.osmdlc) 
			ELSE 0
			END as saldo5
	FROM { oj TOFLMB INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd }	
	WHERE TOFLMB.stsrec in ('A','N') 
			AND ( SETUPLOAN.pokpby not in ( '12','16','18','30'))
			AND ( TOFLMB.kdloc >= @kdloc1 and TOFLMB.kdloc <= @kdloc2 )
			AND ( TOFLMB.stsacc <> 'W')
			AND ( TOFLMB.ststrn = '*' )
	GROUP BY TOFLMB.colbaruint  
	)A

UNION ALL
SELECT CASE
		WHEN A.golac = 3 THEN '15'
		WHEN A.golac = 4 THEN '16'
		ELSE ''
		END AS urut,
		CASE
		WHEN A.golac = 3 THEN 'Pendapatan Bulan ini'
		WHEN A.golac = 4 THEN 'Biaya Bulan ini'
		ELSE ''
		END AS ket,
		CASE
		WHEN A.golac = 3 THEN SUM(A.saldo11) - SUM(A.saldo12)
		WHEN A.golac = 4 THEN SUM(A.saldo21) - SUM(A.saldo22)
		ELSE ''
		END AS saldo
FROM ( 
		SELECT MGL.golac as golac,
				MGL.nosbb as nosbb,
				MGL.nmsbb as nmsbb,
				H_GLTRN.DC AS dc,
				CASE
				WHEN MGL.golac = 3 and H_GLTRN.dc = 'C' THEN SUM(nominal) 
				ELSE 0
				END AS saldo11,
				CASE
				WHEN MGL.golac = 3 and H_GLTRN.dc = 'D' THEN SUM(nominal) 
				ELSE 0
				END AS saldo12,
				CASE
				WHEN MGL.golac = 4 and H_GLTRN.dc = 'D' THEN SUM(nominal) 
				ELSE 0
				END AS saldo21,
				CASE
				WHEN MGL.golac = 4 and H_GLTRN.dc = 'C' THEN SUM(nominal) 
				ELSE 0
				END AS saldo22
		FROM { oj H_GLTRN
				INNER JOIN MGL ON MGL.nosbb = H_GLTRN.noacc }
		WHERE ( left(tgltrn,6) = @periode )
				AND ( MGL.kdloc >= @kdloc1 and MGL.kdloc <= @kdloc2 )
				AND ( MGL.golac in ('3','4') )
				AND ( H_GLTRN.prog <> 'w_trnlr' ) 
				AND ( H_GLTRN.ststrn = '5' ) 
		GROUP BY MGL.golac, MGL.nosbb, MGL.nmsbb, H_GLTRN.DC 
	) A
GROUP BY A.golac

UNION ALL
SELECT '17' AS urut,
		'Rugi Laba Bulan ini' as ket,
		SUM(A.saldo11) - SUM(A.saldo12) - SUM(A.saldo21) + SUM(A.saldo22)  as saldo
FROM (
		SELECT MGL.golac as golac,
				MGL.nosbb as nosbb,
				MGL.nmsbb as nmsbb,
				H_GLTRN.DC AS dc,
				CASE
				WHEN MGL.golac = 3 and H_GLTRN.dc = 'C' THEN SUM(nominal) 
				ELSE 0
				END AS saldo11,
				CASE
				WHEN MGL.golac = 3 and H_GLTRN.dc = 'D' THEN SUM(nominal) 
				ELSE 0
				END AS saldo12,
				CASE
				WHEN MGL.golac = 4 and H_GLTRN.dc = 'D' THEN SUM(nominal) 
				ELSE 0
				END AS saldo21,
				CASE
				WHEN MGL.golac = 4 and H_GLTRN.dc = 'C' THEN SUM(nominal) 
				ELSE 0
				END AS saldo22
		FROM { oj H_GLTRN
				INNER JOIN MGL ON MGL.nosbb = H_GLTRN.noacc }
		WHERE ( left(tgltrn,6) = @periode )
				AND ( MGL.kdloc >= @kdloc1 and MGL.kdloc <= @kdloc2 )
				AND ( MGL.golac in ('3','4') )
				AND ( H_GLTRN.prog <> 'w_trnlr' ) 
				AND ( H_GLTRN.ststrn = '5' ) 
		GROUP BY MGL.golac, MGL.nosbb, MGL.nmsbb, H_GLTRN.DC 
	) A
UNION ALL
SELECT '18' as urut,
		'Rugi Laba Bulan Berjalan' as ket,
		CASE
		WHEN '01' = @tgl THEN SUM(A.tgl01)
		WHEN '02' = @tgl THEN SUM(A.tgl02)
		WHEN '03' = @tgl THEN SUM(A.tgl03)
		WHEN '04' = @tgl THEN SUM(A.tgl04)
		WHEN '05' = @tgl THEN SUM(A.tgl05)
		WHEN '06' = @tgl THEN SUM(A.tgl06)
		WHEN '07' = @tgl THEN SUM(A.tgl07)
		WHEN '08' = @tgl THEN SUM(A.tgl08)
		WHEN '09' = @tgl THEN SUM(A.tgl09)
		WHEN '10' = @tgl THEN SUM(A.tgl10)
		WHEN '11' = @tgl THEN SUM(A.tgl11)
		WHEN '12' = @tgl THEN SUM(A.tgl12)
		WHEN '13' = @tgl THEN SUM(A.tgl13)
		WHEN '14' = @tgl THEN SUM(A.tgl14)
		WHEN '15' = @tgl THEN SUM(A.tgl15)
		WHEN '16' = @tgl THEN SUM(A.tgl16)
		WHEN '17' = @tgl THEN SUM(A.tgl17)
		WHEN '18' = @tgl THEN SUM(A.tgl18)
		WHEN '19' = @tgl THEN SUM(A.tgl19)
		WHEN '20' = @tgl THEN SUM(A.tgl20)
		WHEN '21' = @tgl THEN SUM(A.tgl21)
		WHEN '22' = @tgl THEN SUM(A.tgl22)
		WHEN '23' = @tgl THEN SUM(A.tgl23)
		WHEN '24' = @tgl THEN SUM(A.tgl24)
		WHEN '25' = @tgl THEN SUM(A.tgl25)
		WHEN '26' = @tgl THEN SUM(A.tgl26)
		WHEN '27' = @tgl THEN SUM(A.tgl27)
		WHEN '28' = @tgl THEN SUM(A.tgl28)
		WHEN '29' = @tgl THEN SUM(A.tgl29)
		WHEN '30' = @tgl THEN SUM(A.tgl30)
		WHEN '31' = @tgl THEN SUM(A.tgl31)
		ELSE 0
		END AS saldo
FROM ( select TBLGL.stsac as stsac,
			TBLGL.nobb as nobb,
			TBLGL.nosbb as nosbb,
			TBLGL.nmsbb as nmsbb,
			M_NERACA01.tgl01 as tgl01,
			M_NERACA01.tgl02 as tgl02,
			M_NERACA01.tgl03 as tgl03,
			M_NERACA01.tgl04 as tgl04,
			M_NERACA01.tgl05 as tgl05,
			M_NERACA01.tgl06 as tgl06,
			M_NERACA01.tgl07 as tgl07,
			M_NERACA01.tgl08 as tgl08,
			M_NERACA01.tgl09 as tgl09,
			M_NERACA01.tgl10 as tgl10,
			0 as tgl11,
			0 as tgl12,
			0 as tgl13,
			0 as tgl14,
			0 as tgl15,
			0 as tgl16,
			0 as tgl17,
			0 as tgl18,
			0 as tgl19,
			0 as tgl20,
			0 as tgl21,
			0 as tgl22,
			0 as tgl23,
			0 as tgl24,
			0 as tgl25,
			0 as tgl26,
			0 as tgl27,
			0 as tgl28,
			0 as tgl29,
			0 as tgl30,
			0 as tgl31
	from { oj TBLGL 
			LEFT JOIN M_NERACA01 ON TBLGL.nosbb = M_NERACA01.nosbb }
	where	M_NERACA01.thn = @thn AND M_NERACA01.bln = @bln
			AND ( M_NERACA01.kodeloc >= @kdloc1 AND M_NERACA01.kodeloc <= @kdloc2 )
	UNION ALL
	select TBLGL.stsac as stsac,
			TBLGL.nobb as nobb,
			TBLGL.nosbb as nosbb,
			TBLGL.nmsbb as nmsbb,
			0 as tgl01,
			0 as tgl02,
			0 as tgl03,
			0 as tgl04,
			0 as tgl05,
			0 as tgl06,
			0 as tgl07,
			0 as tgl08,
			0 as tgl09,
			0 as tgl10,
			M_NERACA02.tgl01 as tgl11,
			M_NERACA02.tgl02 as tgl12,
			M_NERACA02.tgl03 as tgl13,
			M_NERACA02.tgl04 as tgl14,
			M_NERACA02.tgl05 as tgl15,
			M_NERACA02.tgl06 as tgl16,
			M_NERACA02.tgl07 as tgl17,
			M_NERACA02.tgl08 as tgl18,
			M_NERACA02.tgl09 as tgl19,
			M_NERACA02.tgl10 as tgl20,
			0 as tgl21,
			0 as tgl22,
			0 as tgl23,
			0 as tgl24,
			0 as tgl25,
			0 as tgl26,
			0 as tgl27,
			0 as tgl28,
			0 as tgl29,
			0 as tgl30,
			0 as tgl31
	from { oj TBLGL 
			LEFT JOIN M_NERACA02 ON TBLGL.nosbb = M_NERACA02.nosbb }
	WHERE ( M_NERACA02.thn = @thn AND M_NERACA02.bln = @bln )
			AND ( M_NERACA02.kodeloc >= @kdloc1 AND M_NERACA02.kodeloc <= @kdloc2 )
	UNION ALL
	select TBLGL.stsac as stsac,
			TBLGL.nobb as nobb,
			TBLGL.nosbb as nosbb,
			TBLGL.nmsbb as nmsbb,
			0 as tgl01,
			0 as tgl02,
			0 as tgl03,
			0 as tgl04,
			0 as tgl05,
			0 as tgl06,
			0 as tgl07,
			0 as tgl08,
			0 as tgl09,
			0 as tgl10,
			0 as tgl11,
			0 as tgl12,
			0 as tgl13,
			0 as tgl14,
			0 as tgl15,
			0 as tgl16,
			0 as tgl17,
			0 as tgl18,
			0 as tgl19,
			0 as tgl20,
			M_NERACA03.tgl01 as tgl21,
			M_NERACA03.tgl02 as tgl22,
			M_NERACA03.tgl03 as tgl23,
			M_NERACA03.tgl04 as tgl24,
			M_NERACA03.tgl05 as tgl25,
			M_NERACA03.tgl06 as tgl26,
			M_NERACA03.tgl07 as tgl27,
			M_NERACA03.tgl08 as tgl28,
			M_NERACA03.tgl09 as tgl29,
			M_NERACA03.tgl10 as tgl30,
			M_NERACA03.tgl11 as tgl31
	from { oj TBLGL 
		LEFT JOIN M_NERACA03 ON TBLGL.nosbb = M_NERACA03.nosbb	}
	Where ( M_NERACA03.thn = @thn AND M_NERACA03.bln = @bln )
			AND ( M_NERACA03.kodeloc >= @kdloc1 AND M_NERACA03.kodeloc <= @kdloc2 )
	) A
WHERE A.stsac ='S'
