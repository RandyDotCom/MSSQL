use msdb
go
if 1=2
BEGIN
  /* Makes the Changes */
  Exec ops.dbo.HADRJobManager 
/* Reports the Errors */  
  
exec msdb.dbo.sp_start_job @job_Name='dbaHADRJobManager', @step_name ='HADR Sync Kit'
END 


select 
  job.name [Job]
  , job.enabled [JobEnabled]
  , isnull(sc.name,'NONE') [Schedule]
  , sc.[enabled] [SchedEnabled] 
  , sp.step_name 
  , sp.database_name 
  , db.HARole
  , CASE when db.HARole = 'PRIMARY' and sc.enabled=1 then 'Good'
		when db.HARole != 'PRIMARY' and sc.enabled != 1 then 'Good'
        else 'Error' end [HADRManagerResult]
From 
  dbo.sysjobs Job 
  left outer join dbo.sysjobsteps sp on sp.job_id = job.job_id
  left outer join dbo.sysjobschedules js on js.job_id = job.job_id 
  left outer join dbo.sysschedules sc on sc.schedule_id = js.schedule_id
  inner join ops.dbo.Database_status_v db on db.DatabaseName = sp.database_name 
Where 1=1 
  and HAROLE is not null 
