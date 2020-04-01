USE [msdb]
GO
if object_id('tempdb..#MyData') is not null 
  Drop Table #MyData


select job.name , job.enabled
  into #MyData 
from 
  msdb.dbo.sysjobs job 
where job.name='IndexOptimize'

/****** Object:  Job [IndexOptimize]    Script Date: 8/23/2017 10:21:54 AM ******/
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'IndexOptimize')
EXEC msdb.dbo.sp_delete_job @job_name=N'IndexOptimize', @delete_unused_schedule=1
GO

declare @enabled bit 
   select @enabled = enabled from #MyData 
   SET @enabled = isnull(@enabled,0) 

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [YDPages]    Script Date: 8/23/2017 10:21:54 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'YDPages' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'YDPages'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
select @jobId = job_id from msdb.dbo.sysjobs where (name = N'IndexOptimize')
if (@jobId is NULL)
BEGIN
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'IndexOptimize', 
		@enabled=@enabled, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'test script from Nikhil, Copied from O''Hallergren , Optimized by Randy (YDPages INC)', 
		@category_name=N'YDPages', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END
/****** Object:  Step [Execute IndexOptimize]    Script Date: 8/23/2017 10:21:54 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute IndexOptimize', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'BEGIN TRY 

	EXECUTE dbo.IndexOptimize
	@Databases = ''USER_DATABASES'', -- set to NULL if you like to do it for all databases, USER_DATABASES for user only databases or set the data base
	@FragmentationLow = NULL,
	@FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE'',-- Reorganize if Rebuild is needed do online followed by offline index rebuild. If we only want to online indexes remove the Rebuild_OFFline
	@FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'',
	@FragmentationLevel1 = 5, -- min freg change it to 5 based on books online 
	 @FragmentationLevel2 = 30, -- max fermentation before it will do Rebuild
	@LogToTable = ''Y'',     -- to log into CommandLog table in master
	@PartitionLevel = ''Y'',
	@SortInTempdb = ''Y'',-- set it to N if not on tempDB
	@UpdateStatistics = ''ALL'',-- set it to NULL if you don’t want to update stats
	@OnlyModifiedStatistics = ''Y'',
	@FillFactor = 90, -- default is 0, we are keeping it at 90%
	@MaxDOP = 0,     -- use all processors
	@PageCountLevel = 10,
	@ExcludeIndexFromDefrag = 1 -- it will exclude tables / objects specified in IndexDefragObjectsToExclude table.

END TRY 
BEGIN CATCH 
  Raiserror(''Noone Cares'',0,1) with nowait 
END CATCH ', 
		@database_name=N'OPS', 
		@output_file_name=N'D:\DBUtil\IndexOptimize_log.txt', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [IndexOptimize msdb]    Script Date: 8/23/2017 10:21:54 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 2)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'IndexOptimize msdb', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Begin Try 

	EXECUTE dbo.IndexOptimize
	@Databases = '' msdb '', -- set to NULL if you like to do it for all databases, USER_DATABASES for user only databases or set the data base
	@FragmentationLow = NULL,
	@FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE'',-- Reorganize if Rebuild is needed do online followed by offline index rebuild. If we only want to online indexes remove the Rebuild_OFFline
	@FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'',
	@FragmentationLevel1 = 5, -- min freg change it to 5 based on books online 
	 @FragmentationLevel2 = 30, -- max fermentation before it will do Rebuild
	@LogToTable = ''Y'',     -- to log into CommandLog table in master
	@PartitionLevel = ''Y'',
	@SortInTempdb = ''Y'',-- set it to N if not on tempDB
	@UpdateStatistics = ''ALL'',-- set it to NULL if you don’t want to update stats
	@OnlyModifiedStatistics = ''Y'',
	@FillFactor = 90, -- default is 0, we are keeping it at 90%
	@MaxDOP = 0,     -- use all processors
	@PageCountLevel = 10,
	@ExcludeIndexFromDefrag = 1 -- it will exclude tables / objects specified in IndexDefragObjectsToExclude table.

End Try 
Begin Catch 
  Raiserror(''Noone Cares'',0,1) 
End Catch ', 
		@database_name=N'OPS', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [IndexOptimize Ops]    Script Date: 8/23/2017 10:21:54 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 3)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'IndexOptimize Ops', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Begin Try 

	EXECUTE dbo.IndexOptimize
	@Databases = '' msdb '', -- set to NULL if you like to do it for all databases, USER_DATABASES for user only databases or set the data base
	@FragmentationLow = NULL,
	@FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE'',-- Reorganize if Rebuild is needed do online followed by offline index rebuild. If we only want to online indexes remove the Rebuild_OFFline
	@FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'',
	@FragmentationLevel1 = 5, -- min freg change it to 5 based on books online 
	 @FragmentationLevel2 = 30, -- max fermentation before it will do Rebuild
	@LogToTable = ''Y'',     -- to log into CommandLog table in master
	@PartitionLevel = ''Y'',
	@SortInTempdb = ''Y'',-- set it to N if not on tempDB
	@UpdateStatistics = ''ALL'',-- set it to NULL if you don’t want to update stats
	@OnlyModifiedStatistics = ''Y'',
	@FillFactor = 90, -- default is 0, we are keeping it at 90%
	@MaxDOP = 0,     -- use all processors
	@PageCountLevel = 10,
	@ExcludeIndexFromDefrag = 1 -- it will exclude tables / objects specified in IndexDefragObjectsToExclude table.

End Try 
Begin Catch 
  Raiserror(''Noone Cares'',0,1) 
End Catch ', 
		@database_name=N'OPS', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [IndexoptimizeMaster]    Script Date: 8/23/2017 10:21:55 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 4)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'IndexoptimizeMaster', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'Begin Try 

		EXECUTE dbo.IndexOptimize
		@Databases = '' master'', -- set to NULL if you like to do it for all databases, USER_DATABASES for user only databases or set the data base
		@FragmentationLow = NULL,
		@FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE'',-- Reorganize if Rebuild is needed do online followed by offline index rebuild. If we only want to online indexes remove the Rebuild_OFFline
		@FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'',
		@FragmentationLevel1 = 5, -- min freg change it to 5 based on books online 
		 @FragmentationLevel2 = 30, -- max fermentation before it will do Rebuild
		@LogToTable = ''Y'',     -- to log into CommandLog table in master
		@PartitionLevel = ''Y'',
		@SortInTempdb = ''Y'',-- set it to N if not on tempDB
		@UpdateStatistics = ''ALL'',-- set it to NULL if you don’t want to update stats
		@OnlyModifiedStatistics = ''Y'',
		@FillFactor = 90, -- default is 0, we are keeping it at 90%
		@MaxDOP = 0,     -- use all processors
		@PageCountLevel = 10,
		@ExcludeIndexFromDefrag = 1 -- it will exclude tables / objects specified in IndexDefragObjectsToExclude table.

End Try 
Begin Catch 
  Raiserror(''Noone Cares'',0,1) 
End Catch ', 
		@database_name=N'OPS', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Daily', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=6, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20140409, 
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


