USE [msdb]
GO

Set nocount on; 
if object_id('tempdb..#Jobs') is not null 
  Drop table #jobs 

select job.name, job.enabled 
into #jobs
from msdb.dbo.sysjobs job 
where name='dbaBackupsLogs'
GO


if object_id('tempdb..#JobSchedules') is not null 
  Drop table #JobSchedules 

select
  job.name [Jobname]
  , job.enabled [JobEnabled]
  , js.next_run_date 
  , js.next_run_time 
  , CASE WHEN js.next_run_date > 0 then msdb.dbo.jobtime(js.next_run_date,js.next_run_time,null) else null end [NextRun]
  , js.schedule_id 
  , ss.name 
  , ss.enabled [SchedEnabled]
into #JobSchedules
from msdb.dbo.sysjobs Job 
 inner join msdb.dbo.sysjobschedules js on js.job_id=job.job_id 
 inner join msdb.dbo.sysschedules ss on ss.schedule_id = js.schedule_id 
where 1=1 
 and job.name='dbaBackupsLogs'

 
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'dbaBackupsLogs')
EXEC msdb.dbo.sp_delete_job @job_name=N'dbaBackupsLogs', @delete_unused_schedule=0
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

  Declare @RootPath nvarchar(max) , @enabled bit 
if 1=2
BEGIN

  select @RootPath = Ops.dbo.[fnSetting]('Instance','BackupDirectory')+'\dbaBackupsLogs.log'
  Raiserror(@Rootpath,0,1) with nowait 
END 


  
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'YDPages' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'YDPages'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
select @jobId = job_id from msdb.dbo.sysjobs where (name = N'dbaBackupsLogs')
if (@jobId is NULL)
BEGIN

EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dbaBackupsLogs', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Database Tran Log Backups Job', 
		@category_name=N'YDPages', 
		@owner_login_name=N'sa', 
		--@notify_email_operator_name=N'Ops',
		 @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END
/****** Object:  Step [BackupDatabases]    Script Date: 9/29/2014 11:11:57 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'BackupDatabases', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=4, 
		@on_fail_step_id=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXECUTE [dbo].BackupDatabase @backupType=''Log'', @debug=1', 
		@database_name=N'Ops', 
		@output_file_name=@Rootpath, 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ReportJobError]    Script Date: 9/29/2014 11:11:57 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 2)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ReportJobError', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command='Exec dbo.joblogs_cleaner @job_name=''dbaBackupsLogs'', @debug=0', 
		@database_name=N'Ops', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback


/*
	I have Tweaked the dbaBackupsDailys and dbaBackupsLogs job scripts to respect the schedules if they already exist.
*/
if not exists(select * from #jobSchedules)
Begin 

   Raiserror('Adding Default Schedule',0,1) with nowait 

EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dbaBackupsLogs', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20140914, 
		@active_end_date=99991231, 
		@active_start_time=500, 
		@active_end_time=235959

END 
ELSE
BEGIN

	Raiserror('RE-Attaching to previous Schedules',0,1) with nowait 

	DECLARE @schedule_id int, @ERM nvarchar(max) , @ERS int 
	DECLARE schedcursor CURSOR READ_ONLY FOR select schedule_id from #jobschedules
	OPEN schedcursor
	FETCH NEXT FROM schedcursor INTO @schedule_id
	WHILE (@@fetch_status <> -1)
	BEGIN
		IF (@@fetch_status <> -2)
		BEGIN

			EXEC @ReturnCode = msdb.dbo.sp_attach_schedule @job_id=@jobId, @schedule_id=@schedule_id 

		END
		FETCH NEXT FROM schedcursor INTO @schedule_id
	END
	CLOSE schedcursor
	DEALLOCATE schedcursor

END 

IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION

  --Raiserror('dbaBackupsLogs Job Created in Disabled State',0,1)

GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

if exists(select * from #jobs where name='dbaBackupsLogs' and enabled=0)
Begin
	Raiserror('dbaBackupsLogs Job was disabled',0,1) with nowait
END 
ELSE
BEGIN
	EXEC msdb.dbo.sp_update_job @job_name='dbaBackupsLogs', @enabled=1
END 
GO

select
  job.name [Jobname]
  , job.enabled [JobEnabled]
  , js.next_run_date 
  , js.next_run_time 
  , CASE WHEN js.next_run_date > 0 then msdb.dbo.jobtime(js.next_run_date,js.next_run_time,null) else null end [NextRun]
  , js.schedule_id 
  , ss.name 
  , ss.enabled [SchedEnabled]
  , ss.active_start_date 
  , ss.active_start_time 
--into #JobSchedules
from msdb.dbo.sysjobs Job 
 inner join msdb.dbo.sysjobschedules js on js.job_id=job.job_id 
 inner join msdb.dbo.sysschedules ss on ss.schedule_id = js.schedule_id 
where 1=1 
 and job.name='dbaBackupsLogs'
GO
