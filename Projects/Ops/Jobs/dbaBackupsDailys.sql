USE [msdb]
GO

if object_id('tempdb..#JobSchedules') is not null 
  Drop table #JobSchedules 
  /* Preserve the current status */
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
into #JobSchedules
from msdb.dbo.sysjobs Job 
 inner join msdb.dbo.sysjobschedules js on js.job_id=job.job_id 
 inner join msdb.dbo.sysschedules ss on ss.schedule_id = js.schedule_id 
where 1=1 
 and job.name='dbaBackupsDailys'

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'dbaBackupsDailys')
	EXEC msdb.dbo.sp_delete_job @job_name=N'dbaBackupsDailys', @delete_unused_schedule=0


BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

  Declare @RootPath nvarchar(max) , @enabled bit, @command varchar(max) 

if 1=2 /*TO ENABLE TEXT FILE LOGGING */
BEGIN
  select @RootPath = Ops.dbo.[fnSetting]('Instance','BackupDirectory')
  select @RootPath = @RootPath+'\dbaBackupsDailys.log'
  Raiserror(@Rootpath,0,1) with nowait 
END 


IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'YDPages' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'YDPages'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
select @jobId = job_id from msdb.dbo.sysjobs where (name = N'dbaBackupsDailys')
if (@jobId is NULL)
BEGIN
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dbaBackupsDailys', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This job RE-assigns SA as the Owner to all databases
		Re-assigns SA as the Owner to All SQL Agent Jobs 
		executes a dailing backup 
Execute the following to find Instance Sepecific Details
select	Name, [Value] from ops.dbo.Settings where Context=''Instance''', 
		@category_name=N'YDPages', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

if 1=2
 select	Name, [Value] from ops.dbo.Settings where Context='Instance'

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Backup Files Audit', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=4, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC msdb..sp_cycle_errorlog
GO
Exec Ops.dbo.BackupFiles_get @debug=1
GO

declare @SCRIPT nvarchar(max) 
select 
 @SCRIPT = COALESCE(@SCRIPT+'';'','''') + ''EXEC [''+ db.name +''].dbo.sp_changedbowner @loginame = N''''sa'''', @map = false'' -- [Script] 
from 
    master.sys.databases db
	left outer join sys.server_principals sp on sp.principal_id = db.owner_sid 
where isnull(sp.name,''NULL'') != ''sa'' and db.state_desc=''ONLINE'' and db.is_in_standby = 0

if @SCRIPT is not null
begin 
Begin try 
	Raiserror(@script,0,1) with nowait 
	Exec (@script)

		select @SCRIPT = convert(varchar(300),serverproperty(''servername'')) + '' SQ Databases Whose owner was changed to SA
	'' +@SCRIPT 

	EXECUTE ops.[dbo].RaiseAlert @Message = @SCRIPT --nvarchar
	,@Type = ''Information'' --varchar
	,@ErrorID = 11 --int


end try 
begin catch
	raiserror(''unable to change a database owner'',11,1) with nowait 
end catch 
end 

select @SCRIPT = null 

select 
  @SCRIPT = coalesce(@SCRIPT +'';'' + char(10),'''') + ''EXEC msdb.dbo.sp_update_job @job_name=N'''''' + Job.name + '''''', @owner_login_name=N''''sa''''''
  -- select job.name, sp.name 
from 
  msdb.dbo.sysjobs job 
  left outer join master.sys.server_principals sp on sp.[sid] = job.owner_sid
where 1=1 
and isnull(sp.name,''Null'') !=''SA''

if @SCRIPT is not null
begin 
Begin try
	Raiserror(@SCRIPT,0,1) with nowait 
	EXEC (@SCRIPT) 
	select @SCRIPT = convert(varchar(300),serverproperty(''servername'')) + '' SQLAgentJobs Whose owner was changed to SA
	'' +@SCRIPT 

	EXECUTE ops.[dbo].RaiseAlert @Message = @SCRIPT --nvarchar
	,@Type = ''Information'' --varchar
	,@ErrorID = 10 --int
	

end try 
begin catch
	raiserror(''unable to change a sqlagent job owner'',11,1) with nowait 
end catch 
end 
GO

-- exec ops.dbo.sp_help_executesproc ''Raisealert''', 
		@database_name=N'Ops', 
		@output_file_name=@Rootpath, 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback


IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 2)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'BackupsCleaner', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=4, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Exec Ops.dbo.BackupsCleaner @debug=null ', 
		@database_name=N'Ops', 
		@output_file_name=@Rootpath, 
		@flags=2
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback


IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 3)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'BackupDatabases', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=4, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXECUTE [dbo].BackupDatabase @backuptype=''Full'', @debug=0', 
		@database_name=N'Ops', 
		@output_file_name=@Rootpath, 
		@flags=2
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback


IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 4)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ReportJobError', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'

Exec Ops.dbo.BackupsCleaner @debug=null -- allows for Retention of 1 

Exec dbo.joblogs_cleaner @job_name=''dbaBackupsDailys'', @debug=1


if datepart(weekday,getdate())=4
Begin
  raiserror(''Resetting dbaIndexOptimize'',0,1) with nowait 
  truncate table ops.dbo.idxHealth 
end

EXEC msdb.dbo.sp_update_job @job_name=''dbaBackupsDailys'', @enabled=1

		', 
		@database_name=N'Ops', 
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback


if not exists(select * from #jobSchedules)
Begin 

   Raiserror('Adding Default Schedule',0,1) with nowait 

EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dbaBackupsDailys', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20140929, 
		@active_end_date=99991231, 
		@active_start_time=220000, 
		@active_end_time=235959 


END 
ELSE
BEGIN

	Raiserror('RE-Attaching to previous Schedules',0,1) with nowait 

	if not exists(select * from #jobSchedules where SchedEnabled=1) 
	  Raiserror('There is no Enabled Schedule',11,1) with nowait 


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

	-- EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'DailyFulls Quiet Time'


END


EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

--select
-- 'Prior' [tag] , 
--  tjs.[Jobname] 
--  , tjs.[JobEnabled]
--  , tjs.next_run_date 
--  , tjs.next_run_time 
--  , CASE WHEN tjs.next_run_date > 0 then msdb.dbo.jobtime(tjs.next_run_date,tjs.next_run_time,null) else null end [NextRun]
--  , tjs.schedule_id 
--  , tjs.name 
--  , tjs.[SchedEnabled]
--  , tjs.active_start_date 
--  , tjs.active_start_time 
--FROM #JobSchedules tjs
--union 
select 'Current' [Tag], 
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
 and job.name='dbaBackupsDailys'
ORDER BY 
	[tag] DESC 

GO

