

-- get the signature of SQL_ID, baselines use EXACT_MATCHING_SIGNATURE - (spm_find_sql.sql)
set verify off
col exact_matching_signature format 999999999999999999999999999
col force_matching_signature format 999999999999999999999999999
select sql_id, child_number, plan_hash_value, exact_matching_signature, force_matching_signature, substr(sql_text,1,35) sql_text
from v$sql 
where upper(sql_text) like upper(nvl('&sql_text',sql_text))
and sql_text not like '%from v$sql where sql_text like nvl(%'
and sql_id like nvl('&sql_id',sql_id)
order by 1,2;

-- query all baselines - (spm_baselines.sql)
set verify off
col parsing_schema format a8
col created format a20
col sql_handle format a25
col sql_text format a35
col origin format a8
SELECT parsing_schema_name parsing_schema, TO_CHAR(created,'MM/DD/YY HH24:MI:SS') created, plan_name, sql_handle, substr(sql_text,1,35) sql_text, optimizer_cost, enabled, accepted, fixed, reproduced, origin 
FROM dba_sql_plan_baselines order by 2,4 asc;

-- find baselines used by SQL_ID - (spm_sqlid.sql)
set verify off
col parsing_schema format a8
col created format a10
SELECT parsing_schema_name parsing_schema, created, plan_name, sql_handle, sql_text, optimizer_cost, enabled, accepted, fixed, origin
FROM dba_sql_plan_baselines
WHERE signature IN (SELECT exact_matching_signature FROM v$sql WHERE sql_id like nvl('&sql_id',sql_id))
/

-- find just the sql 
set verify off
col parsing_schema format a8
col created format a20
col sql_handle format a20
col sql_text format a35
col child format 99999
col exec format 99999
SELECT b.parsing_schema_name parsing_schema, TO_CHAR(created,'MM/DD/YY HH24:MI:SS') created, b.plan_name, b.sql_handle, s.sql_id, s.child_number child, s.plan_hash_value, s.executions exec, b.optimizer_cost, b.enabled, b.accepted, b.fixed, b.origin
FROM v$sql s, dba_sql_plan_baselines b
WHERE s.exact_matching_signature = b.signature(+)
AND s.sql_plan_baseline = b.plan_name(+)
AND upper(s.sql_text) like upper('&sql_text')
/

-- View the exectution plan stored in baselines (format options - basic, typical, all) - (spm_plans.sql)
set lines 200
set verify off
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY_SQL_PLAN_BASELINE(sql_handle=>'&sql_handle', format=>'basic'));

-- View the execution plan of SQL_ID
set lines 200
set verify off
select * from table(dbms_xplan.display_cursor('&sql_id','&child_no','typical'))
/
set lines 200
set verify off
select * from table(dbms_xplan.display_cursor('&sql_id','&child_no','advanced +peeked_binds'))
/




-- evolve - (spm_evolve.sql)
set verify off
SET SERVEROUTPUT ON
SET long 1000000
SET longchunksize 300
set lines 900
DECLARE
report clob;
BEGIN
report := DBMS_SPM.EVOLVE_SQL_PLAN_BASELINE(
sql_handle => '&sql_handle', 
verify => '&verify', 
commit => '&commit');
DBMS_OUTPUT.PUT_LINE(report);
END;
/


-- alter baseline, FIXED - (spm_fixed.sql)
set verify off
declare
myplan pls_integer;
begin
myplan:=DBMS_SPM.ALTER_SQL_PLAN_BASELINE (sql_handle => '&sql_handle',plan_name  => '&plan_name',attribute_name => 'FIXED',   attribute_value => '&YES_OR_NO');
end;
/

-- alter baseline, DISABLE - (spm_enable.sql)
set verify off
declare
myplan pls_integer;
begin
myplan:=DBMS_SPM.ALTER_SQL_PLAN_BASELINE (sql_handle => '&sql_handle',plan_name  => '&plan_name',attribute_name => 'ENABLED',   attribute_value => '&YES_OR_NO');
end;
/





-- drop specific baseline - (spm_drop_baseline.sql)
set verify off
DECLARE
  plans_dropped    PLS_INTEGER;
BEGIN
  plans_dropped := DBMS_SPM.drop_sql_plan_baseline (
sql_handle => '&sql_handle',
plan_name  => '&plan_name');
DBMS_OUTPUT.put_line(plans_dropped);
END;
 /



-- drop all baselines - (spm_drop_all_baseline.sql)
SET SERVEROUT ON;
DECLARE
  x NUMBER;
  y NUMBER := 0;
BEGIN
  FOR i IN (SELECT DISTINCT sql_handle, plan_name FROM dba_sql_plan_baselines)
  LOOP
    x := DBMS_SPM.DROP_SQL_PLAN_BASELINE(i.sql_handle, i.plan_name);
    y := y + x;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('plans deleted: '||y);
END;
/
SET SERVEROUT OFF;




-- spm config parameters (spm_smb_configure.sql)
set lines 300
set verify off
SELECT PARAMETER_NAME, PARAMETER_VALUE FROM DBA_SQL_MANAGEMENT_CONFIG;
BEGIN
  DBMS_SPM.configure('space_budget_percent', &space_budget_percent);
  DBMS_SPM.configure('plan_retention_weeks', &plan_retention_weeks);
END;
/
SELECT PARAMETER_NAME, PARAMETER_VALUE FROM DBA_SQL_MANAGEMENT_CONFIG;









