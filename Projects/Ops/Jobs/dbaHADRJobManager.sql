USE [msdb]
GO

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'dbaHADRJobManager')
EXEC msdb.dbo.sp_delete_job @job_name=N'dbaHADRJobManager', @delete_unused_schedule=1
GO

if object_id('master.sys.dm_hadr_database_replica_cluster_states') is null 
  GOTO QuitWithRollback 

if not exists (SELECT 1  FROM master.sys.dm_hadr_database_replica_cluster_states)
  GOTO QuitWithRollback

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0


IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'YDPages' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'YDPages'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
select @jobId = job_id from msdb.dbo.sysjobs where (name = N'dbaHADRJobManager')
if (@jobId is NULL)
BEGIN
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dbaHADRJobManager', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Manages the SQL Agent Jobs for the HADR Implementation', 
		@category_name=N'YDPages', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END
/****** Object:  Step [HADR Job Manager]    Script Date: 11/10/2016 10:54:01 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'HADR Job Manager', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
declare @ERM varchar(max) , @StartTime datetime = getdate(), @debug int = null 
while (1 = 1 )
Begin 
	select @ERM = convert(varchar(max),getdate(),20)
	if @debug=1
	Raiserror(@ERM,0,1) with nowait 
	
	EXECUTE [ops].[dbo].HADRJobManager  
	
	WAITFOR DELAY ''00:01:00''

	if @StartTime < DATEADD(hour,-1,getdate())
		GOTO ExitEndlessWhileLoop
END
ExitEndlessWhileLoop: ', 
		@database_name=N'Ops', 
		-- @output_file_name=N'\\pc-prep-sql9\SQLBackups\dbaHADRJobManager.log', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [HADR Sync Kit]    Script Date: 11/10/2016 10:54:01 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 2)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'HADR Sync Kit', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec Ops.dbo.HADRSyncKit', 
		@database_name=N'Ops', 
		-- @output_file_name=N'\\pc-prep-sql9\SQLBackups\dbaHADRJobManager.log', 
		@flags=6
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Start Every Hour, Retest Every Minute', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=1, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20100510, 
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


