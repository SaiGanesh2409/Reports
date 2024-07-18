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
    to_char(tt.create_date, 'YYYY-MM-DD') 				   AS trans_date,
    tt.rtl_loc_id 										   AS store#,
    tttc.amt 											   AS change_fund_order_amount_received,
    tttc.deposit_amt 									   AS amount_deposited,
    (SELECT listagg(trnp.string_value,', ') 
	  within GROUP(ORDER BY trnp.string_value) 
     FROM dtv.trn_trans_p trnp  
	 WHERE tttc.organization_id = trnp.organization_id
      AND tttc.rtl_loc_id = trnp.rtl_loc_id
      AND tttc.business_date = trnp.business_date
      AND tttc.wkstn_id = trnp.wkstn_id
      AND tttc.trans_seq = trnp.trans_seq
      AND trnp.property_code like 'SMARTSAFE_DEPOSIT_ID%') smartsafe_transaction#,
     tttc.difference_amt 								   AS variance,
     ttct.reascode 										   AS reason_code,
     ttn.note 											   AS comments
  FROM dtv.trn_trans tt
  JOIN dtv.tsn_tndr_control_trans ttct 
    ON tt.organization_id = ttct.organization_id
    AND tt.rtl_loc_id = ttct.rtl_loc_id
    AND tt.business_date = ttct.business_date
    AND tt.wkstn_id = ttct.wkstn_id
    AND tt.trans_seq = ttct.trans_seq
    AND /*UPPER*/ tt.trans_typcode = 'TENDER_CONTROL'
    AND /*UPPER*/ tt.trans_statcode = 'COMPLETE'
    AND /*UPPER*/ ttct.typcode = 'SAFE_BAG_ADJUST'
    AND /*UPPER*/ ttct.inbound_tndr_repository_id = 'CHANGEFUND'
  JOIN dtv.tsn_tndr_tndr_count tttc 
    ON tt.organization_id = tttc.organization_id
    AND tt.rtl_loc_id = tttc.rtl_loc_id
    AND tt.business_date = tttc.business_date
    AND tt.wkstn_id = tttc.wkstn_id
    AND tt.trans_seq = tttc.trans_seq   
  LEFT JOIN dtv.trn_trans_notes ttn
    ON tt.organization_id = ttn.organization_id
    AND tt.rtl_loc_id = ttn.rtl_loc_id
    AND tt.business_date = ttn.business_date
    AND tt.wkstn_id = ttn.wkstn_id
    AND tt.trans_seq = ttn.trans_seq
  WHERE EXISTS (SELECT 1 FROM smartsafe_store ss
        WHERE TO_CHAR(tt.rtl_loc_id) = ss.rtl_loc_id 
				or ss.rtl_loc_id = '*:*')  -- this is for the case which is pushed for global
   AND TRUNC(tt.create_date) = TO_DATE('${REPORT_DATE}', 'YYYY-MM-DD') --date criteria
   AND tt.organization_id = '1'
   AND tt.rtl_loc_id LIKE '%'