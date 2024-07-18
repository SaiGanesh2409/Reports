SELECT DISTINCT TTCT.RTL_LOC_ID             AS Store,
  (SELECT DISTINCT STORE_NAME FROM DTV.LOC_RTL_LOC WHERE RTL_LOC_ID= TTTC.RTL_LOC_ID) AS STORE_NAME,
  (SELECT DISTINCT ADDRESS1  FROM DTV.LOC_RTL_LOC WHERE RTL_LOC_ID=TTTC.RTL_LOC_ID) AS STORE_ADDRESS,
TO_CHAR(TTCT.BUSINESS_DATE,'DD-MON-YYYY') AS BUSINESS_DATE,
  --TTCT.TRANS_SEQ,
  CASE
    WHEN TTCT.OUTBOUND_TNDR_REPOSITORY_ID IS NULL 
    THEN 'Store Bank Reconcile'
    WHEN TTCT.OUTBOUND_TNDR_REPOSITORY_ID='STOREBANK' 
    THEN 'Bank Deposit'
    ELSE TTCT.OUTBOUND_TNDR_REPOSITORY_ID
  END                         AS Till_Number,
  (SELECT EMPLOYEE_ID FROM DTV.CRM_PARTY WHERE PARTY_ID= TTTC.CREATE_USER_ID
  )                                                AS PID,
  (SELECT dtv.crm_party.first_name || ' ' || dtv.crm_party.last_name FROM DTV.CRM_PARTY WHERE PARTY_ID = TTTC.CREATE_USER_ID) AS Employee_Name,
  --TTTC.TNDR_ID                 AS TENDER_ID,
  TTTC.AMT-TTTC.DIFFERENCE_AMT AS EXPECTED_AMT,
  TTTC.AMT                     AS Actual_Amt,
  TTTC.DIFFERENCE_AMT          AS Variance,
  TTCT.REASCODE,
  TO_CHAR(
  (SELECT NOTE
  FROM DTV.TRN_TRANS_NOTES
  WHERE RTL_LOC_ID=TTTC.rtl_loc_id
  AND TRANS_SEQ   =TTTC.TRANS_SEQ
  AND WKSTN_ID    =TTTC.WKSTN_ID
  AND BUSINESS_DATE=TTTC.business_date
  )) AS Comments,
  TO_CHAR(TTCT.CREATE_DATE, 'DD-MON-YYYY HH24:MI') AS Create_Date
FROM DTV.tsn_session TS
INNER JOIN DTV.tsn_tndr_control_trans TTCT
ON TS.rtl_loc_id       = TTCT.rtl_loc_id
AND TS.ORGANIZATION_ID = TTCT.ORGANIZATION_ID
AND (TS.session_id     = TTCT.outbound_session_id
OR TS.session_id       =TTCT.INBOUND_SESSION_ID)
INNER JOIN DTV.tsn_tndr_tndr_count TTTC
ON TTCT.organization_id = TTTC.organization_id
AND TTCT.rtl_loc_id     = TTTC.rtl_loc_id
AND TTCT.business_date  = TTTC.business_date
AND TTCT.wkstn_id       = TTTC.wkstn_id
AND TTCT.TRANS_SEQ      = TTTC.TRANS_SEQ
INNER JOIN DTV.tnd_tndr TTD
ON TTTC.organization_id                      = TTD.organization_id
AND TTTC.TNDR_ID                             = TTD.TNDR_ID
WHERE UPPER(TTCT.TYPCODE)                                   IN ('ENDCOUNT','BANK_DEPOSIT')
AND TO_CHAR(TTCT.business_date, 'mm\dd\yyyy')=TO_CHAR(SYSDATE-1, 'mm\dd\yyyy')
AND TTTC. TNDR_TYPCODE= 'CURRENCY'
AND TTTC.TNDR_ID= 'USD_CURRENCY'
AND TTTC.DIFFERENCE_AMT < > 0
ORDER BY TTCT.RTL_LOC_ID,
  --TTCT.TRANS_SEQ,
  Till_Number ASC