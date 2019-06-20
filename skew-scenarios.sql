

Step 1) generate data (spm_demo_gendata.sql)
create table skew as select rownum all_distinct, 10000 skew from dual connect by level <= 10000; 
update skew set skew=all_distinct where rownum<=10;
select skew, count(*) from skew group by skew order by skew; 

Step 2) create index gather stats (spm_demo_createindex.sql)
create index skew_idx on skew(skew); 
exec dbms_stats.gather_index_stats(user,'SKEW_IDX', no_invalidate => false); 
exec dbms_stats.gather_table_stats(user,'SKEW', no_invalidate => false); 

Step 3) query (spm_demo_query.sql)
select * from skew where skew=3;
select * from table(dbms_xplan.display_cursor);

Step 4) set stats to make full scan on skew=1 (spm_demo_fudgestats.sql)
exec dbms_stats.set_table_stats(user, 'SKEW', numrows => 1, numblks => 1, avgrlen => 1, no_invalidate => false);  

Step 5) cleanup (spm_demo_cleanup.sql)
drop index skew_idx;
exec dbms_stats.delete_table_stats(user,'SKEW'); 
exec dbms_stats.gather_table_stats(user,'SKEW',method_opt=>'for columns skew size 1');


Do the following to demo the evolution process and the rest of the concepts:
1) Create the logon trigger from the "Enabling and Capture" section above, change the parsing schema accordingly
2) Go to Appendix B and execute the step 1 (spm_demo_gendata.sql) to create the table and generate the data 
3) Execute the step 3 (spm_demo_query.sql) twice to automatically create the 1st baseline 
4) Execute the step 2 (spm_demo_createindex.sql) to create the index and gather the stats
5) Execute the step 3 (spm_demo_query.sql) twice to automatically create the 2nd baseline


spm_demo_gendata.sql
spm_demo_createindex.sql
spm_demo_query.sql
spm_demo_fudgestats.sql
spm_demo_cleanup.sql


-- Gather Stats
------------------
The new plans created as a result of gathering statistics are stored as non-accepted plans. These plans have to be manually evolved to be used. 

@spm_demo_cleanup.sql
@spm_drop_all_baseline.sql
@spm_demo_createindex.sql
@spm_demo_fudgestats.sql
@spm_demo_query.sql
@spm_demo_query.sql       <-- first baseline created (full scan)
@spm_baselines.sql
@spm_demo_createindex.sql <-- gather stats, index add
@spm_demo_query.sql       <-- new baseline created (index scan), but still first baseline is used
@spm_baselines.sql
@spm_evolve.sql



-- Index Add
------------------
When adding indexes, new plans will be stored as non-accepted plans. Same as when gathering statistics, these plans have to be manually evolved to be used. 

@spm_demo_cleanup.sql
@spm_drop_all_baseline.sql
@spm_demo_query.sql
@spm_demo_query.sql       <-- first baseline create (full scan)
@spm_baselines.sql
@spm_demo_createindex.sql <-- gather stats, index add
@spm_demo_query.sql       <-- new baseline created (index scan), but still first baseline is used
@spm_baselines.sql
@spm_evolve.sql



-- Index Drop
------------------
If the execution plan cannot be reproduced due to an index drop, then the baselines cannot be used even if it's ACCEPTED. If there are no other ACCEPTED plans that suits the new execution plan. Then a new baseline will be created and used (with full scan). If the index gets recreated then the old baseline (index scan) will be used. 

@spm_demo_cleanup.sql
@spm_drop_all_baseline.sql
@spm_demo_createindex.sql
@spm_demo_query.sql
@spm_demo_query.sql       <-- first baseline create (index scan)
@spm_baselines.sql
@spm_plans.sql
@spm_demo_cleanup.sql
@spm_demo_query.sql
@spm_baselines.sql



-- Alter objects – add/drop/rename/modify column
------------------
When new columns are added or dropped then it has no effect on the baselines. 
When the columns and objects that are being referenced on the query are renamed,dropped, or modified (change of data type) then the baselines will not be used. 

-- ADD COLUMN
@spm_demo_cleanup.sql
@spm_drop_all_baseline.sql
@spm_demo_createindex.sql
@spm_demo_query.sql
@spm_demo_query.sql                              <-- first baseline create (index scan)
@spm_baselines.sql
ALTER TABLE skew ADD skew2 varchar2(50);         <-- no effect
@spm_demo_query.sql
@spm_baselines.sql

-- DROP COLUMN
ALTER TABLE skew DROP COLUMN skew2;              <-- no effect
@spm_demo_query.sql
@spm_baselines.sql

-- RENAME COLUMN
ALTER TABLE skew RENAME COLUMN skew to skew2;     
select * from skew where skew2=3;
select * from skew where skew2=3;                <-- baseline will not be used, a new one will be created
@spm_baselines.sql

-- RENAME TABLE
ALTER TABLE skew RENAME TO skew2;                
select * from skew2 where skew2=3;
select * from skew2 where skew2=3;               <-- baseline will not be used, a new one will be created
@spm_baselines.sql

-- REVERT TO OLD COLUMN/TABLE NAMES
ALTER TABLE skew2 RENAME COLUMN skew2 to skew; 
ALTER TABLE skew2 RENAME TO skew; 

-- MODIFY COLUMN FROM NUMBER TO VARCHAR2
truncate table skew; 
ALTER TABLE skew MODIFY skew varchar2(100) not null;
insert into skew select rownum all_distinct, 10000 skew from dual connect by level <= 10000; 
update skew set skew=all_distinct where all_distinct in (1,2,3,4,5,6,7,8,9,10); 
select skew, count(*) from skew group by skew order by skew; 
@spm_demo_query.sql                              <-- this created a new baseline (full scan)
@spm_baselines.sql

-- MODIFY COLUMN - REVERT TO NUMBER
truncate table skew; 
ALTER TABLE skew MODIFY skew number;
insert into skew select rownum all_distinct, 10000 skew from dual connect by level <= 10000; 
update skew set skew=all_distinct where all_distinct in (1,2,3,4,5,6,7,8,9,10); 
select skew, count(*) from skew group by skew order by skew; 
@spm_demo_query.sql                              <-- reverted back to the old baseline (index scan)
@spm_baselines.sql

-- MODIFY COLUMN - ALTER NUMBER COLUMN
truncate table skew; 
ALTER TABLE skew MODIFY skew number(30);
insert into skew select rownum all_distinct, 10000 skew from dual connect by level <= 10000; 
update skew set skew=all_distinct where all_distinct in (1,2,3,4,5,6,7,8,9,10); 
select skew, count(*) from skew group by skew order by skew; 
@spm_demo_query.sql                              <-- still used the old baseline (index scan)
@spm_baselines.sql



-- Drop and recreate a table
------------------
When a table is dropped the ACCEPTED plans still remains in the repository. On the recreation of the table all the corresponding objects (indexes) that are referenced on the baseline also has to be recreated, else the old baseline will not be used and a new one will be created (and used). 

@spm_demo_cleanup.sql
@spm_drop_all_baseline.sql
@spm_demo_createindex.sql
@spm_demo_query.sql
@spm_demo_query.sql       <-- first baseline create (index scan)
@spm_baselines.sql
drop table skew cascade constraints;
@spm_demo_gendata.sql
@spm_demo_query.sql       <-- without creating the indexes a new baseline is created (with full scan)
@spm_demo_createindex.sql <-- recreate the indexes
@spm_demo_query.sql       <-- old baseline used



-- Truncate a table
------------------
When a table is truncated, the baselines will still be used

@spm_demo_cleanup.sql
@spm_drop_all_baseline.sql
@spm_demo_createindex.sql
@spm_demo_query.sql
@spm_demo_query.sql       <-- first baseline create (index scan)
@spm_baselines.sql
truncate table skew;
@spm_demo_query.sql       <-- the baseline is still used (index scan)
@spm_baselines.sql



-- Change optimizer environment
------------------
When there is a change in the optimizer environment then the new plans will be stored as non-accepted plans. Same as when gathering statistics and adding indexes, these plans have to be manually evolved to be used. 

@spm_demo_cleanup.sql
@spm_drop_all_baseline.sql
@spm_demo_createindex.sql
@spm_demo_query.sql
@spm_demo_query.sql       <-- first baseline create (index scan)
@spm_baselines.sql
alter session set optimizer_index_cost_adj=10000;   <-- influence full scans
@spm_demo_query.sql       <-- new baseline create (full scan)
@spm_baselines.sql



-- Adaptive Cursor Sharing test case

variable b varchar2(19);
exec :b := '&1'
select * from skew where skew=:b;

exec dbms_stats.gather_table_stats('STELIOS','ACS', estimate_percent=>100, method_opt=>'FOR ALL COLUMNS SIZE 254');

select count(object_type) from acs where object_type=:b;
select IS_BIND_SENSITIVE S, IS_BIND_AWARE A from v$sqlarea where sql_id=' 5fvxn411s48p0';



-- Cardinality Feedback test case


show parameter optimizer_dynamic_sampling
NAME                                 TYPE        VALUE
------------------------------------ ----------- --------------
optimizer_dynamic_sampling           integer     4




-- Backup, Drop, Restore baseslines

alter system set optimizer_capture_sql_plan_baselines=true;
alter system set optimizer_use_sql_plan_baselines=true;



1) Create the staging table and pack the baselines into the staging table

var n NUMBER 
EXEC dbms_spm.create_stgtab_baseline('SPM_STAGE2'); 
EXEC :n := dbms_spm.pack_stgtab_baseline('SPM_STAGE2');

2) Query the packed baselines 

SET long 1000000
SET longchunksize 30
colu sql_text format a30
colu optimizer_cost format 999,999 heading 'Cost'
colu buffer_gets    format 999,999 heading 'Gets'
SELECT sql_text, OPTIMIZER_COST, CPU_TIME, BUFFER_GETS, COMP_DATA FROM SPM_STAGE2;

3) Export the table and backup the dump file

4) Drop all baselines 

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


4) To restore, locate the backup dump file and import the staging table then unpack the baselines 

var n NUMBER 
exec :n:=DBMS_SPM.UNPACK_STGTAB_BASELINE('SPM_STAGE2');



-- Move baselines to another database


1) Create the staging table and pack the baselines into the staging table

var n NUMBER 
EXEC dbms_spm.create_stgtab_baseline('SPM_STAGE'); 
EXEC :n := dbms_spm.pack_stgtab_baseline('SPM_STAGE');

2) Query the packed baselines 

SET long 1000000
SET longchunksize 30
colu sql_text format a30
colu optimizer_cost format 999,999 heading 'Cost'
colu buffer_gets    format 999,999 heading 'Gets'
SELECT sql_text, OPTIMIZER_COST, CPU_TIME, BUFFER_GETS, COMP_DATA FROM SPM_STAGE;

3) Export the table and copy the dump file to the destination environment

4) Import the table on the destination environment, and unpack the baselines 

var n NUMBER 
exec :n:=DBMS_SPM.UNPACK_STGTAB_BASELINE('SPM_STAGE');

5) Verify 

col parsing_schema format a8
col created format a20
col sql_handle format a25
col sql_text format a35
col origin format a8
SELECT parsing_schema_name parsing_schema, TO_CHAR(created,'MM/DD/YY HH24:MI:SS') created, plan_name, sql_handle, substr(sql_text,1,35) sql_text, optimizer_cost, enabled, accepted, fixed, reproduced, origin
FROM dba_sql_plan_baselines order by 2,4 asc;



-- Loading Hinted Execution Plans into SQL Plan Baseline 


















