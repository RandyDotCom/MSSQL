USE OPS 
GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo' AND SPECIFIC_NAME = N'Task_Manager' )
   DROP PROCEDURE dbo.Task_Manager
GO

-- =============================================
-- Author:		Randy
-- Create date: 20141122
-- Description:	Manages Tasks
-- =============================================
CREATE PROCEDURE dbo.Task_Manager 
	@Login varchar(max) = null, 
	@MaxWorkers int = null , 
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
, @value varchar(max), @ReturnCode int 
DECLARE @job_name varchar(max), @loginName varchar(50) , @lastidTask int 
DECLARE @jobId BINARY(16)
DECLARE @Job_id Uniqueidentifier 

delete from dbo.Tasks where RequestDate < DATEADD(Day,-14,convert(DATE,Getdate()))

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'YDPages' AND category_class=1)
BEGIN
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'YDPages'
END


select @MaxWorkers = isnull(@maxWorkers,isnull(dbo.fnSetting('Tasks','MaxWorkers'),10)) 
Select @value = cast(@MaxWorkers as char(2)) 
exec ops.dbo.Settings_put @context='Tasks',@name='MaxWorkers',@value= @value 

declare @enum  table (v int, d varchar(10))
insert into @enum (v,d) 
SELECT 0,'Failed'
union 
SELECT 1,'Succeeded'
union 
SELECT 2,'Retry'
union 
SELECT 3,'Canceled'

BEGIN -- Checking Workers 

		Select 
			Job.name [Job]
			, job.job_id
			, jh.step_id
			--, js.step_name
			, ja.start_execution_date 
			, ja.stop_execution_date
			, msdb.dbo.jobtime(jh.run_date, jh.run_time,null) StartTime
			, msdb.dbo.jobtime(jh.run_date, jh.run_time,jh.run_duration) EndTime 
			, jh.sql_severity 
			, jh.run_status 
			, jh.message
		 into #Workers
		from 
		  msdb.dbo.sysjobs job 
		  inner join msdb.dbo.sysjobactivity JA on JA.job_id = job.job_id
		  inner join msdb.dbo.sysjobhistory jh on jh.job_id=job.job_id and jh.step_id=0
		  --left outer join msdb.dbo.sysjobsteps js on js.job_id = job.job_id and jh.step_id=js.step_id
		where 1=1 
		 and job.name like 'worker_%'
		 
if @debug = 2 
Begin
 select SUBSTRING(Job,len('Worker_455AAD35-750A-4799-B45D-E485D7185FA0_+'),50)
--, [job_id]
--, [step_id]
, [start_execution_date]
, [stop_execution_date]
, [StartTime]
, [EndTime]
, [sql_severity]
, [run_status]
, [message]
FROM [#Workers]
  
return 1;
END 

select @ERM = null 
declare @WorkerCount int , @run_status tinyint  

DECLARE WorkerCursor CURSOR READ_ONLY FOR 
select Job, Job_id, run_status from #Workers where stop_execution_date is not null

OPEN WorkerCursor

FETCH NEXT FROM WorkerCursor INTO @job_name, @Job_id, @run_status 
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		Begin Try 

		Select @ERM = @job_name + ' ' + e.d from #Workers w, @enum e where w.run_status=e.v 
		Raiserror(@ERM,0,1) with nowait 


		update tk set TaskState=e.d, result=jh.message, endtime=getdate() 
		from 
		  msdb.dbo.sysjobs job 
		  inner join msdb.dbo.sysjobhistory jh on jh.job_id=job.job_id 
		  inner join @enum e on e.v=jh.run_status
		  inner join msdb.dbo.sysjobsteps js on js.job_id = job.job_id and jh.step_id=js.step_id
		  inner join ops.dbo.tasks tk on tk.job_id = job.job_id and tk.step_name = js.step_name
		where 1=1 
		 and job.job_id =@job_id 

		update ops.dbo.tasks set TaskState = 'Job Failed' 
		where job_id=@job_id 
		and TaskState not in (select d from @enum)

	
			delete from #Workers where job_id=@job_id 
			exec msdb.dbo.sp_delete_job @job_id=@job_id


		End Try

		Begin Catch

			select @ERM = ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			

			Raiserror(@ERM,@ERS,1)

			IF @ERS > 11 Goto OnErrorExitWorkerCursor

		End Catch

	END
	FETCH NEXT FROM WorkerCursor INTO @job_name,@Job_id,@run_status
END

OnErrorExitWorkerCursor: 

CLOSE WorkerCursor
DEALLOCATE WorkerCursor

if @erm is null and @debug>0 
  raiserror('Job Status Collection was empty',0,1) with nowait 
  

IF @ERS > 2 
 Return 0; 

declare @jobCount int 
select @WorkerCount = (select Count(*) from #Workers)
select @jobcount = (select count(*) from msdb.dbo.sysjobs where name like 'worker_%') 


if @debug =3 
Begin
	
  select @WorkerCount [WorkerCount]
  select * from #Workers 
  Return 1;
End 

END 

/* 
	TODO: Test for longRunning Jobs
 */ 

NextWorker: 


select @jobcount = (select count(*) from msdb.dbo.sysjobs where name like 'worker%') 
--select @jobCount, @WorkerCount 

if @jobCount >= @MaxWorkers 
  BEGIN
	Raiserror('Too many Workers Running',0,1) with nowait 
	Return 1;
  END
ELSE 
  Begin
	select @ERM = 'There are @WorkerCount Workers running and MaxWorkers is set to @MaxWorkers' 
	 SELECT @ERM= Replace(Replace(@ERM,'@MaxWorkers',convert(varchar(20),@MaxWorkers)),'@WorkerCount',convert(varchar(20),@WorkerCount))
	 Raiserror(@ERM,0,1) with nowait
  END
  
select @job_id = (select top 1 job_id from ops.dbo.Tasks where TaskState='New' and isnull(RequestDate,getdate()) <= Getdate())
 
if @job_id is null 
GOTO Report

select @loginName = (select top 1 loginName from ops.dbo.Tasks where job_id = @job_id) 
select @lastidTask = max(idTask) from ops.dbo.Tasks where job_id = @job_id

SELECT @job_name= 'Worker_'+ convert(varchar(100),@Job_id) + '_' + isnull(workername,@loginName)
  from dbo.Tasks where job_id=@job_id 

if @debug is not null
 Select @ERM = 'Creating Job ' + @job_name 
  raiserror(@ERM,0,1) 

--Return 1;


BEGIN TRANSACTION
SELECT @ReturnCode = 0

Update ops.dbo.Tasks Set TaskState='Building' where job_id = @job_id

EXEC @ReturnCode = msdb.dbo.sp_add_job @job_name=@job_name, 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Ops.dbo.Task_Manager Worker BEE', 
		@category_name=N'OpsWorker', 
		@owner_login_name= 'sa' ,
		@job_id = @jobId OUTPUT

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

DECLARE TaskCursor CURSOR READ_ONLY FOR 
select step_name,commandtype, command, idTask 
  from ops.dbo.Tasks
  where Job_id=@job_id 
  order by idTask 

DECLARE @step_name nvarchar(max),@commandtype varchar(10) , @command nvarchar(max)
, @step_id int =1, @idtask int 
, @on_success_action tinyint =3
, @spidlogger bit = null 

OPEN TaskCursor

FETCH NEXT FROM TaskCursor INTO @step_name,@commandtype,@command,@idtask
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

	if @idtask=@lastidTask 
		SELECT @on_success_action=1  

   /*  This caused blocking as the process is holding latches across databases longer than the execution of the task itself */
	--if @commandtype='TSQL' 
	--BEGIN
	----if CHARINDEX('@@spid',@command)=0 
	----begin
	----	select @command = --'update ops.dbo.Tasks set spid=@@spid where idTask=' + cast(@idTask as varchar(10)) + char(13)+ char(10) + 'GO' 
	----		+ char(13) + char(10) + isnull(@command,'Null @command')
	----		+ char(13)+ char(10) + 'GO' 
	----end
	--END

		if @debug>0 
		  raiserror(@command,0,1) 

EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=@step_name, 
		@step_id=@step_id, 
		@cmdexec_success_code=0, 
		@on_success_action=@on_success_action, 
		@on_success_step_id=0, 
		@on_fail_action=1, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, 
		@subsystem= @commandtype, 
		@command=@command, 
		@database_name = N'Ops', 
		@flags=16

	SELECT @step_id=@step_id+1

	IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

	Select @WorkerCount = @WorkerCount + 1 

	END
	FETCH NEXT FROM TaskCursor INTO @step_name,@commandtype,@command,@idtask
END

OnErrorExitCursor: 


CLOSE TaskCursor
DEALLOCATE TaskCursor

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1 
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

Declare @server_name varchar(max) 
  select @server_name = Convert(varchar(max),SERVERPROPERTY('Servername')) 

EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @server_name
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

Update ops.dbo.Tasks Set TaskState='Starting',Starttime=getdate(),[WorkerName]=@job_name, job_id=@jobId where job_id = @job_id

exec msdb.dbo.sp_start_job @job_id=@jobId 
 SELECT @jobID=Null

  Goto NextWorker  

Report:

if @debug > 1 
		Select 
			Job.name [Job]
			, job.job_id
			, jh.step_id
			--, js.step_name
			, ja.start_execution_date 
			, ja.stop_execution_date
			--, msdb.dbo.jobtime(jh.run_date, jh.run_time,null) StartTime
			--, msdb.dbo.jobtime(jh.run_date, jh.run_time,jh.run_duration) EndTime 
			, jh.sql_severity 
			, jh.run_status 
			, jh.message
		 --into #Workers
		from 
		  msdb.dbo.sysjobs job 
		  inner join msdb..sysjobactivity JA on JA.job_id = job.job_id
		  inner join msdb.dbo.sysjobhistory jh on jh.job_id=job.job_id and jh.step_id=0
		  --left outer join msdb.dbo.sysjobsteps js on js.job_id = job.job_id and jh.step_id=js.step_id
		where 1=1 
			and ja.stop_execution_date is null
		 and job.name like 'worker%'

if @debug is not null 
Begin

  select Tasks.WorkerName, step_name, TaskState,Result from OPs.dbo.tasks [Tasks] 
  where TaskState not in ('New','Succeeded') FOR XML Auto, root('OpsWorkload')

END

if @debug > 0 
BEGIN

 if exists (select * from ops.dbo.tasks where [TaskState] not in ('NEW','STARTED','Succeeded'))
 BEGIN
	
	Raiserror('There are Task Errors',0,1) with nowait
	
	 select @ERM = coalesce(@ERM + char(13) + char(10),'') + isnull(step_name,'null Step_name') + ' ' + isnull(taskState,'Null TaskState')
	 from ops.dbo.tasks where [TaskState] not in ('NEW','STARTED','Succeeded')

	 Raiserror(@ERM,0,1) with nowait
  --truncate table ops.dbo.tasks
 END
END 



END
GO

 --select * from ops.dbo.tasks t where t.workername like '%OST3TEST5SQL01'

IF 1=2
BEGIN
	--exec sp_help_executesproc @procname='Task_Manager'

DECLARE @Login varchar(max) = null 
	,@job_id varchar(100) = null 
	,@MaxWorkers int  = null 
	,@debug int  = null 

SELECT @Login = @Login --varchar
	,@job_id = @job_id --varchar
	,@MaxWorkers = 15 --int
	,@debug = 1 --int

EXECUTE [dbo].Task_Manager @Login = @Login --varchar
	,@MaxWorkers = @MaxWorkers --int
	,@debug = @debug --int

--  select Job_id, TaskState, step_name, Result from ops.dbo.Tasks 

		-- update ops.dbo.Tasks SET TaskState='NEW'

		--Select 
		--	Job.name [Job]
		--	, job.job_id
		--	, jh.step_id
		--	--, js.step_name
		--	, ja.start_execution_date 
		--	, ja.stop_execution_date
		--	, msdb.dbo.jobtime(jh.run_date, jh.run_time,null) StartTime
		--	, msdb.dbo.jobtime(jh.run_date, jh.run_time,jh.run_duration) EndTime 
		--	, jh.sql_severity 
		--	, jh.run_status 
		--	, jh.message
		--from 
		--  msdb.dbo.sysjobs job 
		--  inner join msdb..sysjobactivity JA on JA.job_id = job.job_id
		--  inner join msdb.dbo.sysjobhistory jh on jh.job_id=job.job_id and jh.step_id=0
		--  --left outer join msdb.dbo.sysjobsteps js on js.job_id = job.job_id and jh.step_id=js.step_id
		--where 1=1 
		-- and job.name like 'worker%'
		 


END
GO

if 1=2 
BEGIN
  exec ops.dbo.Task_Manager @maxWorkers=15 , @Debug=1

  exec msdb.dbo.sp_update_job @job_name='Ops TaskManager', @enabled=1 

END 
GO

