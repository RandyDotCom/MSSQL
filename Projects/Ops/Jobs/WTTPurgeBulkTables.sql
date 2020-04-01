USE [msdb]
GO

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'WTTPrugeBulkTables')
	EXEC msdb.dbo.sp_delete_job @job_name=N'WTTPrugeBulkTables', @delete_unused_schedule=1
GO


BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'YDPages' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'YDPages'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
select @jobId = job_id from msdb.dbo.sysjobs where (name = N'WTTPrugeBulkTables')
if (@jobId is NULL)
BEGIN
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'WTTPrugeBulkTables', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This Job suppports cross-datastore scheduling by removing garbage tables by Schema Name', 
		@category_name=N'YDPages', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END
/****** Object:  Step [Purge Bulk Schema Tables older than 10 minutes]    Script Date: 1/25/2016 11:34:15 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Purge Bulk Schema Tables older than 10 minutes', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=5, 
		@retry_interval=5, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
/*********************************************************************************************************************************/
--Comments
--1.  This script will drop table created by cross-datastore scheduling i.e.  tables starting with blk.
--2.  Set @CutOffMinute before running the script. for example SET @CutOffMinute = 10,  blk tables that are more than 10 minutes old will be dropped

/*********************************************************************************************************************************/

DECLARE @CutOffMinute int
DECLARE @TableCreateDate DateTime
DECLARE @SqlText nvarchar(max)
DECLARE @id INT
SET @id = 0
--DROP All blk TABLEs more than 10 minutes old
SET @CutOffMinute = 10
SET @TableCreateDate = DateADD(minute, -@CutOffMinute, getdate())


IF OBJECT_ID(''tempdb..#Commands'') IS NOT NULL
DROP TABLE #Commands

CREATE TABLE #Commands 
(
    Id int identity(1,1), 
    SqlText nvarchar(max)
)

INSERT INTO #Commands (SqlText)
SELECT ''DROP TABLE [''+ss.name+''].['' + so.name + '']'' 
FROM sys.Objects so INNER JOIN sys.Schemas  ss
ON so.Schema_id = ss.schema_id 
   AND ss.Name = ''blk'' AND so.Type = ''U'' 
   AND so.Create_Date <=@TableCreateDate


WHILE (1=1)
BEGIN
    SELECT TOP 1 @SqlText = SqlText, @Id = Id
    FROM #Commands
    WHERE Id > @Id 
    ORDER BY Id
    
    IF (@@ROWCOUNT = 0) BREAK
    PRINT @SqlText
    EXEC (@SqlText)
END', 
		@database_name=N'OSGThreshold_EDS07', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'PurgeEvery30Minutes', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=30, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20140617, 
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


