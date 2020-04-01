DECLARE 
	@dbname nvarchar(300)=db_name()
	,@RunAgain bit = 1 
	,@ObjName nvarchar(max) = null 
	,@IndexName nvarchar(max) = null 
	,@debug int  = null 

Raiserror(@dbname,0,1) with nowait 

exec msdb.dbo.sp_update_job @Job_name='dbaindexOptimize', @Enabled=0 

EXEC msdb.dbo.sp_Stop_job @Job_name='dbaindexOptimize'--, @Enabled=0 

exec msdb.dbo.sp_start_job @Job_name='dbaindexOptimize', @step_name='Retasking' 

select distinct database_name from 
msdb.dbo.sysjobs job inner join msdb.dbo.sysjobsteps js on js.job_id = job.job_id
 


 Waitfor delay '00:00:00:100'

 select top 1 * from ops.dbo.CommandLog order by id desc 