Declare @periode varchar(15)
Set @periode = '202402'

-- Realisasi Bulan Berjalan Pembiayaan Berdasarkan Lokasi dan produk
SELECT A.kdloc, A.nmkantor, A.kdprd, A.nmprd,
		SUM(A.qty_noa) as qty_noa,
		SUM(A.plf_noa) as plf_noa,
		SUM(A.qty) as qty,
		SUM(A.plf) as plf
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
		TOFLMB.jw,
		TOFLMB.kdjw,
		TOFLMB.tgleff,
		TOFLMB.tglexp,
		TOFLMB.tgllunas,
		TOFLMB.stsrec,
		TOFLMDROP.tgldrop,
		TOFLMDROP.modal,
		TOFLMDROP.stsdrop,
		TOFLMB.kdaoh as kdaoh,
		AO.nmao as nmao,
		mCIF.tglbuka as tglbuka,
		Case When Left(mCIF.tglbuka,6) = @periode Then 1 Else 0 End as qty_noa,
		Case When Left(mCIF.tglbuka,6) = @periode Then TOFLMDROP.modal Else 0 End as plf_noa,
		Case When Left(mCIF.tglbuka,6) <> @periode Then 1 Else 0 End as qty,
		Case When Left(mCIF.tglbuka,6) <> @periode Then TOFLMDROP.modal Else 0 End as plf
FROM { oj TOFLMB 
		INNER JOIN mCIF ON mCIF.nocif = TOFLMB.nocif
		INNER JOIN TOFLMDROP ON TOFLMDROP.nokontrak = TOFLMB.nokontrak
		INNER JOIN CABANG ON CABANG.kdloc = TOFLMB.kdloc
		INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd
		LEFT JOIN AO ON AO.kdao = TOFLMB.kdaoh }
WHERE TOFLMDROP.stsdrop ='T'
		AND LEFT(TOFLMDROP.tgldrop,6) = @periode
) A
GROUP BY A.kdloc, A.nmkantor, A.kdprd, A.nmprd
ORDER BY A.kdloc, A.kdprd

-- Realisasi Bulan Berjalan Pembiayaan Berdasarkan AO
SELECT A.kdaoh, IsNull(A.nmao,'') as nmao, 
		SUM(A.qty_noa) as qty_noa,
		SUM(A.plf_noa) as plf_noa,
		SUM(A.qty) as qty,
		SUM(A.plf) as plf
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
		TOFLMB.jw,
		TOFLMB.kdjw,
		TOFLMB.tgleff,
		TOFLMB.tglexp,
		TOFLMB.tgllunas,
		TOFLMB.stsrec,
		TOFLMDROP.tgldrop,
		TOFLMDROP.modal,
		TOFLMDROP.stsdrop,
		TOFLMB.kdaoh as kdaoh,
		AO.nmao as nmao,
		mCIF.tglbuka as tglbuka,
		Case When Left(mCIF.tglbuka,6) = @periode Then 1 Else 0 End as qty_noa,
		Case When Left(mCIF.tglbuka,6) = @periode Then TOFLMDROP.modal Else 0 End as plf_noa,
		Case When Left(mCIF.tglbuka,6) <> @periode Then 1 Else 0 End as qty,
		Case When Left(mCIF.tglbuka,6) <> @periode Then TOFLMDROP.modal Else 0 End as plf
FROM { oj TOFLMB 
		INNER JOIN mCIF ON mCIF.nocif = TOFLMB.nocif
		INNER JOIN TOFLMDROP ON TOFLMDROP.nokontrak = TOFLMB.nokontrak
		INNER JOIN CABANG ON CABANG.kdloc = TOFLMB.kdloc
		INNER JOIN SETUPLOAN ON SETUPLOAN.kdprd = TOFLMB.kdprd
		LEFT JOIN AO ON AO.kdao = TOFLMB.kdaoh }
WHERE TOFLMDROP.stsdrop ='T'
		AND LEFT(TOFLMDROP.tgldrop,6) = @periode
) A
GROUP BY A.kdaoh, A.nmao
ORDER BY A.nmao
