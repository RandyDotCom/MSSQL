USE [msdb]
GO

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'WTTCaptureDeadlocks')
	EXEC msdb.dbo.sp_delete_job @job_name=N'WTTCaptureDeadlocks',  @delete_unused_schedule=1
GO


--/****** Object:  Job [WTTCaptureDeadlocks]    Script Date: 8/17/2017 9:15:56 AM ******/
--BEGIN TRANSACTION
--DECLARE @ReturnCode INT
--SELECT @ReturnCode = 0
--/****** Object:  JobCategory [QBIBEE]    Script Date: 8/17/2017 9:15:56 AM ******/
--IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'QBIBEE' AND category_class=1)
--BEGIN
--EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'QBIBEE'
--IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

--END

--DECLARE @jobId BINARY(16)
--select @jobId = job_id from msdb.dbo.sysjobs where (name = N'WTTCaptureDeadlocks')
--if (@jobId is NULL)
--BEGIN
--EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'WTTCaptureDeadlocks', 
--		@enabled=1, 
--		@notify_level_eventlog=2, 
--		@notify_level_email=0, 
--		@notify_level_netsend=0, 
--		@notify_level_page=0, 
--		@delete_level=0, 
--		@description=N'Job for responding to DEADLOCK_GRAPH events', 
--		@category_name=N'QBIBEE', 
--		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
--IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

--END
--/****** Object:  Step [HADRSecNoRun]    Script Date: 8/17/2017 9:15:57 AM ******/
--IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
--EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'HADRSecNoRun', 
--		@step_id=1, 
--		@cmdexec_success_code=0, 
--		@on_success_action=3, 
--		@on_success_step_id=0, 
--		@on_fail_action=2, 
--		@on_fail_step_id=0, 
--		@retry_attempts=0, 
--		@retry_interval=0, 
--		@os_run_priority=0, @subsystem=N'TSQL', 
--		@command=N'
--DECLARE @job_name varchar(255)   
--SET @job_name =  ''WTTCaptureDeadlocks''
-- exec OPS.dbo.DBA_HADRSecNoRun @JOB_NAME = @job_name', 
--		@database_name=N'OPS', 
--		@flags=0
--IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
--/****** Object:  Step [Insert Graph into WTTDeadlockEvents]    Script Date: 8/17/2017 9:15:57 AM ******/
--IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 2)
--EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Insert Graph into WTTDeadlockEvents', 
--		@step_id=2, 
--		@cmdexec_success_code=0, 
--		@on_success_action=1, 
--		@on_success_step_id=0, 
--		@on_fail_action=2, 
--		@on_fail_step_id=0, 
--		@retry_attempts=0, 
--		@retry_interval=0, 
--		@os_run_priority=0, @subsystem=N'TSQL', 
--		@command=N'SET NOCOUNT ON;
--SET QUOTED_IDENTIFIER ON;

----Capture deadlock into temp table
--CREATE TABLE #DeadlockTemp (DeadlockGraph xml)
--INSERT INTO #DeadlockTemp (DeadlockGraph)
--VALUES (N''$(ESCAPE_SQUOTE(WMI(TextData)))'')

----Parse Database name from Deadlock Graph XML
--DECLARE @Database varchar(100);
--SELECT TOP(1)@Database=T.c.value(N''@objectname'', N''varchar(100)'')
--FROM #DeadlockTemp
--CROSS APPLY DeadlockGraph.nodes(''/TextData/deadlock-list/deadlock/resource-list/*'') AS T(c)

----Parse Database name from string
--SELECT @Database = SUBSTRING( @Database, 0, CHARINDEX(''.'', @Database) )

----Create Insert Command into target Database
--declare @cmd varchar(2000)
--select 	@cmd =''IF OBJECT_ID('''''' + @Database + ''.dbo.WTTDeadlockEvents'''', ''''U'''') IS NOT NULL'' + CHAR(13)
--select 	@cmd = @cmd + ''INSERT INTO '' + @Database + ''.dbo.WTTDeadlockEvents (AlertTime, DeadlockGraph)''
--select 	@cmd = @cmd + ''SELECT GETUTCDATE(), DeadlockGraph FROM #DeadlockTemp''
--exec (@cmd)', 
--		@database_name=N'master', 
--		@flags=0
--IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
--EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
--IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
--EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
--IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
--COMMIT TRANSACTION
--GOTO EndSave
--QuitWithRollback:
--    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
--EndSave:
--GO


