
-- GENERATE DATA

-- generate data
create table skew as select rownum all_distinct, 10000 skew from dual connect by level <= 10000; 
update skew set skew=all_distinct where rownum<=10;
select skew, count(*) from skew group by skew order by skew; 

-- setup
create index skew_idx on skew(skew); 
exec dbms_stats.gather_index_stats(user,'SKEW_IDX', no_invalidate => false); 
exec dbms_stats.gather_table_stats(user,'SKEW', no_invalidate => false); 

-- query
select * from skew where skew=10000;
select * from table(dbms_xplan.display_cursor);
select * from skew where skew=3;
select * from table(dbms_xplan.display_cursor);

-- set stats to make full scan on skew=1
exec dbms_stats.set_table_stats(user, 'SKEW', numrows => 1, numblks => 1, avgrlen => 1, no_invalidate => false);  

--cleanup
--drop table skew;
drop index skew_idx;
exec dbms_stats.delete_table_stats(user,'SKEW'); 
exec dbms_stats.gather_table_stats(user,'SKEW',method_opt=>'for columns skew size 1'); 


-- FREQUENCY HISTOGRAM

	exec dbms_stats.gather_table_stats(user,'SKEW',method_opt=>'for columns skew size 11'); 
	 
	select column_name,endpoint_number,endpoint_value from user_tab_histograms where table_name='SKEW' and column_name='SKEW'; 
	 
	COLUMN_NAME ENDPOINT_NUMBER ENDPOINT_VALUE 
	------------- --------------- -------------- 
	SKEW 1 1 
	SKEW 2 2 
	SKEW 3 3 
	SKEW 4 4 
	SKEW 5 5 
	SKEW 6 6 
	SKEW 7 7 
	SKEW 8 8 
	SKEW 9 9 
	SKEW 10 10 
	SKEW 10000 10000 
	 
	11 rows selected. 


	set term off
	select * from skew where skew=10000; 
	select * from skew where skew=1; 
	select * from table(dbms_xplan.display_cursor);

-- HEIGHT-BALANCED HISTOGRAM

	exec dbms_stats.gather_table_stats(user,'SKEW',method_opt=>'for columns skew size 5'); 
	 
	PL/SQL procedure successfully completed. 
	 
	test@ORADB10G> select table_name, column_name,endpoint_number,endpoint_value from 
	user_tab_histograms where table_name='SKEW' and column_name='SKEW'; 
	 
	TABLE_NAME COLUMN_NAME ENDPOINT_NUMBER ENDPOINT_VALUE 
	------------- ------------- --------------- -------------- 
	HISTOGRAM SKEW 0 1 
	HISTOGRAM SKEW 5 10000 

	test@ORADB10G> SELECT bucket_number, max(skew) AS endpoint_value 
	 2 FROM ( 
	 3 SELECT skew, ntile(5) OVER (ORDER BY skew) AS bucket_number 
	 4 FROM skew) 
	 5 GROUP BY bucket_number 
	 6 ORDER BY bucket_number; 
	 
	BUCKET_NUMBER ENDPOINT_VALUE 
	------------- -------------- 
	 1 10000 
	 2 10000 
	 3 10000 
	 4 10000 
	 5 10000 





