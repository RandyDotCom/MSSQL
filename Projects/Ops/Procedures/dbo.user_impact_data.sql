USE [OPS]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[user_impact_data]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[user_impact_data]
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[user_impact_data]') AND type in (N'P', N'PC'))
BEGIN
	EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[user_impact_data] AS' 
END
GO

ALTER procedure [dbo].[user_impact_data] 
	@Action nvarchar(max) = null
	, @debug int = null
AS 
BEGIN 
SET NOCOUNT ON; 
SET XACT_ABORT ON
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
DECLARE @Xdata XML = '<Report />' , @subnode xml = null 

select @action  = case when @action in ('STASH','Blocking','Rollup') then @action else 'sp_who' end 
if @action = 'sp_who'
begin
   raiserror('Here are the valid @actions for this procedure',0,1) 
   if @debug = 1 Return 1; 
end 


BEGIN
CREATE TABLE #sp_who3 
( 
    SPID INT, 
    [Status] nvarchar(300) NULL, 
    [Login] nvarchar(300) NULL, 
    HostName nvarchar(300) NULL, 
    BlkBy nvarchar(300) NULL, 
    DBName nvarchar(300) NULL, 
    Command nvarchar(300) NULL, 
    CPUTime nvarchar(300) NULL, 
    DiskIO nvarchar(300) NULL, 
    LastBatch varchar(400) NULL, 
    ProgramName nvarchar(300) NULL, 
    SPID2 INT null,
    RequestID int null  
) 
 
INSERT #sp_who3 EXEC sp_who2 --'active' 

update #sp_who3 SET LastBatch = LEFT(LastBatch,5) + '/' + cast(YEAR(getdate()) as char(4)) +' '+ RIGHT(LastBatch,8)
update #sp_who3 set [BlkBy]=null where [BlkBy] = '  .'

END  
 

if @Action = 'Rollup'
Begin 

SELECT 
	DBName
	, HostName
	, [Login] 
	, COUNT(*) [Spids]
	, MAX(CONVERT(Datetime,LastBatch)) [LastBatch]
	, datediff(minute,MAX(CONVERT(Datetime,LastBatch)),getdate()) AgeinMins
	, SUM(convert(bigint,DiskIO)) DiskIO
	, AVG(Convert(bigint,CPUTime)) CPUTime 
FROM 
	#sp_who3
where 1=1 
	and [Login] != 'sa'	
	and dbname not in ('master','msdb')
GROUP BY
	 DBNAME, HostName , [Login]
Order by 
	AgeinMins, DBNAME, HostName , [Login] 

REturn 1; 
END 

if @Action='Stash'
begin 

select @subnode = (
	SELECT 
	DBName
	, HostName
	, [Login] 
	, COUNT(*) [Spids]
	, MAX(CONVERT(Datetime,LastBatch)) [LastBatch]
	, datediff(minute,MAX(CONVERT(Datetime,LastBatch)),getdate()) AgeinMins
	, SUM(convert(bigint,DiskIO)) DiskIO
	, AVG(Convert(bigint,CPUTime)) CPUTime 
FROM 
	#sp_who3 spwho3
where 1=1 
	and [Login] != 'sa'	
	and dbname not in ('master','msdb')
GROUP BY
	 DBNAME, HostName , [Login]
Order by 
	AgeinMins, DBNAME, HostName , [Login] 
for xml raw, root('Rollup')
) 


  SET @Xdata.modify('insert sql:variable("@subnode") as first into (/Report)[1]')
  if @debug = 2 
	select @Xdata

end 



IF EXISTS (SELECT * FROM #SP_WHO3 WHERE BLKBY IS NOT NULL )
BEGIN

with spidCTE ([BlockingLevel],[BlkBy],[Spid],Status,[HostName],[DBName],[CPUTime],[Diskio],[LastBatch],[ProgramName]) AS
(
  select 1 as [BlockingLevel],[BlkBy],[Spid],Status,[HostName],[DBName],[CPUTime],[Diskio],[LastBatch],[ProgramName] 
	From #sp_who3 where spid in (select blkby from #sp_who3 ) and blkby is null 
  UNION ALL 
  select [BlockingLevel]+1,s.[BlkBy],s.[Spid],s.Status,s.[HostName],s.[DBName],s.[CPUTime],s.[Diskio],s.[LastBatch],s.[ProgramName]
	From #sp_who3 s
	  inner join spidCTE on spidCTE.[Spid] = s.BlkBy and s.SPID != S.BlkBy
)
Select * 
  into #blocking 
from spidCTE


  select 
	[BlockingLevel]
	,isnull([BlkBy],0) [BlkBy]
	,[Spid]
	,[Status]
	,[HostName]
	,[DBName]
	,[CPUTime]
	,[Diskio]
	,[LastBatch]
	,[ProgramName]
From #blocking 

if @Action='Stash'
BEGIN

select @subnode = (

 select 
	[BlockingLevel]
	,isnull([BlkBy],0) [BlkBy]
	,rtrim(ltrim([Spid])) [Spid]
	,rtrim(ltrim([Status])) [Status]
	,rtrim(ltrim([HostName])) [HostName]
	,rtrim(ltrim([DBName])) [DBName]
	,rtrim(ltrim([CPUTime])) [CPUTime]
	,rtrim(ltrim([Diskio])) [Diskio]
	,rtrim(ltrim([LastBatch])) [LastBatch]
	,rtrim(ltrim([ProgramName])) [ProgramName]
From #blocking Blocking

FOR XML RAW, Root('Blocking') 

)

  SET @Xdata.modify('insert sql:variable("@subnode") as first into (/Report)[1]')
  if @debug = 2 
	select @Xdata
  
end 

END 

if @action in ('STASH','HADR')
BEGIN

if object_id('sys.dm_hadr_database_replica_states') is not null 
Begin 

if exists (select 1 from sys.dm_hadr_database_replica_states)
Begin 

if @Action='HADR'
select  
  md.name
  , datediff(millisecond,[last_hardened_time],getdate()) [hardened_age_ms]
	, datediff(millisecond,[last_commit_time],getdate()) [commit_age_ms]
--, [group_id]
--, mds.[replica_id]
--, mds.[group_database_id]
, [is_local]
--, [synchronization_state]
, [synchronization_state_desc]
--, [is_commit_participant]
--, [synchronization_health]
, [synchronization_health_desc]
--, [database_state]
, [database_state_desc]
--, [is_suspended]
--, [suspend_reason]
--, [suspend_reason_desc]
--, [recovery_lsn]
--, [truncation_lsn]
--, [last_sent_lsn]
--, [last_sent_time]
--, [last_received_lsn]
--, [last_received_time]
--, [last_hardened_lsn]
--, [last_hardened_time]
--, [last_redone_lsn]
--, [last_redone_time]
, [log_send_queue_size]
--, [log_send_rate]
, [redo_queue_size]
--, [redo_rate]
--, [filestream_send_rate]
--, [end_of_log_lsn]
--, [last_commit_lsn]
--, [last_commit_time]
--, [low_water_mark_for_ghosts]
from 
	sys.dm_hadr_database_replica_states mds 
    inner join master.sys.databases md on md.database_id = mds.database_id
where 1=1

if @action='Stash'
Begin

select @subnode = (
select  
  md.name
  , datediff(millisecond,[last_hardened_time],getdate()) [hardened_age_ms]
	, datediff(millisecond,[last_commit_time],getdate()) [commit_age_ms]
--, [group_id]
--, mds.[replica_id]
--, mds.[group_database_id]
, [is_local]
--, [synchronization_state]
, [synchronization_state_desc]
--, [is_commit_participant]
--, [synchronization_health]
, [synchronization_health_desc]
--, [database_state]
, [database_state_desc]
--, [is_suspended]
--, [suspend_reason]
--, [suspend_reason_desc]
--, [recovery_lsn]
--, [truncation_lsn]
--, [last_sent_lsn]
--, [last_sent_time]
--, [last_received_lsn]
--, [last_received_time]
--, [last_hardened_lsn]
--, [last_hardened_time]
--, [last_redone_lsn]
--, [last_redone_time]
, [log_send_queue_size]
--, [log_send_rate]
, [redo_queue_size]
--, [redo_rate]
--, [filestream_send_rate]
--, [end_of_log_lsn]
--, [last_commit_lsn]
--, [last_commit_time]
--, [low_water_mark_for_ghosts]
from 
	sys.dm_hadr_database_replica_states mds 
    inner join master.sys.databases md on md.database_id = mds.database_id
where 1=1
for xml auto, root('HADRPerformance')
) 

  SET @Xdata.modify('insert sql:variable("@subnode") as first into (/Report)[1]')
  if @debug = 2 
	select @Xdata

end 

end 

end 

END  
 


END 
GO

if 2=1
exec ops.dbo.sp_help_executesproc 'user_impact_data'
go 

 if object_id('tempdb..#sp_who3') is not null
   drop table #sp_who3 
GO

if 2=1
Begin 

DECLARE @Action nvarchar(max) = null 
	,@debug int  = null 

SELECT @Action = 'STASH' --nvarchar
	,@debug = 2 --int

EXECUTE [dbo].user_impact_data @Action = @Action --nvarchar
	,@debug = @debug --int

end 
GO 


