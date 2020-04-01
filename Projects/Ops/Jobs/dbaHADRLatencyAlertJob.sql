USE [msdb]
GO

/****** Object:  Job [dba HADR Latency Alert Job]    Script Date: 11/10/2016 1:31:44 PM ******/
IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'dba HADR Latency Alert Job')
EXEC msdb.dbo.sp_delete_job @job_name=N'dba HADR Latency Alert Job',  @delete_unused_schedule=1
GO

/****** Object:  Job [dba HADR Latency Alert Job]    Script Date: 11/10/2016 1:31:44 PM ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [YDPages]    Script Date: 11/10/2016 1:31:44 PM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'YDPages' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'YDPages'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
select @jobId = job_id from msdb.dbo.sysjobs where (name = N'dba HADR Latency Alert Job')
if (@jobId is NULL)
BEGIN
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dba HADR Latency Alert Job', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Sends Alerts when HADR Latency on the Secondary Exceeds a set Threshold.', 
		@category_name=N'YDPages', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END
/****** Object:  Step [HADR Latency Test and Alerting]    Script Date: 11/10/2016 1:31:44 PM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'HADR Latency Test and Alerting', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/* 
	Run against Primary or Listener 
	Note: While running the query on servers without AlwaysOn Listener configured, comment out the section aglip.state=1.
*/ 
SET NOCOUNT ON; 
DECLARE @DEBUG int = null
 , @MaxLagAllowed int = 20 

if Exists(select * from ops.dbo.Database_status_v where HARole=''PRIMARY'')
BEGIN

IF Object_id(''tempdb..#HADRHealth'') is null 
Begin 
  exec sp_MSdroptemptable ''#HADRHealth'' 

; WITH DR_CTE (connected_state_desc, replica_server_name, database_name, last_commit_time, synchronization_state_desc, synchronization_health_desc, log_send_queue_size, log_send_rate, redo_queue_size, redo_rate, availability_mode_desc, failover_mode_desc, is_suspended, suspend_reason_desc, is_failover_ready , is_pending_secondary_suspend, secondary_role_allow_connections_desc)
AS
(
select ars.connected_state_desc, ar.replica_server_name, database_name, rs.last_commit_time, synchronization_state_desc, rs.synchronization_health_desc, log_send_queue_size, log_send_rate, redo_queue_size, redo_rate, availability_mode_desc, failover_mode_desc, is_suspended, suspend_reason_desc, is_failover_ready , is_pending_secondary_suspend, secondary_role_allow_connections_desc
from master.sys.dm_hadr_database_replica_states rs
inner join master.sys.availability_replicas ar on rs.replica_id = ar.replica_id
inner join sys.dm_hadr_database_replica_cluster_states dcs on dcs.group_database_id = rs.group_database_id and rs.replica_id = dcs.replica_id
inner join sys.dm_hadr_availability_replica_states ars on ars.replica_id=rs.replica_id
where replica_server_name != @@servername
)
select 
	ar.replica_server_name as Primary_replica,
	DR_CTE.replica_server_name as DR_replica, 
	ag.name as AG_Group,
	dcs.database_name, 
	DR_CTE.connected_state_desc,
	DR_CTE.synchronization_state_desc as db_sync_state,
	DR_CTE.synchronization_health_desc as db_sync_health,
	DR_CTE.is_suspended,
	DR_CTE.suspend_reason_desc,
	DR_CTE .is_failover_ready ,
	rs.last_commit_time, 
	DR_CTE.last_commit_time ''DR_commit_time'', 
	datediff(minute, DR_CTE.last_commit_time, rs.last_commit_time) as [lag_in_minutes], 
	DR_CTE.log_send_queue_size as log_send_queue_size_kb,
	DR_CTE.log_send_rate as log_send_rate_kb,
	DR_CTE.redo_queue_size as redo_queue_size_kb,
	DR_CTE.redo_rate as redo_rate_kb,
	DR_CTE.availability_mode_desc as ar_mode,
	DR_CTE.failover_mode_desc ,
	ag.automated_backup_preference_desc as backup_preference,
	ar.backup_priority,
	DR_CTE.secondary_role_allow_connections_desc,
	agl.dns_name as Listener_Name,
	agl.port as Listener_Port,
	aglip.ip_address as Listener_IP_Address, 
	@@SERVERNAME as server_name,
	GetDate() as statsdate
	into #HADRHealth 
from 
	master.sys.dm_hadr_database_replica_states rs
	inner join master.sys.availability_replicas ar on rs.replica_id = ar.replica_id
	inner join sys.dm_hadr_database_replica_cluster_states dcs on dcs.group_database_id = rs.group_database_id and rs.replica_id = dcs.replica_id
	inner join DR_CTE on DR_CTE.database_name = dcs.database_name
	INNER JOIN master.sys.availability_groups ag on ag.group_id = rs.group_id and ag.group_id = ar.group_id
	left join sys.availability_group_listeners agl on ag.group_id = agl.group_id
	left join sys.availability_group_listener_ip_addresses aglip on aglip.listener_id=agl.listener_id 
where 
	ar.replica_server_name = @@servername and aglip.state=1
order by 3
end 

IF @DEBUG=2 
BEGIN
  Select Database_name, lag_in_minutes, redo_queue_size_kb from #HADRHealth
  GOTO AbortScript
END

declare @ERM nvarchar(max) 
  select @ERM = Coalesce(@ERM,'''') + database_name +'' is experiencing a lag of '' + cast([lag_in_minutes] as varchar(100)) + '' minutes.'' 
  from #HADRHealth 
    where [lag_in_minutes] > @MaxLagAllowed or @debug=1

    group by database_name , [lag_in_minutes] 


select @ERM = isnull(@ERM,''NULL'')
raiserror(@ERM,1,1) 


IF len(@ERM) > 10  
begin 
	select @ERM = ''ESOC: Follow the Instructions Provided at: https://osgwiki.com/wiki/EIACollectionGenericEvents#6606'' + char(10) + @ERM 
	Raiserror(@ERM,11,1) 

EXECUTE ops.[dbo].RaiseAlert @Message = @ERM --nvarchar
	,@Type = ''Error'' --varchar
	,@ErrorID = 4300 --int
	,@debug = 1 --int


end 

END

AbortScript: 
', 
		@database_name=N'master', 
		@flags=4
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'HADR Latency Testing', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=15, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20161110, 
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


