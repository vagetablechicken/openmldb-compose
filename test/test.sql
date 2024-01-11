show components;
set @@sync_job=true;
select 1 into outfile 'hdfs://namenode:19000/test/' options(mode='overwrite');