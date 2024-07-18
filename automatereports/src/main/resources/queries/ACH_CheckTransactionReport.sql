SELECT
    L.RTL_LOC_ID AS Store,
    loc.store_name,
    loc.address1,
    loc.state,
    loc.city,
    loc.district,
    loc.postal_code,
    TO_CHAR(L.BUSINESS_DATE, 'mm/dd/yyyy') AS BUSINESS_DATE,
    COUNT(L.TNDR_ID) AS ACHTransactions,
    SUM(L.AMT) AS sum
FROM 
    dtv.TTR_TNDR_LINEITM L
JOIN 
    dtv.loc_rtl_loc loc ON loc.rtl_loc_id = L.rtl_loc_id
WHERE 
    L.TNDR_ID = 'ACH_CHECK'
    AND L.BUSINESS_DATE >= TO_DATE('${FROM_DATE}', 'YYYY-MM-DD') 
    AND L.BUSINESS_DATE <= TO_DATE('${TO_DATE}', 'YYYY-MM-DD') 
GROUP BY 
    L.RTL_LOC_ID, 
    TO_CHAR(L.BUSINESS_DATE, 'mm/dd/yyyy'), 
    loc.store_name, 
    loc.address1, 
    loc.state, 
    loc.district, 
    loc.postal_code, 
    loc.city
HAVING 
    SUM(L.AMT) <> 0  
ORDER BY 
    L.RTL_LOC_ID ASC, 
    BUSINESS_DATE ASC