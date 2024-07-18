---AGTPORTL17-3247 - Smartsafe Treasury Reporting v2.0
with smartsafe_store as (
 select distinct CASE WHEN loc.org_scope_code IS NULL THEN replace(chgdpl.org_scope,'STORE:','') 
 ELSE replace(loc.org_scope_code,'STORE:','')   END rtl_loc_id 
 from
    -- Get latest pushes for systemconfig
    (select chg0.ORGANIZATION_ID, chg0.PROFILE_GROUP_ID, chg0.PROFILE_ELEMENT_ID, chg0.CHANGE_TYPE, chg0.CHANGE_SUBTYPE, 
            max(chg0.CONFIG_VERSION) CONFIG_VERSION, dpl.org_scope
    from XADMIN.cfg_profile_element_changes chg0, xadmin.dpl_deployment dpl        
    where DEPLOYMENT_TYPE = 'CONFIGURATOR' and DEPLOY_STATUS IN ('COMPLETE', 'IN_PROCESS', 'SCHEDULED') -- Considering SCHEDULED is eligible
    and dpl.config_version = chg0.config_version and 
    dpl.profile_element_id = chg0.profile_element_id and
    dpl.profile_group_id = chg0.profile_group_id 
    and chg0.CHANGE_TYPE = 'SYSCFG' AND chg0.CHANGE_SUBTYPE = 'SystemConfig.xml'
    group by chg0.ORGANIZATION_ID,
    chg0.PROFILE_GROUP_ID,
    chg0.PROFILE_ELEMENT_ID,
    chg0.CHANGE_TYPE, chg0.CHANGE_SUBTYPE,
    dpl.org_scope) chgdpl
    
    -- join back to cfg_profile_element_changes to get content
    join XADMIN.cfg_profile_element_changes chg1
    on chgdpl.ORGANIZATION_ID = chg1.ORGANIZATION_ID and
    chgdpl.PROFILE_GROUP_ID = chg1.PROFILE_GROUP_ID and
    chgdpl.PROFILE_ELEMENT_ID = chg1.PROFILE_ELEMENT_ID and
    chgdpl.CHANGE_TYPE = chg1.CHANGE_TYPE and
    chgdpl.CHANGE_SUBTYPE = chg1.CHANGE_SUBTYPE and
    chgdpl.CONFIG_VERSION = chg1.CONFIG_VERSION
    
    -- get stores in the case deploying for a collection
    left join XADMIN.loc_rtl_loc_collection_element loc
    on chgdpl.org_scope = loc.COLLECTION_NAME   
 where chg1.CHANGES like '%SmartSafeEnabled=true%'
)
SELECT
    rpt.locationid,rpt.amount,rpt.trans_date,rpt.department,rpt.billerid,rpt.payment_type,rpt.deposits,
    (select hr.employee_id from dtv.hrs_employee hr where rpt.create_user_id=hr.party_id) as pid
FROM
    (
        SELECT
            ttl.rtl_loc_id                       AS locationid,
            SUM(
                CASE
                    WHEN trlp1.property_code = 'SPS_REVERSAL_ORIG_TRANS_ID' THEN
                        0
                    ELSE
                        trlp.decimal_value
                END
            )                                    AS amount,
            to_char(ttl.create_date, 'YYYYMMDD') AS trans_date,
            'CORE'                               AS department,
            substr(biller.billerid, 0, '8')        AS billerid,
            CASE
                WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                     AND tndr.tndr_id != 'ACH_CHECK' THEN
                    'DEPOSIT'
                WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                     AND tndr.tndr_id = 'ACH_CHECK' THEN
                    tndr.tndr_id
                ELSE
                    tndr.tndr_typcode
            END                                  AS payment_type,
            CASE
                WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                     AND tndr.tndr_id != 'ACH_CHECK' THEN
                    ss.ss_id
                ELSE
                    NULL
            END                                  AS deposits,
			ttl.create_user_id
        FROM
                 dtv.ttr_tndr_lineitm ttl
            JOIN dtv.tnd_tndr             tndr ON ttl.tndr_id = tndr.tndr_id
            JOIN dtv.trl_rtrans_lineitm_p trlp ON trlp.organization_id = ttl.organization_id
                                                  AND trlp.rtl_loc_id = ttl.rtl_loc_id
                                                  AND trlp.trans_seq = ttl.trans_seq
                                                  AND trlp.wkstn_id = ttl.wkstn_id
				                     AND trlp.rtrans_lineitm_seq = ttl.rtrans_lineitm_seq
                                                  AND trlp.business_date = ttl.business_date
                                                  AND ( ( trlp.property_code = 'CPS_POSTED_TNDR_AMT'
                                                          AND ttl.tndr_id = 'ACH_CHECK' )
                                                        OR ( trlp.property_code != 'CPS_POSTED_TNDR_AMT'
                                                             AND trlp.property_code LIKE 'CPS_POSTED_TNDR_AMT%' ) )
            LEFT JOIN dtv.trl_rtrans_lineitm_p trlp1 ON trlp.organization_id = trlp1.organization_id
                                                        AND trlp.rtl_loc_id = trlp1.rtl_loc_id
                                                        AND trlp.trans_seq = regexp_substr(trlp1.string_value, '[^::]+', 1, 5)
                                                        AND trlp.wkstn_id = regexp_substr(trlp1.string_value, '[^::]+', 1, 4)
                                                        AND trlp.business_date = trlp1.business_date
                                                        AND trlp1.property_code = 'SPS_REVERSAL_ORIG_TRANS_ID'
            JOIN dtv.trl_rtrans_lineitm   trl ON trl.organization_id = ttl.organization_id
                                               AND trl.rtl_loc_id = ttl.rtl_loc_id
                                               AND trl.trans_seq = ttl.trans_seq
                                               AND trl.rtrans_lineitm_seq = ttl.rtrans_lineitm_seq
                                               AND trl.business_date = ttl.business_date
                                               AND trl.wkstn_id = ttl.wkstn_id
                                               AND trl.void_flag = 0
            JOIN dtv.trn_trans            trn ON trl.rtl_loc_id = trn.rtl_loc_id
                                      AND trl.organization_id = trn.organization_id
                                      AND trl.business_date = trn.business_date
                                      AND trl.trans_seq = trn.trans_seq
                                      AND trl.wkstn_id = trn.wkstn_id
            JOIN (
                SELECT DISTINCT
                    bill_trlp.string_value AS billerid,
                    bill_trlp.trans_seq,
                    bill_trlp.business_date,
                    bill_trlp.rtl_loc_id,
                    bill_trlp.wkstn_id,
                    bill_trlp.rtrans_lineitm_seq
                FROM
                         dtv.trl_rtrans_lineitm_p bill_trlp
                    JOIN dtv.trl_rtrans_lineitm bill_trl ON bill_trlp.organization_id = bill_trl.organization_id
                                                            AND bill_trlp.rtl_loc_id = bill_trl.rtl_loc_id
                                                            AND bill_trlp.trans_seq = bill_trl.trans_seq
                                                            AND bill_trlp.rtrans_lineitm_seq = bill_trl.rtrans_lineitm_seq
                                                            AND bill_trlp.business_date = bill_trl.business_date
                                                            AND bill_trlp.wkstn_id = bill_trl.wkstn_id
                                                            AND bill_trl.void_flag = 0
                    JOIN dtv.trl_sale_lineitm   tsl ON tsl.organization_id = bill_trl.organization_id
                                                     AND tsl.rtl_loc_id = bill_trl.rtl_loc_id
                                                     AND tsl.trans_seq = bill_trl.trans_seq
                                                     AND tsl.business_date = bill_trl.business_date
                                                     AND tsl.wkstn_id = bill_trl.wkstn_id
                                                     AND tsl.item_id NOT IN ( 'MOBILEOTD0001', 'MOBILEOTS0001' )
                WHERE
                    bill_trlp.property_code = 'SPECTRUM_BILLER_ID'
            )                        biller ON biller.trans_seq = ttl.trans_seq
                        AND biller.business_date = ttl.business_date
                        AND biller.wkstn_id = ttl.wkstn_id
                        AND biller.rtl_loc_id = ttl.rtl_loc_id
            LEFT JOIN (SELECT trnp.organization_id,trnp.rtl_loc_id,trnp.business_date,
					listagg(trnp.string_value,', ') within GROUP(ORDER BY trnp.string_value) as ss_id
					FROM dtv.trn_trans_p trnp where trnp.property_code like 'SMARTSAFE_DEPOSIT_ID%' 
					group by trnp.organization_id,trnp.rtl_loc_id,trnp.business_date) ss
			ON ss.organization_id = trn.organization_id
			AND ss.rtl_loc_id = trn.rtl_loc_id
			AND ss.business_date = trn.business_date
			--AND ss.wkstn_id = trn.wkstn_id
			--AND ss.trans_seq = trn.trans_seq
        WHERE
                trunc(ttl.create_date) = TO_DATE('${REPORT_DATE}', 'YYYY-MM-DD')
            AND ttl.organization_id = '1'
            AND ttl.rtl_loc_id LIKE '%'
        GROUP BY
            ttl.rtl_loc_id,
            to_char(ttl.create_date, 'YYYYMMDD'),
            trlp.string_value,
            substr(biller.billerid, 0, '8'),
            (
                CASE
                    WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                         AND tndr.tndr_id != 'ACH_CHECK' THEN
                        'DEPOSIT'
                    WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                         AND tndr.tndr_id = 'ACH_CHECK' THEN
                        tndr.tndr_id
                    ELSE
                        tndr.tndr_typcode
                END
            ),
            (
                CASE
                    WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                         AND tndr.tndr_id != 'ACH_CHECK' THEN
                        ss.ss_id
                    ELSE
                        NULL
                END
            ),ttl.create_user_id
        UNION
        SELECT
            ttl.rtl_loc_id                       AS locationid,
            SUM(
                CASE
                    WHEN trlp1.property_code = 'SPS_REVERSAL_ORIG_TRANS_ID' THEN
                        0
                    ELSE
                        trlp.decimal_value
                END
            )                                    AS amount,
            to_char(ttl.create_date, 'YYYYMMDD') AS trans_date,
            'MOBILE DEVICE PAYMENT'              AS department,
            substr(biller.billerid, 0, '8')        AS billerid,
            CASE
                WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                     AND tndr.tndr_id != 'ACH_CHECK' THEN
                    'DEPOSIT'
                WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                     AND tndr.tndr_id = 'ACH_CHECK' THEN
                    tndr.tndr_id
                ELSE
                    tndr.tndr_typcode
            END                                  AS payment_type,
            CASE
                WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                     AND tndr.tndr_id != 'ACH_CHECK' THEN
                    ss.ss_id
                ELSE
                    NULL
            END                                  AS deposits,
			ttl.create_user_id
        FROM
                 dtv.ttr_tndr_lineitm ttl
            JOIN dtv.tnd_tndr             tndr ON ttl.tndr_id = tndr.tndr_id
            JOIN dtv.trl_rtrans_lineitm_p trlp ON trlp.organization_id = ttl.organization_id
                                                  AND trlp.rtl_loc_id = ttl.rtl_loc_id
                                                  AND trlp.trans_seq = ttl.trans_seq
                                                  AND trlp.wkstn_id = ttl.wkstn_id
                                                  AND trlp.rtrans_lineitm_seq = ttl.rtrans_lineitm_seq
                                                  AND trlp.business_date = ttl.business_date
                                                  AND ( ( trlp.property_code = 'CPS_POSTED_TNDR_AMT'
                                                          AND ttl.tndr_id = 'ACH_CHECK' )
                                                        OR ( trlp.property_code != 'CPS_POSTED_TNDR_AMT'
                                                             AND trlp.property_code LIKE 'CPS_POSTED_TNDR_AMT%' ) )
            LEFT JOIN dtv.trl_rtrans_lineitm_p trlp1 ON trlp.organization_id = trlp1.organization_id
                                                        AND trlp.rtl_loc_id = trlp1.rtl_loc_id
                                                        AND trlp.trans_seq = regexp_substr(trlp1.string_value, '[^::]+', 1, 5)
                                                        AND trlp.wkstn_id = regexp_substr(trlp1.string_value, '[^::]+', 1, 4)
                                                        AND trlp.business_date = trlp1.business_date
                                                        AND trlp1.property_code = 'SPS_REVERSAL_ORIG_TRANS_ID'
            JOIN dtv.trl_rtrans_lineitm   trl ON trl.organization_id = ttl.organization_id
                                               AND trl.rtl_loc_id = ttl.rtl_loc_id
                                               AND trl.trans_seq = ttl.trans_seq
                                               AND trl.rtrans_lineitm_seq = ttl.rtrans_lineitm_seq
                                               AND trl.business_date = ttl.business_date
                                               AND trl.wkstn_id = ttl.wkstn_id
                                               AND trl.void_flag = 0
            JOIN dtv.trn_trans            trn ON trl.rtl_loc_id = trn.rtl_loc_id
                                      AND trl.organization_id = trn.organization_id
                                      AND trl.business_date = trn.business_date
                                      AND trl.trans_seq = trn.trans_seq
                                      AND trl.wkstn_id = trn.wkstn_id
            JOIN (
                SELECT DISTINCT
                    bill_trlp.string_value AS billerid,
                    bill_trlp.trans_seq,
                    bill_trlp.business_date,
                    bill_trlp.rtl_loc_id,
                    bill_trlp.wkstn_id,
                    bill_trlp.rtrans_lineitm_seq
                FROM
                         dtv.trl_rtrans_lineitm_p bill_trlp
                    JOIN dtv.trl_rtrans_lineitm bill_trl ON bill_trlp.organization_id = bill_trl.organization_id
                                                            AND bill_trlp.rtl_loc_id = bill_trl.rtl_loc_id
                                                            AND bill_trlp.trans_seq = bill_trl.trans_seq
                                                            AND bill_trlp.rtrans_lineitm_seq = bill_trl.rtrans_lineitm_seq
                                                            AND bill_trlp.business_date = bill_trl.business_date
                                                            AND bill_trlp.wkstn_id = bill_trl.wkstn_id
                                                            AND bill_trl.void_flag = 0
                    JOIN dtv.trl_sale_lineitm   tsl ON tsl.organization_id = bill_trl.organization_id
                                                     AND tsl.rtl_loc_id = bill_trl.rtl_loc_id
                                                     AND tsl.trans_seq = bill_trl.trans_seq
                                                     AND tsl.business_date = bill_trl.business_date
                                                     AND tsl.wkstn_id = bill_trl.wkstn_id
                                                     AND tsl.item_id = 'MOBILEOTD0001'
                                                     AND tsl.scanned_item_id NOT IN ( 'SPECTRUM001', 'MOBILEOTS0001' )
                WHERE
                    bill_trlp.property_code = 'SPECTRUM_BILLER_ID'
            )                        biller ON biller.trans_seq = ttl.trans_seq
                        AND biller.business_date = ttl.business_date
                        AND biller.wkstn_id = ttl.wkstn_id
                        AND biller.rtl_loc_id = ttl.rtl_loc_id
            LEFT JOIN (SELECT trnp.organization_id,trnp.rtl_loc_id,trnp.business_date,
					listagg(trnp.string_value,', ') within GROUP(ORDER BY trnp.string_value) as ss_id
					FROM dtv.trn_trans_p trnp where trnp.property_code like 'SMARTSAFE_DEPOSIT_ID%' 
					group by trnp.organization_id,trnp.rtl_loc_id,trnp.business_date) ss
			ON ss.organization_id = trn.organization_id
			AND ss.rtl_loc_id = trn.rtl_loc_id
			AND ss.business_date = trn.business_date
			--AND ss.wkstn_id = trn.wkstn_id
			--AND ss.trans_seq = trn.trans_seq
        WHERE
                trunc(ttl.create_date) = TO_DATE('${REPORT_DATE}', 'YYYY-MM-DD')
            AND ttl.organization_id = '1'
            AND ttl.rtl_loc_id LIKE '%'
        GROUP BY
            ttl.rtl_loc_id,
            to_char(ttl.create_date, 'YYYYMMDD'),
            trlp.string_value,
            substr(biller.billerid, 0, '8'),
            (
                CASE
                    WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                         AND tndr.tndr_id != 'ACH_CHECK' THEN
                        'DEPOSIT'
                    WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                         AND tndr.tndr_id = 'ACH_CHECK' THEN
                        tndr.tndr_id
                    ELSE
                        tndr.tndr_typcode
                END
            ),
            (
                CASE
                    WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                         AND tndr.tndr_id != 'ACH_CHECK' THEN
                        ss.ss_id
                    ELSE
                        NULL
                END
            ),ttl.create_user_id
        UNION
        SELECT
            ttl.rtl_loc_id                       AS locationid,
            SUM(
                CASE
                    WHEN trlp1.property_code = 'SPS_REVERSAL_ORIG_TRANS_ID' THEN
                        0
                    ELSE
                        trlp.decimal_value
                END
            )                                    AS amount,
            to_char(ttl.create_date, 'YYYYMMDD') AS trans_date,
            'MOBILE SERVICE PAYMENT'             AS department,
            substr(biller.billerid, 0, '8')        AS billerid,
            CASE
                WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                     AND tndr.tndr_id != 'ACH_CHECK' THEN
                    'DEPOSIT'
                WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                     AND tndr.tndr_id = 'ACH_CHECK' THEN
                    tndr.tndr_id
                ELSE
                    tndr.tndr_typcode
            END                                  AS payment_type,
            CASE
                WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                     AND tndr.tndr_id != 'ACH_CHECK' THEN
                    ss.ss_id
                ELSE
                    NULL
            END                                  AS deposits,
			ttl.create_user_id
        FROM
                 dtv.ttr_tndr_lineitm ttl
            JOIN dtv.tnd_tndr             tndr ON ttl.tndr_id = tndr.tndr_id
            JOIN dtv.trl_rtrans_lineitm_p trlp ON trlp.organization_id = ttl.organization_id
                                                  AND trlp.rtl_loc_id = ttl.rtl_loc_id
                                                  AND trlp.trans_seq = ttl.trans_seq
                                                  AND trlp.wkstn_id = ttl.wkstn_id
                                                  AND trlp.rtrans_lineitm_seq = ttl.rtrans_lineitm_seq
                                                  AND trlp.business_date = ttl.business_date
                                                  AND ( ( trlp.property_code = 'CPS_POSTED_TNDR_AMT'
                                                          AND ttl.tndr_id = 'ACH_CHECK' )
                                                        OR ( trlp.property_code != 'CPS_POSTED_TNDR_AMT'
                                                             AND trlp.property_code LIKE 'CPS_POSTED_TNDR_AMT%' ) )
            LEFT JOIN dtv.trl_rtrans_lineitm_p trlp1 ON trlp.organization_id = trlp1.organization_id
                                                        AND trlp.rtl_loc_id = trlp1.rtl_loc_id
                                                        AND trlp.trans_seq = regexp_substr(trlp1.string_value, '[^::]+', 1, 5)
                                                        AND trlp.wkstn_id = regexp_substr(trlp1.string_value, '[^::]+', 1, 4)
                                                        AND trlp.business_date = trlp1.business_date
                                                        AND trlp1.property_code = 'SPS_REVERSAL_ORIG_TRANS_ID'
            JOIN dtv.trl_rtrans_lineitm   trl ON trl.organization_id = ttl.organization_id
                                               AND trl.rtl_loc_id = ttl.rtl_loc_id
                                               AND trl.trans_seq = ttl.trans_seq
                                               AND trl.rtrans_lineitm_seq = ttl.rtrans_lineitm_seq
                                               AND trl.business_date = ttl.business_date
                                               AND trl.wkstn_id = ttl.wkstn_id
                                               AND trl.void_flag = 0
            JOIN dtv.trn_trans            trn ON trl.rtl_loc_id = trn.rtl_loc_id
                                      AND trl.organization_id = trn.organization_id
                                      AND trl.business_date = trn.business_date
                                      AND trl.trans_seq = trn.trans_seq
                                      AND trl.wkstn_id = trn.wkstn_id
            JOIN (
                SELECT DISTINCT
                    bill_trlp.string_value AS billerid,
                    bill_trlp.trans_seq,
                    bill_trlp.business_date,
                    bill_trlp.rtl_loc_id,
                    bill_trlp.wkstn_id,
                    bill_trlp.rtrans_lineitm_seq
                FROM
                         dtv.trl_rtrans_lineitm_p bill_trlp
                    JOIN dtv.trl_rtrans_lineitm bill_trl ON bill_trlp.organization_id = bill_trl.organization_id
                                                            AND bill_trlp.rtl_loc_id = bill_trl.rtl_loc_id
                                                            AND bill_trlp.trans_seq = bill_trl.trans_seq
                                                            AND bill_trlp.rtrans_lineitm_seq = bill_trl.rtrans_lineitm_seq
                                                            AND bill_trlp.business_date = bill_trl.business_date
                                                            AND bill_trlp.wkstn_id = bill_trl.wkstn_id
                                                            AND bill_trl.void_flag = 0
                    JOIN dtv.trl_sale_lineitm   tsl ON tsl.organization_id = bill_trl.organization_id
                                                     AND tsl.rtl_loc_id = bill_trl.rtl_loc_id
                                                     AND tsl.trans_seq = bill_trl.trans_seq
                                                     AND tsl.business_date = bill_trl.business_date
                                                     AND tsl.wkstn_id = bill_trl.wkstn_id
                                                     AND tsl.scanned_item_id = 'MOBILEOTS0001'
                                                     AND tsl.scanned_item_id NOT IN ( 'MOBILEOTD0001', 'SPECTRUM001' )
                WHERE
                    bill_trlp.property_code = 'SPECTRUM_BILLER_ID'
            )                        biller ON biller.trans_seq = ttl.trans_seq
                        AND biller.business_date = ttl.business_date
                        AND biller.wkstn_id = ttl.wkstn_id
                        AND biller.rtl_loc_id = ttl.rtl_loc_id
            LEFT JOIN (SELECT trnp.organization_id,trnp.rtl_loc_id,trnp.business_date,
					listagg(trnp.string_value,', ') within GROUP(ORDER BY trnp.string_value) as ss_id
					FROM dtv.trn_trans_p trnp where trnp.property_code like 'SMARTSAFE_DEPOSIT_ID%' 
					group by trnp.organization_id,trnp.rtl_loc_id,trnp.business_date) ss
			ON ss.organization_id = trn.organization_id
			AND ss.rtl_loc_id = trn.rtl_loc_id
			AND ss.business_date = trn.business_date
			--AND ss.wkstn_id = trn.wkstn_id
			--AND ss.trans_seq = trn.trans_seq
        WHERE
                trunc(ttl.create_date) = TO_DATE('${REPORT_DATE}', 'YYYY-MM-DD')
            AND ttl.organization_id = '1'
            AND ttl.rtl_loc_id LIKE '%'
        GROUP BY
            ttl.rtl_loc_id,
            to_char(ttl.create_date, 'YYYYMMDD'),
            trlp.string_value,
            substr(biller.billerid, 0, '8'),
            (
                CASE
                    WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                         AND tndr.tndr_id != 'ACH_CHECK' THEN
                        'DEPOSIT'
                    WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                         AND tndr.tndr_id = 'ACH_CHECK' THEN
                        tndr.tndr_id
                    ELSE
                        tndr.tndr_typcode
                END
            ),
            (
                CASE
                    WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                         AND tndr.tndr_id != 'ACH_CHECK' THEN
                        ss.ss_id
                    ELSE
                        NULL
                END
            ),ttl.create_user_id
        UNION
        SELECT
            locationid,
            SUM(amt) AS amount,
            trans_date,
            department,
            billerid,
            tenderid AS payment_type,
            deposits,
			create_user_id
        FROM
            (
                SELECT
                    ttl.rtl_loc_id                       AS locationid,
                    ( ttl.amt - trlp.decimal_value )     AS amt,
                    CASE
                        WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                             AND tndr.tndr_id != 'ACH_CHECK' THEN
                            'DEPOSIT'
                        WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                             AND tndr.tndr_id = 'ACH_CHECK' THEN
                            tndr.tndr_id
                        ELSE
                            tndr.tndr_typcode
                    END                                  AS tenderid,
                    NULL                                 AS billerid,
                    ttl.wkstn_id                         AS wkstn_id,
                    CASE
                        WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                             AND tndr.tndr_id != 'ACH_CHECK' THEN
                            ss.ss_id
                        ELSE
                            NULL
                    END                                  AS deposits,
                    to_char(ttl.create_date, 'YYYYMMDD') AS trans_date,
                    'ACCESSORY'                          AS department,
					ttl.create_user_id
                FROM
                         dtv.ttr_tndr_lineitm ttl
                    JOIN dtv.tnd_tndr             tndr ON ttl.tndr_id = tndr.tndr_id
                    JOIN dtv.trl_rtrans_lineitm   trl ON trl.organization_id = ttl.organization_id
                                                       AND trl.rtl_loc_id = ttl.rtl_loc_id
                                                       AND trl.trans_seq = ttl.trans_seq
                                                       AND trl.rtrans_lineitm_seq = ttl.rtrans_lineitm_seq
                                                       AND trl.wkstn_id = ttl.wkstn_id
                                                       AND trl.business_date = ttl.business_date
                                                       AND trl.void_flag = 0
                    JOIN dtv.trn_trans            trn ON trl.rtl_loc_id = trn.rtl_loc_id
                                              AND trl.organization_id = trn.organization_id
                                              AND trl.business_date = trn.business_date
                                              AND trl.trans_seq = trn.trans_seq
                    JOIN dtv.trl_rtrans_lineitm_p trlp ON trlp.organization_id = ttl.organization_id
                                                          AND trlp.rtl_loc_id = ttl.rtl_loc_id
                                                          AND trlp.trans_seq = ttl.trans_seq
                                                          AND trlp.rtrans_lineitm_seq = ttl.rtrans_lineitm_seq
                                                          AND trlp.property_code = 'CPS_POSTED_TNDR_AMT'
                                                          AND trunc(ttl.create_date) = TO_DATE('${REPORT_DATE}', 'YYYY-MM-DD')
                                                          AND ttl.organization_id = '1'
                                                          AND ttl.rtl_loc_id LIKE '%'
                                                          AND ( ttl.amt - trlp.decimal_value ) > 0
                    LEFT JOIN (SELECT trnp.organization_id,trnp.rtl_loc_id,trnp.business_date,
						listagg(trnp.string_value,', ') within GROUP(ORDER BY trnp.string_value) as ss_id
					FROM dtv.trn_trans_p trnp where trnp.property_code like 'SMARTSAFE_DEPOSIT_ID%' 
						group by trnp.organization_id,trnp.rtl_loc_id,trnp.business_date) ss
					ON ss.organization_id = trn.organization_id
					AND ss.rtl_loc_id = trn.rtl_loc_id
					AND ss.business_date = trn.business_date
					--AND ss.wkstn_id = trn.wkstn_id
					--AND ss.trans_seq = trn.trans_seq
                WHERE
                    EXISTS (
                        SELECT
                            1
                        FROM
                            dtv.trl_sale_lineitm tsl
                        WHERE
                                tsl.organization_id = ttl.organization_id
                            AND tsl.rtl_loc_id = ttl.rtl_loc_id
                            AND tsl.trans_seq = ttl.trans_seq
                            AND tsl.business_date = ttl.business_date
                            AND tsl.wkstn_id = ttl.wkstn_id
                            AND merch_level_1 != 'NP'
                    )
                UNION ALL
                SELECT
                    ttl.rtl_loc_id                       AS locationid,
                    ttl.amt                              AS amt,
                    CASE
                        WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                             AND tndr.tndr_id != 'ACH_CHECK' THEN
                            'DEPOSIT'
                        WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                             AND tndr.tndr_id = 'ACH_CHECK' THEN
                            tndr.tndr_id
                        ELSE
                            tndr.tndr_typcode
                    END                                  AS tenderid,
                    NULL                                 AS billerid,
                    ttl.wkstn_id                         AS wkstn_id,
                    CASE
                        WHEN tndr.tndr_typcode != 'CREDIT_CARD'
                             AND tndr.tndr_id != 'ACH_CHECK' THEN
                            ss.ss_id
                        ELSE
                            NULL
                    END                                  AS deposits,
                    to_char(ttl.create_date, 'YYYYMMDD') AS trans_date,
                    'ACCESSORY'                          AS department,
			        ttl.create_user_id
                FROM
                         dtv.ttr_tndr_lineitm ttl
                    JOIN dtv.tnd_tndr           tndr ON ttl.tndr_id = tndr.tndr_id
                    JOIN dtv.trl_rtrans_lineitm trl ON trl.organization_id = ttl.organization_id
                                                       AND trl.rtl_loc_id = ttl.rtl_loc_id
                                                       AND trl.trans_seq = ttl.trans_seq
                                                       AND trl.rtrans_lineitm_seq = ttl.rtrans_lineitm_seq
                                                       AND trl.wkstn_id = ttl.wkstn_id
                                                       AND trl.business_date = ttl.business_date
                                                       AND trl.void_flag = 0
                    JOIN dtv.trn_trans          trn ON trl.rtl_loc_id = trn.rtl_loc_id
                                              AND trl.organization_id = trn.organization_id
                                              AND trl.business_date = trn.business_date
                                              AND trl.trans_seq = trn.trans_seq
                    LEFT JOIN (SELECT trnp.organization_id,trnp.rtl_loc_id,trnp.business_date,
						listagg(trnp.string_value,', ') within GROUP(ORDER BY trnp.string_value) as ss_id
					FROM dtv.trn_trans_p trnp where trnp.property_code like 'SMARTSAFE_DEPOSIT_ID%' 
						group by trnp.organization_id,trnp.rtl_loc_id,trnp.business_date) ss
					ON ss.organization_id = trn.organization_id
					AND ss.rtl_loc_id = trn.rtl_loc_id
					AND ss.business_date = trn.business_date
					--AND ss.wkstn_id = trn.wkstn_id
					--AND ss.trans_seq = trn.trans_seq
                WHERE
                    NOT EXISTS (
                        SELECT
                            NULL
                        FROM
                            dtv.trl_rtrans_lineitm_p trlp
                        WHERE
                                trlp.organization_id = ttl.organization_id
                            AND trlp.rtl_loc_id = ttl.rtl_loc_id
                            AND trlp.trans_seq = ttl.trans_seq
                            AND trlp.wkstn_id = ttl.wkstn_id
                            AND trlp.rtrans_lineitm_seq = ttl.rtrans_lineitm_seq
                            AND trlp.property_code = 'CPS_POSTED_TNDR_AMT'
                    )
                        AND trunc(ttl.create_date) = TO_DATE('${REPORT_DATE}', 'YYYY-MM-DD')
                        AND ttl.organization_id = '1'
                        AND ttl.rtl_loc_id LIKE '%'
                        AND ttl.amt != 0
                        AND EXISTS (
                        SELECT
                            1
                        FROM
                            dtv.trl_sale_lineitm tsl
                        WHERE
                                tsl.organization_id = ttl.organization_id
                            AND tsl.rtl_loc_id = ttl.rtl_loc_id
                            AND tsl.trans_seq = ttl.trans_seq
                            AND tsl.business_date = ttl.business_date
                            AND tsl.wkstn_id = ttl.wkstn_id
                            AND merch_level_1 != 'NP'
                    )
            )
        GROUP BY
            locationid,
            tenderid,
            billerid,
            deposits,
            trans_date,
            department,
			create_user_id
        HAVING
            SUM(amt) != 0
        UNION
        SELECT
            rtl_loc_id                       AS locationid,
            coalesce(SUM(difference),
                     0)                      AS amount,
            to_char(create_date, 'YYYYMMDD') AS trans_date,
            'OVER/SHORT'                     AS department,
            NULL                             AS billerid,
            tender_id                        AS payment_type,
            deposits,
			create_user_id
        FROM
            (
                SELECT
                     tender_id,
                     difference,
                   rtl_loc_id,
                    business_date,
                     create_date,
                    organization_id,
					(SELECT listagg(trnp.string_value,', ') 
                      within GROUP(ORDER BY trnp.string_value) 
                    FROM dtv.trn_trans_p trnp  
                    WHERE trnp.organization_id = dd.organization_id
                      AND trnp.rtl_loc_id = dd.rtl_loc_id
                      AND trnp.business_date = dd.business_date
                      AND trnp.wkstn_id = dd.wkstn_id
                      AND trnp.trans_seq=dd.trans_seq
                      AND trnp.property_code like 'SMARTSAFE_DEPOSIT_ID%') as deposits,
			          create_user_id
                FROM(
				SELECT
                    tttc.tndr_id         AS tender_id,
                    tttc.difference_amt  AS difference,
                    ttct.rtl_loc_id      AS rtl_loc_id,
                    ttct.business_date   AS business_date,
                    ttct.create_date     AS create_date,
                    ttct.organization_id AS organization_id,
                    ttct.wkstn_id ,
                    ttct.trans_seq,
					ttct.create_user_id
					FROM
                         dtv.tsn_session ts
                    INNER JOIN dtv.tsn_tndr_control_trans ttct ON ts.rtl_loc_id = ttct.rtl_loc_id
                                                                  AND ts.organization_id = ttct.organization_id
                                                                  AND ts.session_id = ttct.outbound_session_id
                    INNER JOIN dtv.tsn_tndr_tndr_count    tttc ON ttct.organization_id = tttc.organization_id
                                                               AND ttct.rtl_loc_id = tttc.rtl_loc_id
                                                               AND ttct.business_date = tttc.business_date
                                                               AND ttct.wkstn_id = tttc.wkstn_id
                                                               AND ttct.trans_seq = tttc.trans_seq
                                                               AND tttc.difference_amt <> 0
                                                               OR ( tttc.media_count <> 0
                                                                    AND ttct.trans_seq = tttc.trans_seq )
                    INNER JOIN dtv.tnd_tndr               ttd ON tttc.organization_id = ttd.organization_id
                                                   AND tttc.tndr_id = ttd.tndr_id
												   WHERE
                    upper(ttct.typcode) = 'ENDCOUNT'
				UNION 
				SELECT     'USD_CURRENCY'         AS tender_id,
                    ttp.decimal_value - ttct.amt  AS difference,
                    ttct.rtl_loc_id      AS rtl_loc_id,
                    ttct.business_date   AS business_date,
                    ttct.create_date     AS create_date,
                    ttct.organization_id AS organization_id,
                    ttct.wkstn_id ,
                    ttct.trans_seq,
					ttct.create_user_id
					FROM
                         dtv.tsn_session ts
                     JOIN dtv.tsn_tndr_control_trans ttct ON ts.rtl_loc_id = ttct.rtl_loc_id
                                                                  AND ts.organization_id = ttct.organization_id
                                                                  AND ts.session_id = ttct.outbound_session_id                    
					JOIN dtv.trn_trans_p ttp 
					ON 
					 ttct.organization_id = ttp.organization_id
                                                               AND ttct.rtl_loc_id = ttp.rtl_loc_id
                                                               AND ttct.business_date = ttp.business_date
                                                               AND ttct.wkstn_id = ttp.wkstn_id
                                                               AND ttct.trans_seq = ttp.trans_seq
															   AND ttp.property_code like 'SMARTSAFE_DEPOSIT_AMT%'
															   WHERE exists(select 1 from dtv.trn_trans_p tt
                                 where tt.organization_id = ttct.organization_id
                                                               AND tt.rtl_loc_id = ttct.rtl_loc_id
                                                               AND tt.business_date = ttct.business_date
                                                               AND tt.wkstn_id = ttct.wkstn_id
                                                               AND tt.trans_seq = ttct.trans_seq
                                                               AND tt.string_value ='Kiosk') and
                    upper(ttct.typcode) = 'ENDCOUNT'
				)dd
                ORDER BY
                    dd.tender_id
            )
        WHERE
                trunc(create_date) = TO_DATE('${REPORT_DATE}', 'YYYY-MM-DD')
            AND organization_id = '1'
            AND rtl_loc_id LIKE '%'
        GROUP BY
            tender_id,
            create_date,
            rtl_loc_id,
			deposits,
			create_user_id
        HAVING
            SUM(difference) != 0
        ORDER BY
            locationid,
            department
    ) rpt
WHERE
    EXISTS (SELECT 1 FROM smartsafe_store ss
        WHERE TO_CHAR(rpt.locationid) = ss.rtl_loc_id 
				or ss.rtl_loc_id = '*:*')