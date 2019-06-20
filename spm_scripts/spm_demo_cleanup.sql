drop index skew_idx;
exec dbms_stats.delete_table_stats(user,'SKEW'); 
exec dbms_stats.gather_table_stats(user,'SKEW',method_opt=>'for columns skew size 1');

