create table skew as select rownum all_distinct, 10000 skew from dual connect by level <= 10000; 
update skew set skew=all_distinct where rownum<=10;
select skew, count(*) from skew group by skew order by skew; 

