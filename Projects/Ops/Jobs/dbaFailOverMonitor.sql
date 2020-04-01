USE [msdb]
GO

/****** Object:  Job [dbaFailOverMonitor]    Script Date: 12/21/2015 10:44:47 AM ******/
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'dbaFailOverMonitor')
EXEC msdb.dbo.sp_delete_job @job_name=N'dbaFailOverMonitor', @delete_unused_schedule=1
GO

/****** Object:  Job [dbaFailOverMonitor]    Script Date: 12/21/2015 10:44:47 AM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [YDPages]    Script Date: 12/21/2015 10:44:47 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'YDPages' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'YDPages'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
select @jobId = job_id from msdb.dbo.sysjobs where (name = N'dbaFailOverMonitor')
if (@jobId is NULL)
BEGIN
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dbaFailOverMonitor', 
		@enabled=1, 
		@notify_level_eventlog=2, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Sets this server back to Primary for databases in HA', 
		@category_name=N'YDPages', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END
/****** Object:  Step [Reclaim Databases]    Script Date: 12/21/2015 10:44:48 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Reclaim Databases', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @profile_name sysname = null 
,@recipients varchar(max) = null 
,@copy_recipients varchar(max)  = null
,@blind_copy_recipients varchar(max)  = null
,@subject nvarchar(255)  = null
,@body nvarchar(max)  = null
,@body_format varchar(10)  = ''HTML'' --TEXT or HTML
,@importance varchar(6)  = ''High''  --  Low, Normal, High
,@sensitivity varchar(12)  = ''Normal'' -- Normal, Personal, Private, Confidential
,@mailitem_id int  = null

SELECT 
	@recipients=''Projects@ydpages.com''
,   @copy_recipients=''Projects@ydpages.com''
,	@subject = convert(varchar(max),serverproperty(''servername'')) + '' dbaFailoverMonitor Alert''
,	@body = null 	

DECLARE @FEC int 

DECLARE dbc CURSOR READ_ONLY FOR 
select 
 md.name as [DatabaseName]
 , mp.ag_name [AgNAme]
 --, ars.role_desc
FROM
	master.sys.databases mD 
	left outer join master.sys.availability_databases_cluster dc on dc.database_name = mD.Name 
	left outer join master.sys.dm_hadr_availability_replica_states ars on ars.group_id = dc.group_id and ars.is_local=1
	left outer join master.sys.dm_hadr_name_id_map mp on mp.ag_id = ars.group_id 
where 1=1 
  and ars.role_desc = ''Secondary''

DECLARE @Databasename nvarchar(max), @ERM nvarchar(max) , @ERS int, @Agname nvarchar(512)
OPEN dbc

FETCH NEXT FROM dbc INTO @Databasename,@Agname
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		
		SELECT @FEC = isnull(@FEC,0) + 1 
		Begin Try 

		DECLARE @stmt varchar(max)
		SELECT @stmt = ''ALTER AVAILABILITY GROUP [''+@Agname+''] FORCE_FAILOVER_ALLOW_DATA_LOSS;''
		select @body = Coalesce(@body,'''') + ''<div>''+isnull(@stmt,''@stmt null'') +''</div>'' 
		Raiserror(@stmt,0,1) 
		EXEC (@stmt)
		
		End Try

		Begin Catch

			select @ERM = isnull(@Databasename,''Null @Databasename'') + '' Raised Error''+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			
			select @body = Coalesce(@body,'''') + ''<li>Error:'' + isnull(@ERM,''Null @ERM'') + ''</li>''
			Raiserror(@ERM,@ERS,1)

			--IF @ERS > 11 Goto OnErrorExitCursor

		End Catch

	END
	FETCH NEXT FROM dbc INTO @Databasename,@Agname
END

OnErrorExitCursor: 


CLOSE dbc
DEALLOCATE dbc


if @body is not null 
begin
	select @body= ''<h1>'' + @subject + ''</h1><h3>Server Executed the following</h3>'' + @body

 Raiserror(@body,0,1)  


EXEC msdb.dbo.sp_send_dbmail @profile_name = @profile_name 
,	@recipients = @recipients 
,	@copy_recipients = @copy_recipients
,	@blind_copy_recipients = @blind_copy_recipients
,	@subject = @subject
,	@body = @body
,	@body_format = @body_format
,	@importance = @importance
,	@sensitivity = @sensitivity
,	@mailitem_id = @mailitem_id OUTPUT 


	

END 

if @FEC > 0 
  Raiserror(''A Failover did occur, check email process'',11,1) with nowait', 
		@database_name=N'master', 
		@flags=8
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Occurs Every 3 Min', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=3, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20111120, 
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


