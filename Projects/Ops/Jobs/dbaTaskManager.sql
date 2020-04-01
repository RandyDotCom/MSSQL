USE [msdb]
GO

IF NOT EXISTS (SELECT name FROM msdb.dbo.sysoperators WHERE name = N'Randy')
EXEC msdb.dbo.sp_add_operator @name=N'Randy', 
		@enabled=1, 
		@weekday_pager_start_time=90000, 
		@weekday_pager_end_time=180000, 
		@saturday_pager_start_time=90000, 
		@saturday_pager_end_time=180000, 
		@sunday_pager_start_time=90000, 
		@sunday_pager_end_time=180000, 
		@pager_days=0, 
		@email_address=N'Randy@ydpages.info'
GO


/****** Object:  Job [dbaTaskManager]    Script Date: 4/11/2018 9:39:58 AM ******/
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'dbaTaskManager')
EXEC msdb.dbo.sp_delete_job @job_name=N'dbaTaskManager', @delete_unused_schedule=1
GO

/****** Object:  Job [dbaTaskManager]    Script Date: 4/11/2018 9:39:58 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'OpsWorker' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'OpsWorker'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'YDPages' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'YDPages'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
select @jobId = job_id from msdb.dbo.sysjobs where (name = N'dbaTaskManager')
if (@jobId is NULL)
BEGIN
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dbaTaskManager', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Runs Tasks', 
		@category_name=N'YDPages', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'Randy', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END
/****** Object:  Step [Schedule from Opshealth]    Script Date: 4/11/2018 9:39:58 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Task Load Evaluation', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'declare @TaskCount int , @schedule_ID int , @ERM nvarchar(max) 

select @TaskCount = count(*) from ops.dbo.Tasks where TaskState=''New''
	select @schedule_id = [schedule_id] from msdb.dbo.sysschedules where name=''dbaTaskManager Rush'' 

DECLARE @MAxThreads tinyint, @minthreads tinyint 

select 
	@MaxThreads = ops.dbo.fnSetting(''TaskManager'',''MaxThreads'')
  , @minthreads = ops.dbo.fnSetting(''TaskManager'',''MinThreads'')

if @MAxThreads is null 
  exec ops.dbo.Settings_put @context=''TaskManager'', @name=''MaxThreads'', @value=30 

if @minthreads is null 
  exec ops.dbo.Settings_put @context=''TaskManager'', @name=''MinThreads'', @value=15 


if @TaskCount > @MAxThreads 
Begin 
	EXEC msdb.dbo.sp_update_schedule @schedule_id=@schedule_id, @enabled=1
 end

IF @TaskCount between @minthreads and @MAxThreads
Begin 
	Raiserror(''Faster Schedule'',0,1)
	EXEC msdb.dbo.sp_update_schedule @schedule_id=@schedule_id, @enabled=0
end  

if @TaskCount <= @minthreads
Begin 
	Raiserror(''Slow and back to Stamping'',0,1)
	EXEC msdb.dbo.sp_update_schedule @schedule_id=@schedule_id, @enabled=0
END 


 select @ERM = ''@TaskCount:'' + isnull(cast(@TaskCount as varchar(100)),''Null'') + ''
 @minthreads:'' + isnull(cast(@minthreads as varchar(100)),''Null'') + ''
 @MAxThreads:'' + isnull(cast(@MAxThreads as varchar(100)),''Null'') + ''''

 Raiserror(@ERM,0,1)
', 
		@database_name=N'Ops', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Run dbaTaskManager]    Script Date: 4/11/2018 9:39:58 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 2)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Run dbaTaskManager', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
		EXECUTE [dbo].Task_Manager @debug = null 
--, @maxworkers=10
', 
		@database_name=N'Ops', 
		@flags=12
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dbaTaskManager Rush', 
		@enabled=0, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=2, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20170611, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959 
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dbaTaskManager', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=10, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20141122, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959 
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO


