Declare @periode varchar(15)
Declare @thn varchar(15)
Declare @bln varchar(15)

Set @periode = '202511'
Set @thn = Substring(@periode,1,4)
Set @bln = Substring(@periode,5,2)

SELECT AO.kdao, 
	AO.nmao, 
	AO.kdloc, 
	AO.stsrec,
	TARGETAO.thn,
	TARGETAO.bln,
	TARGETAO.tab,
	Cast(0 as decimal(18,2)) as rtab,
	TARGETAO.dep,
	IsNull(AB.nomrp,0) as rdep,
	Case When TARGETAO.dep <> 0 Then ( IsNull(AB.nomrp,0) / TARGETAO.dep ) * 100 Else 0 End As bdr_dep,
	TARGETAO.loan,
	IsNull(AC.modal,0) as rloan,
	Case When TARGETAO.loan <> 0 Then (IsNull(AC.modal,0) / TARGETAO.loan ) * 100 Else 0 End As bdr_loan
FROM { oj AO
		LEFT JOIN TARGETAO ON TARGETAO.kdao = AO.kdao 
		LEFT JOIN (
		SELECT kodeaoh, Left(tglbuka,6) as periode, SUM(nomrp)as nomrp 
		FROM TOFDEP WHERE Left(tglbuka,6) = @periode
		GROUP BY kodeaoh, Left(tglbuka,6)) AB
		ON AB.kodeaoh = AO.kdao 
		LEFT JOIN (
		SELECT TOFLMB.kdaoh, Left(TOFLMDROP.tgldrop,6) as periode, SUM(TOFLMDROP.modal) as modal
		FROM { oj TOFLMB INNER JOIN TOFLMDROP ON TOFLMDROP.nokontrak = TOFLMB.nokontrak }
		WHERE TOFLMDROP.stsdrop ='T' AND LEFT(TOFLMDROP.tgldrop,6) = @periode
		GROUP BY TOFLMB.kdaoh, Left(TOFLMDROP.tgldrop,6) ) AC
		ON AC.kdaoh = AO.kdao
		}
WHERE TARGETAO.thn = @thn AND TARGETAO.bln = @bln AND AO.stsrec in ('A','N')
		AND ( TARGETAO.tab + TARGETAO.dep + TARGETAO.loan ) > 0
ORDER BY AO.nmao, TARGETAO.thn, TARGETAO.bln

--SELECT * FROM TARGETAO
--SELECT kodeaoh, Left(tglbuka,6) as periode, SUM(nomrp)as nomrp FROM TOFDEP
--GROUP BY kodeaoh, Left(tglbuka,6)
--ORDER BY kodeaoh
--SELECT TOFLMB.kdaoh, Left(TOFLMDROP.tgldrop,6) as periode, SUM(TOFLMDROP.modal) as modal
--FROM { oj TOFLMB INNER JOIN TOFLMDROP ON TOFLMDROP.nokontrak = TOFLMB.nokontrak }
--WHERE TOFLMDROP.stsdrop ='T' AND LEFT(TOFLMDROP.tgldrop,6) = @periode
--GROUP BY TOFLMB.kdaoh, Left(TOFLMDROP.tgldrop,6) 

--Update TARGETAO
--SEt tab = 20000000, dep = 100000000, loan = 400000000
--where kdao in ('11','12','08')

