create index skew_idx on skew(skew); 
exec dbms_stats.gather_index_stats(user,'SKEW_IDX', no_invalidate => false); 
exec dbms_stats.gather_table_stats(user,'SKEW', no_invalidate => false); 

