USE [msdb]
GO

--if object_id('tempdb..#JobSchedules') is not null 
--  Drop table #JobSchedules 
--  /* Preserve the current status */
--select
--  job.name [Jobname]
--  , job.enabled [JobEnabled]
--  , js.next_run_date 
--  , js.next_run_time 
--  , CASE WHEN js.next_run_date > 0 then msdb.dbo.jobtime(js.next_run_date,js.next_run_time,null) else null end [NextRun]
--  , js.schedule_id 
--  , ss.name 
--  , ss.enabled [SchedEnabled]
--  , ss.active_start_date 
--  , ss.active_start_time 
--into #JobSchedules
--from msdb.dbo.sysjobs Job 
-- inner join msdb.dbo.sysjobschedules js on js.job_id=job.job_id 
-- inner join msdb.dbo.sysschedules ss on ss.schedule_id = js.schedule_id 
--where 1=1 
-- and job.name='dbaDBCC-Checkdb'



IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'dbaDBCC-Checkdb')
begin
	Raiserror('Removing old Job',0,1) with nowait 
	EXEC msdb.dbo.sp_delete_job @job_name=N'dbaDBCC-Checkdb', @delete_unused_schedule=1
end 
GO

--IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'YDPages' AND category_class=1)
--BEGIN
--	EXEC msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'YDPages'
--END 


--BEGIN TRANSACTION
--DECLARE @ReturnCode INT
--SELECT @ReturnCode = 0


--DECLARE @jobId BINARY(16)
--select @jobId = job_id from msdb.dbo.sysjobs where (name = N'dbaDBCC-Checkdb')
--if (@jobId is NULL)
--BEGIN
--EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dbaDBCC-Checkdb', 
--		@enabled=0, 
--		@notify_level_eventlog=0, 
--		@notify_level_email=0, 
--		@notify_level_netsend=0, 
--		@notify_level_page=0, 
--		@delete_level=0, 
--		@description=N'DBCC CheckdB Physical_only', 
--		@category_name=N'YDPages', 
--		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
--IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

--END

--/* Trap the Current SChedule  */
--if OBJECT_ID('tempdb..#CurrentSchedules') is not null 
--  Drop Table #CurrentSchedules

--select ss.schedule_uid, js.schedule_id,ss.name
-- into #CurrentSchedules  
-- from msdb.dbo.sysjobschedules js 
--   inner join msdb.dbo.sysschedules ss on ss.schedule_id = js.schedule_id
-- where js.job_id = @jobId


--IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
--EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DBCC', 
--		@step_id=1, 
--		@cmdexec_success_code=0, 
--		@on_success_action=1, 
--		@on_success_step_id=0, 
--		@on_fail_action=2, 
--		@on_fail_step_id=0, 
--		@retry_attempts=0, 
--		@retry_interval=0, 
--		@os_run_priority=0, @subsystem=N'TSQL', 
--		@command=N'
--DECLARE dbccc CURSOR READ_ONLY FOR 
--select name from master.sys.databases

--DECLARE @name nvarchar(max), @ERM nvarchar(max) , @ERS int
--OPEN dbccc

--FETCH NEXT FROM dbccc INTO @name
--WHILE (@@fetch_status <> -1)
--BEGIN
--	IF (@@fetch_status <> -2)
--	BEGIN

--		Begin Try 

--		declare @stmt nvarchar(max) 
--		select @stmt =''DBCC CHECKDB(N''''''+@name+'''''')  WITH NO_INFOMSGS,ALL_ERRORMSGS,PHYSICAL_ONLY'' 
--		raiserror(@STMT,0,1) with nowait 

--		Exec(@stmt)

--		End Try

--		Begin Catch

--			select @ERM = isnull(@name,''Null @name'') + '' Raised Error''+ char(10) + ERROR_MESSAGE()
--			, @ERS = ERROR_SEVERITY() 
			

--			Raiserror(@ERM,@ERS,1)

--			--IF @ERS > 11 Goto OnErrorExitCursor

--		End Catch

--	END
--	FETCH NEXT FROM dbccc INTO @name
--END

--OnErrorExitCursor: 


--CLOSE dbccc
--DEALLOCATE dbccc
--GO

--', 
--		@database_name=N'master', 
--		@flags=0
--IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
--EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1

--IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

-- EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dbaDBCC-Checkdb', 
--		@enabled=1, 
--		@freq_type=8, 
--		@freq_interval=4, 
--		@freq_subday_type=1, 
--		@freq_subday_interval=0, 
--		@freq_relative_interval=0, 
--		@freq_recurrence_factor=1, 
--		@active_start_date=20160321, 
--		@active_end_date=99991231, 
--		@active_start_time=80000, 
--		@active_end_time=235959


--EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
--IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback






----if exists(select * From #CurrentSchedules)
----BEGIN
  
----DECLARE SSSchedC CURSOR READ_ONLY FOR 
----select schedule_uid, schedule_id, name from #CurrentSchedules

----DECLARE @schedule_uid uniqueidentifier, @schedule_id int, @ERM nvarchar(max) , @name nvarchar(max)   
----OPEN SSSchedC

----FETCH NEXT FROM SSSchedC INTO @schedule_uid, @schedule_id, @name
----WHILE (@@fetch_status <> -1)
----BEGIN
----	IF (@@fetch_status <> -2)
----	BEGIN

----		Begin Try 
----			select @ERM = 'Attaching Schedule ' + @name 
----			Raiserror(@ERM,0,1) with nowait 

----			EXEC msdb.dbo.sp_attach_schedule @job_id=@jobId,@schedule_id=@schedule_id
			
----		End Try

----		Begin Catch

----			select @ERM = 'unable to Attach schedule ' + isnull(@name,'Null @name') + ' 
----			  Raised Error'+ char(10) + ERROR_MESSAGE()
----			Raiserror(@ERM,1,1) with nowait 			


----		End Catch

----	END
----	FETCH NEXT FROM SSSchedC INTO  @schedule_uid, @schedule_id, @name
----END

----OnErrorExitCursor: 


----CLOSE SSSchedC
----DEALLOCATE SSSchedC

----END 
----ELSE
----BEGIN
----   Raiserror('Using Default SChedule',0,1) with nowait 

----EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dbaDBCC-Checkdb', 
----		@enabled=1, 
----		@freq_type=8, 
----		@freq_interval=4, 
----		@freq_subday_type=1, 
----		@freq_subday_interval=0, 
----		@freq_relative_interval=0, 
----		@freq_recurrence_factor=1, 
----		@active_start_date=20160321, 
----		@active_end_date=99991231, 
----		@active_start_time=80000, 
----		@active_end_time=235959

----END 


----if not exists(
----select ss.schedule_uid, js.schedule_id,ss.name
---- from msdb.dbo.sysjobschedules js 
----   inner join msdb.dbo.sysschedules ss on ss.schedule_id = js.schedule_id
---- where js.job_id = @jobId
---- ) 
---- BEGIN

---- Raiserror('Schedule Process Error, using Default',0,1) with nowait 

---- EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dbaDBCC-Checkdb', 
----		@enabled=1, 
----		@freq_type=8, 
----		@freq_interval=4, 
----		@freq_subday_type=1, 
----		@freq_subday_interval=0, 
----		@freq_relative_interval=0, 
----		@freq_recurrence_factor=1, 
----		@active_start_date=20160321, 
----		@active_end_date=99991231, 
----		@active_start_time=80000, 
----		@active_end_time=235959


---- END


--COMMIT TRANSACTION
--GOTO EndSave
--QuitWithRollback:
--    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
--EndSave:


--GO


--if 1=2 
--  begin 
--select ss.schedule_uid, js.schedule_id,ss.name
 
-- from msdb.dbo.sysjobschedules js 
--   inner join msdb.dbo.sysschedules ss on ss.schedule_id = js.schedule_id
   
-- where 1=1 
--   and ss.name like 'dbadbc%'
--   --and js.job_id = @jobI
--  end 
