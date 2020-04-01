USE [OPS]
GO

IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[HADR_health_v]'))
DROP VIEW [dbo].[HADR_health_v]
GO

IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[HADRClusterData_v]'))
DROP VIEW [dbo].[HADRClusterData_v]
GO

SET ANSI_NULLS ON ;SET QUOTED_IDENTIFIER ON
GO

if object_id('master.sys.dm_hadr_database_replica_cluster_states') is null 
  GOTO AbortScript 


IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[HADRClusterData_v]'))
EXEC dbo.sp_executesql @statement = N'
create view [dbo].[HADRClusterData_v]
as

WITH DR_CTE (connected_state_desc, replica_server_name, database_name, last_commit_time, synchronization_state_desc, synchronization_health_desc, log_send_queue_size, log_send_rate, redo_queue_size, redo_rate, availability_mode_desc, failover_mode_desc, is_suspended, suspend_reason_desc, is_failover_ready , is_pending_secondary_suspend, secondary_role_allow_connections_desc)
AS
(
select ars.connected_state_desc, ar.replica_server_name, database_name, rs.last_commit_time, synchronization_state_desc, rs.synchronization_health_desc, log_send_queue_size, log_send_rate, redo_queue_size, redo_rate, availability_mode_desc, failover_mode_desc, is_suspended, suspend_reason_desc, is_failover_ready , is_pending_secondary_suspend, secondary_role_allow_connections_desc
from master.sys.dm_hadr_database_replica_states rs
inner join master.sys.availability_replicas ar on rs.replica_id = ar.replica_id
inner join master.sys.dm_hadr_database_replica_cluster_states dcs on dcs.group_database_id = rs.group_database_id and rs.replica_id = dcs.replica_id
inner join master.sys.dm_hadr_availability_replica_states ars on ars.replica_id=rs.replica_id
where replica_server_name != @@servername
)
select TOP 100 PERCENT
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
	datediff(ss, DR_CTE.last_commit_time, rs.last_commit_time) as ''lag_in_seconds'', 
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
' 
AbortScript:
GO

if 1=2 
Begin

select [name] from sys.columns c where object_id = object_id('HADRClusterData_v') 

select * from ops.dbo.HADRClusterData_v


end
