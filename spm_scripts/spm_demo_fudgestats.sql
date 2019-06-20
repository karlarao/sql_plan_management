exec dbms_stats.set_table_stats(user, 'SKEW', numrows => 1, numblks => 1, avgrlen => 1, no_invalidate => false); 

