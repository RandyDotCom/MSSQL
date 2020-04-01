USE [msdb]
GO
SET NOCOUNT ON; 
if Object_id('tempdb..#CurrentJobSettings') is not null 
  Drop table #CurrentJobSettings

select 
  job.name
  , job.enabled 
  , ss.name [Schedule]
  , ss.enabled [ScheduleEnabled]
into #CurrentJobSettings
from 
  msdb.dbo.sysjobs job 
  inner join msdb.dbo.sysjobschedules js on js.job_id = job.job_id 
  inner join msdb.dbo.sysschedules ss on ss.schedule_id = js.schedule_id 
WHERE job.name='dbaIndexOptimize' 


begin Try 

	exec msdb.dbo.sp_update_job @Job_name='dbaindexOptimize', @Enabled=0 
	--EXEC msdb.dbo.sp_Stop_job @Job_name='dbaindexOptimize' 
	Truncate table ops.dbo.idxhealth 

end Try 
Begin Catch 
	declare @ERM nvarchar(max)
	select @ERM = ERROR_MESSAGE()

end Catch
GO

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'dbaIndexOptimize')
	EXEC msdb.dbo.sp_delete_job @job_name=N'dbaIndexOptimize',  @delete_unused_schedule=1
GO

Declare @LogPath nvarchar(400) , @jobEnabled bit 
SET @LogPath = ops.dbo.fnSetting('dbaIndexoptimize','Log File Path')


SET @jobEnabled = (select enabled from #CurrentJobSettings where name='dbaIndexOptimize') 
SET @jobEnabled = isnull(@jobenabled,1)  

if @LogPath is null 
SET @LogPath = ops.dbo.fnSetting('Instance','BackupDirectory') + '\dbaindexoptimize.log'


BEGIN TRANSACTION
if @LogPath is null  GOTO QuitWithRollback

DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [YDPages]    Script Date: 1/31/2017 11:16:36 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'YDPages' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'YDPages'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
select @jobId = job_id from msdb.dbo.sysjobs where (name = N'dbaIndexOptimize')
if (@jobId is NULL)
BEGIN
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'dbaIndexOptimize', 
		@enabled=@jobEnabled, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Index Defragmentation Toolsuite', 
		@category_name=N'YDPages', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END
/****** Object:  Step [Discovery]    Script Date: 1/31/2017 11:16:36 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 1)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Discovery', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=4, 
		@on_fail_step_id=4, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/*DISCOVERY*/
SET QUOTED_IDENTIFIER ON;
declare @debug int = 0 /* Increase Verbosity */
declare @ERM nvarchar(max) , @servername nvarchar(128)  , @dbname nvarchar(128), @RC int 
Select @Servername = Convert(nvarchar(128),SERVERPROPERTY(''servername'')), @dbname = convert(nvarchar(128),db_name())
select @ERM = ''Discovering on '' + @servername + ''.'' + @dbname 
Raiserror(@ERM,0,1) with nowait 

if not exists(select * FROM ops.dbo.Database_status_v where DatabaseName=@dbname and isnull(HARole,''PRIMARY'') = ''PRIMARY'' and is_in_standby=0 and state_desc=''ONLINE'') 
BEGIN
	select @ERM = @dbname + '' Is not in a state for Index Maintenance'' 
	Raiserror(@ERM,0,1) with nowait 
	GOTO ExitScript 
END
ELSE
BEGIN

  -- Truncate Table ops.dbo.idxHealth 


Declare @MaxFragClustered int, @MaxFragNonClustered int , @MaxFragActions tinyint 
/* Setting Default Defrag values */

Begin /* Making Sure we have Fragmentation settings */
begin try 

Settings: 
  select @MaxFragClustered = CAST(ops.dbo.fnSetting(''Fragmentation'',''Clustered'') as INT) 
  , @MaxFragNonClustered = CAST(ops.dbo.fnSetting(''Fragmentation'',''NonClustered'') as INT) 
  , @MaxFragActions = CAST(ops.dbo.fnSetting(''Fragmentation'',''MaxActions'') as tinyint) 

if @MaxFragClustered is null 
	exec ops.dbo.Settings_put ''Fragmentation'',''Clustered'',''5''
	
if @MaxFragNonClustered is null 
	exec ops.dbo.Settings_put ''Fragmentation'',''NonClustered'',''10''

if @MaxFragActions is null 
	exec ops.dbo.Settings_put ''Fragmentation'',''MaxActions'',''5''

	
	if @debug>0
	select ops.dbo.fnSetting(''Fragmentation'',''NonClustered'') [NonClustered]
	, ops.dbo.fnSetting(''Fragmentation'',''Clustered'') [Clustered]
	, ops.dbo.fnSetting(''Fragmentation'',''MaxActions'') [MaxActions]


if ((@MaxFragClustered is null) or (@MaxFragNonClustered is null) or (@MaxFragActions is null))
  GOTO Settings 
  
end try 
Begin catch 

	raiserror(''Either the fnSetting Function, Settings_put procedure, or settings table is missing?'',11,1) 
	Goto ExitScript 

end catch
END 

insert into ops.dbo.idxHealth (servername,DatabaseName,[schema],TableName,IndexName,type_desc,StatsDate,[Action],[Status])
SELECT 
	convert(varchar(300),ServerProperty(''ServerName'')) COLLATE SQL_Latin1_General_CP1_CI_AS as servername
	,db_name() COLLATE SQL_Latin1_General_CP1_CI_AS as DatabaseName 
	, sc.name as [schema]
	, ob.name [TableName]
	,b.[name] as [IndexName]
	,b.type_desc 
	, STATS_DATE(b.[object_id], b.index_id) [StatsDate]
	,''Discovery'' [Action]
	,''Discovered'' [status]
	--, ci.idRow 
FROM 
	sys.objects ob 
	inner join sys.schemas sc on sc.[schema_id] = ob.[schema_id]
	INNER JOIN sys.indexes AS b ON ob.[object_id] = b.[object_id] --and b.type_desc in (''CLUSTERED'',''NONCLUSTERED'')
	left outer join ops.dbo.idxHealth ci on ci.ServerName = convert(varchar(300),ServerProperty(''ServerName'')) COLLATE SQL_Latin1_General_CP1_CI_AS
		and ci.DatabaseName=db_name() and ci.[schema]=sc.name COLLATE SQL_Latin1_General_CP1_CI_AS
		and ci.TableName = ob.name COLLATE SQL_Latin1_General_CP1_CI_AS
		and ci.IndexName = b.name COLLATE SQL_Latin1_General_CP1_CI_AS
WHERE 1=1
 and ob.type in (''U'')
 and b.name is not null
 and ci.Status is null


  select @RC = @@ROWCOUNT
  select @ERM=''Discovered '' + cast(@rc as varchar(100)) + '' new indexes for '' + db_name() + '' on '' + @servername  
  Raiserror(@ERM,0,1) with nowait 

  update H Set [action]='''', Status= hi.idxhealthstatus 
from ops.dbo.idxHealth h 
	inner join [OPS].[dbo].[idxHealthIssues] hi on h.DatabaseName = hi.databasename 
		and h.TableName = hi.TableName 
		and h.[schema] = hi.localschema 
       and h.IndexName = hi.IndexName 

where 1=1

  select @RC = @@ROWCOUNT
  select @ERM=''Discovered '' + cast(@rc as varchar(100)) + '' indexes with Exceptions for '' + db_name() + '' on '' + @servername  
  Raiserror(@ERM,0,1) with nowait 

END

ExitScript:

if @debug >=1
SELECT 
  [DatabaseName]
  , [Action] 
  , Status
  , Count(*) [Indexes]
FROM
	ops.dbo.idxHealth 
where 1=1 
 and DatabaseName=DB_NAME() 
Group by 
  [DatabaseName]
  , [Action] 
  , Status
order by 
	CHARINDEX([Action],''Discovery, Sampling, Detailed, Rebuilt, Retested'')
	, CHARINDEX([Status],''Discovery, Sampling, Detailed, Rebuilt, Retested'')

GO
/*DISCOVERY*/
', 
		@database_name=N'Ops', 
		@output_file_name=@LogPath, 
		-- \\wttatlassql20\E$\MSSQL11.MSSQLSERVER\MSSQL\Backup
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Sampling]    Script Date: 1/31/2017 11:16:36 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 2)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Sampling', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=4, 
		@on_fail_step_id=4, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/*SAMPLING*/
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
/*
	//msdn.microsoft.com/en-us/library/ms188388(v=sql.110).aspx  
*/
declare @ERM nvarchar(max),@ERN int, @ERS int
,@servername nvarchar(128)  , @dbname nvarchar(128)
, @RC int , @debug int 

Select @Servername = Convert(nvarchar(128),SERVERPROPERTY(''servername'')), @dbname = convert(nvarchar(128),db_name())
select @ERM = ''Sampling indexes on '' + @servername + ''.'' + @dbname 
Raiserror(@ERM,0,1) with nowait 

if not exists(select * from ops.dbo.Database_status_v where Databasename=db_name() and state_desc=''ONLINE'' and is_in_standby=0 and isnull(HAROLE,''PRIMARY'') = ''PRIMARY'' )
BEGIN
	select @ERM = ''DB is not available for index optimize''
	Raiserror(@ERM,11,1) with nowait 
	GOTO ExitScript
END

Declare @MaxFragClustered int, @MaxFragNonClustered int , @MaxFragActions tinyint 
/* Setting Default Defrag values */

Begin /* Making Sure we have Fragmentation settings */
begin try 

Settings: 
  select @MaxFragClustered = CAST(ops.dbo.fnSetting(''Fragmentation'',''Clustered'') as INT) 
  , @MaxFragNonClustered = CAST(ops.dbo.fnSetting(''Fragmentation'',''NonClustered'') as INT) 
  , @MaxFragActions = CAST(ops.dbo.fnSetting(''Fragmentation'',''MaxActions'') as tinyint) 

if @MaxFragClustered is null 
	exec ops.dbo.Settings_put ''Fragmentation'',''Clustered'',''5''
	
if @MaxFragNonClustered is null 
	exec ops.dbo.Settings_put ''Fragmentation'',''NonClustered'',''5''

if @MaxFragActions is null 
	exec ops.dbo.Settings_put ''Fragmentation'',''MaxActions'',''5''

	
	if @debug>0
	select ops.dbo.fnSetting(''Fragmentation'',''NonClustered'') [NonClustered]
	, ops.dbo.fnSetting(''Fragmentation'',''Clustered'') [Clustered]
	, ops.dbo.fnSetting(''Fragmentation'',''MaxActions'') [MaxActions]


if ((@MaxFragClustered is null) or (@MaxFragNonClustered is null) or (@MaxFragActions is null))
  GOTO Settings 
  
end try 
Begin catch 

	raiserror(''Either the fnSetting Function, Settings_put procedure, or settings table is missing?'',11,1) 
	Goto ExitScript 

end catch
END 

DECLARE idxcursor CURSOR READ_ONLY FOR 
select -- Top 5 
	[idrow]
	, ix.[schema]
	, ix.TableName
	, ix.IndexName
	, ix.StatsDate
	, [status] as [ScanType]
	, ix.partition_number 
from 
	[ops].[dbo].[idxHealth] ix
where 1=1 
	and ix.[Status] in (''Discovered'',''Retest'') 
	and ix.DatabaseName = db_name() 

DECLARE @idRow int, @stmt varchar(max), @statsdate datetime, @schema nvarchar(128), @table nvarchar(128), @index  nvarchar(128), @scantype nvarchar(128) , @partition_number int 

OPEN idxcursor

FETCH NEXT FROM idxcursor INTO @idrow, @schema, @Table, @index, @statsdate, @Scantype, @partition_number
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
--	  select @MaxFragActions = @MaxFragActions - 1 
--	   if @MaxFragActions=0 GOTO OnErrorExitCursor

	  select @Scantype=''SAMPLED'' 

		SELECT @STMT = @servername+''.''+@schema+''.''+@dbname+''.''+@table+''.''+@index + '' ('' + isnull(CAST(@partition_number as varchar(10)),''NULL'') + '') [''+@scantype+'']'' 
		-- Raiserror(@stmt,0,1) with nowait 
	
		declare @spid int 
		select @spid = @@spid
			BEGIN TRANSACTION 
				update ops.dbo.idxHealth set [Status] = ''Scanning'', [spid]=@spid where idRow=@idRow 
			COMMIT TRANSACTION

		BEGIN TRY
	

--if isnull(@debug,0) < 1
BEGIN

BEGIN TRANSACTION 

INSERT INTO ops.[dbo].[idxHealth]
           ([ServerName]
           ,[DatabaseName]
		   , [schema]
           ,[TableName]
           ,[IndexName]
           ,[StatsDate]
           ,[type_desc]
           ,[partition_number]
           ,[index_depth]
           ,[index_type_desc]
           ,[avg_fragmentation_in_percent]
           ,[fragment_count]
           ,[page_count]
           ,[record_count]
           ,[alloc_unit_type_desc]
           ,[Action]
           ,[Status])
SELECT 
		@servername as servername
		,@dbname as DatabaseName 
		, sc.name as [Schema]
		, ob.name [TableName]
		,b.[name] as [IndexName]
		, STATS_DATE(b.object_id,b.index_id) as [statsdate]
		,b.type_desc 
		, a.[partition_number]
		,a.[index_depth]
		,a.[index_type_desc]
		,a.[avg_fragmentation_in_percent]
		,a.[fragment_count]
		,a.[page_count]
		,a.[record_count]
		,a.alloc_unit_type_desc
		, ''Sampling'' as [Action]
		, ''Sampled'' as [Status] -- Sampled
		FROM 
			sys.objects ob 
			inner join sys.schemas sc on sc.[schema_id] = ob.[schema_id] 
			INNER JOIN sys.indexes AS b ON ob.[object_id] = b.[object_id] --and b.type_desc in (''CLUSTERED'',''NONCLUSTERED'')
			Cross Apply sys.dm_db_index_physical_stats (DB_ID(), B.[object_id], B.index_id , @partition_number, @scantype) AS a
		WHERE 1=1
		  and ob.type=''U''
		  and sc.name=@schema
		  and ob.name = @table
		  and b.name = @index


		  update ops.dbo.idxHealth set [Status] = ''Scan Complete'',[spid]=null where idRow=@idRow 

COMMIT TRANSACTION

END 

		End Try

		Begin Catch

		update ops.dbo.idxHealth set [Status] = + '' Failed Sampling'', [spid]=null  where idRow=@idRow 

		select @ERM = isnull(@stmt,''Null @stmt'') + '' Raised Error''+ char(10) + ERROR_MESSAGE(), @ERS = ERROR_SEVERITY() 
		Raiserror(@ERM,@ERS,1)

			IF @ERS > 11 Goto OnErrorExitCursor

		End Catch

	  waitfor delay ''00:00:01'' 

	END
	FETCH NEXT FROM idxcursor INTO @idrow, @schema, @Table, @index, @statsdate, @Scantype, @partition_number
END

OnErrorExitCursor: 

CLOSE idxcursor
DEALLOCATE idxcursor

WHILE @@TRANCOUNT > 0 
BEGIN
	Rollback transaction 
END

ExitScript:

if @debug >=1
SELECT 
  [DatabaseName]
  , [Action] 
  , Status
  , Count(*) [Indexes]
FROM
	ops.dbo.idxHealth 
where 1=1 
 and DatabaseName=DB_NAME() 
Group by 
  [DatabaseName]
  , [Action] 
  , Status
order by 
	CHARINDEX([Action],''Discovery, Sampling, Detailed, Rebuilt, Retested'')
	, CHARINDEX([Status],''Discovery, Sampling, Detailed, Rebuilt, Retested'')

/*SAMPLING*/
', 
		@database_name=N'Ops', 
		@output_file_name=@LogPath, 
		@flags=2
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 3)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Rebuilding', 
		@step_id=3, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=4, 
		@on_fail_step_id=4, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command = N'/*REBUILDING*/

SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET QUERY_GOVERNOR_COST_LIMIT 2000;

nukeemdanno: 
/*
	//msdn.microsoft.com/en-us/library/ms188388(v=sql.110).aspx  
*/
declare @ERM nvarchar(max),@ERN int, @ERS int
,@servername nvarchar(128)  , @dbname nvarchar(128)
, @RC int , @debug int , @MaxFragActions int 

-- GOTO ExitScript  --ABORTING

SELECT @debug= null 
select @MaxFragActions = CAST(ops.dbo.fnSetting(''Fragmentation'',''MaxActions'') as tinyint) 

if not exists(select * from ops.dbo.Database_status_v where Databasename=db_name() and state_desc=''ONLINE'' and is_in_standby=0 and isnull(HAROLE,''PRIMARY'') = ''PRIMARY'')
BEGIN
	select @ERM = ''DB is not available for index optimize''
	Raiserror(@ERM,11,1) with nowait 
	GOTO ExitScript
END
/*  
		TODO: Watch for log file growth 
*/
DEclare @recoverymodel nvarchar(100) 
select @recoverymodel=recovery_model_desc 
from  ops.dbo.Database_status_v where Databasename=db_name()

Select @Servername = Convert(nvarchar(128),SERVERPROPERTY(''servername'')), @dbname = convert(nvarchar(128),db_name())

UPDATE [ops].[dbo].[idxHealth] SET Spid=null
	, [Action] = COALESCE([ACtion]+char(10),'''') + '' Abandonded SPID Found in '' + isnull([Status],''NULL'')
	, [Status] = COALESCE([Status],''NULL'') + '' ERROR'' 
WHERE [Spid] is not null 

/*
	After a detailed SCAN, we can then Skip, mark Completed or leave to the Cursor to rebuild 
*/

if isnull(Cast(ops.dbo.fnSetting(''Fragmentation'',''MinPageCount'') as int),0) < 4 
		exec ops.dbo.Settings_put ''Fragmentation'',''MinPageCount'',''100''


Begin

update ix SET status = CASE [status] when ''Retest'' then ''Complete'' else ''Skipped'' end  
from 
	[ops].[dbo].[idxHealth] ix with (nolock)
where 1=1 
and ix.Action = ''Sampling''
and ix.Status in (''Sampled'',''Retest'')
and ix.DatabaseName = db_name() 
and (1=0 
	or ix.page_count <= Cast(ops.dbo.fnSetting(''Fragmentation'',''MinPageCount'') as int)
	OR ix.type_desc=''CLUSTERED'' and ix.avg_fragmentation_in_percent < ops.dbo.fnSetting(''Fragmentation'',''Clustered'')  
	OR ix.type_desc=''NONCLUSTERED'' and ix.avg_fragmentation_in_percent <  ops.dbo.fnSetting(''Fragmentation'',''NonClustered'') 
	)

END 

select @ERM = ''Index Fragmentation Allowed for NonClustered:'' + 
	ops.dbo.fnSetting(''Fragmentation'',''NonClustered'') +
	'' And  Clustered:'' + ops.dbo.fnSetting(''Fragmentation'',''Clustered'') + '' Max number of Tables Touched '' + cast(@MaxFragActions as varchar(10)) + char(10) 

IF @debug >= 1
   Raiserror(@ERM,0,1) with nowait 

	if object_id(''tempdb..#RebuildList'') is not null 
	Drop Table #RebuildList 


create table [#RebuildList](
	[id] int identity(1,1) ,
	[idrow] int NOT NULL,
	[dbname] nvarchar(256) NOT NULL, 
	[schema] nvarchar(256) NOT NULL,
	[TableName] nvarchar(256) NOT NULL,
	[IndexName] nvarchar(256) NOT NULL,
	[StatsDate] datetime,
	[partition_number] smallint,
	[Status] varchar(150),
	[type_desc] varchar(150),
	[avg_fragmentation_in_percent] float(8),
	[page_count] int,
	[record_count] bigint
)

  -- Exec ops.dbo.settings_put ''Fragmentation'',''MaxActions'',''5''
Declare @stmt nvarchar(max) 
select @stmt=''SELECT TOP '' + ops.dbo.fnSetting(''Fragmentation'',''MaxActions'')+''
	[idrow]
	, db_name()
	, ix.[schema]
	, ix.TableName
	, ix.IndexName
	, ix.StatsDate
	, ix.partition_number 
	, [Status] 
	, ix.type_desc
	, ix.avg_fragmentation_in_percent
	, ix.page_count
	, ix.record_count
from 
	[ops].[dbo].[idxHealth] ix with (nolock)
where 1=1 
--and ix.Action in (''''Detailed'''')--,''''Rebuild'''')
and ix.[Status] in (''''Sampled'''',''''Retest'''')
and ix.DatabaseName = db_name() 
and (1=0						
	OR ix.type_desc=''''CLUSTERED'''' and ix.avg_fragmentation_in_percent > ops.dbo.fnSetting(''''Fragmentation'''',''''Clustered'''')
	--OR ix.type_desc=''''NONCLUSTERED'''' and ix.avg_fragmentation_in_percent > ops.dbo.fnSetting(''''Fragmentation'''',''''NonClustered'''') 
	)
Order by 
	ix.[Status] DESC -- Lets get all the Sampled runs completed before retesting 
	, ix.page_count DESC 

''
--if @debug = 1 
--Raiserror(@STMT,0,1) with nowait

DECLARE @RowCount int 

insert into #RebuildList ([idrow],[dbname], [schema], [TableName], [IndexName], [StatsDate], [partition_number], [Status], [type_desc], [avg_fragmentation_in_percent], [page_count], [record_count])
EXEC (@STMT)

  SET @RowCount = isnull(@@ROWCOUNT,0) 
  --SELECT @RowCount

if @RowCount < 1 -- CAST(ops.dbo.fnSetting(''Fragmentation'',''MaxActions'') as int) -- Null is false 
BEGIN
 
 if @debug is not null  
	Raiserror(''All Primary Keys are under the allowed fragmentation'',0,1) 

select @stmt=''SELECT TOP '' + ops.dbo.fnSetting(''Fragmentation'',''MaxActions'')+''
	[idrow]
	, db_name()
	, ix.[schema]
	, ix.TableName
	, ix.IndexName
	, ix.StatsDate
	, ix.partition_number 
	, [Status] 
	, ix.type_desc
	, ix.avg_fragmentation_in_percent
	, ix.page_count
	, ix.record_count
from 
	[ops].[dbo].[idxHealth] ix with (nolock)
where 1=1 
--and ix.Action in (''''Detailed'''')--,''''Rebuild'''')
and ix.[Status] in (''''Sampled'''')
and ix.DatabaseName = db_name() 
and (1=0						
	--OR ix.type_desc=''''CLUSTERED'''' and ix.avg_fragmentation_in_percent > ops.dbo.fnSetting(''''Fragmentation'''',''''Clustered'''')
	OR ix.type_desc=''''NONCLUSTERED'''' and ix.avg_fragmentation_in_percent > ops.dbo.fnSetting(''''Fragmentation'''',''''NonClustered'''') 
	)
Order by 
	ix.[Status] DESC -- Lets get all the Sampled runs completed before retesting 
	, ix.page_count DESC 

''
if @debug > 1 
Raiserror(@STMT,0,1) with nowait
  
insert into #RebuildList ([idrow], [dbname], [schema], [TableName], [IndexName], [StatsDate], [partition_number], [Status], [type_desc], [avg_fragmentation_in_percent], [page_count], [record_count])
EXEC (@STMT)

END
ELSE
BEGIN

insert into #RebuildList ([idrow], [dbname], [schema], [TableName], [IndexName], [StatsDate], [partition_number], [Status], [type_desc], [avg_fragmentation_in_percent], [page_count], [record_count])
SELECT 
	ix.[idrow]
	, db_name()
	, ix.[schema]
	, ix.TableName
	, ix.IndexName
	, ix.StatsDate
	, ix.partition_number 
	, ix.[Status] 
	, ix.type_desc
	, ix.avg_fragmentation_in_percent
	, ix.page_count
	, ix.record_count
from
	[ops].[dbo].[idxHealth] ix with (nolock)
	inner join #RebuildList RB on RB.dbname = ix.DatabaseName and rb.TableName = ix.TableName 
	left outer join #RebuildList RB2 on RB2.dbname = ix.DatabaseName and rb2.TableName = ix.TableName and rb2.IndexName=ix.IndexName and rb2.partition_number = ix.partition_number
where 1=1 
 and ix.[Action] = ''Sampling'' -- Should be 100% of the index+partitionSchema
 and rb2.partition_number is null 
Order by 
	ix.[Status] DESC -- Lets get all the Sampled runs completed before retesting 
	, ix.page_count DESC 


END 


if @debug > 1 
BEGIN
	select ops.dbo.fnSetting(''Fragmentation'',''Clustered'') [Setting]
	select * From #RebuildList order by TableName, type_desc
	Goto Exitscript 
END


/* Number of impacting Executions  Allowed */

DECLARE idxcursor CURSOR READ_ONLY FOR 
select 
	[idrow]
	, [schema]
	, TableName
	, IndexName
	, StatsDate
	, partition_number 
	, ''Rebuild'' [ScanType]
	--, Status 
	, type_desc
	--, avg_fragmentation_in_percent
	--, page_count
	--, record_count
FROM #RebuildList 
 order by TableName, type_desc

DECLARE @idRow int, @statsdate datetime, @schema nvarchar(128), @table nvarchar(128), @index  nvarchar(128), @scantype nvarchar(128) , @partition_number int, @typeDESC nvarchar(50)

OPEN idxcursor

FETCH NEXT FROM idxcursor INTO @idrow, @schema, @Table, @index, @statsdate, @partition_number, @scantype, @typeDesc --, @Frag 
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN


		SELECT @STMT = char(10) + ''IDRow ('' + cast(@idRow as varchar(100)) + '')'' + @servername+''.''+@dbname+''.''+@schema+''.''+@table+''.''+@index + '' ''+ @typeDesc +'' [''+@scantype+''] /* SPID: ''+ CAST(@@SPID as VArchar(10)) +'' */'' 
	
	if @debug is not null 
		Raiserror(@stmt,0,1) with nowait 

BEGIN TRY
	IF @scantype=''REBUILD'' 
	BEGIN

			SELECT @stmt = ''ALTER INDEX ['' + @index +''] on [''+ @schema +''].[''+ @table +''] REBUILD '' 
			+ Case when @partition_number > 1 then ''PARTITION = '' + cast(@partition_number as varchar(10)) else '''' end 
			--+ '' WITH ( ONLINE = ON ( WAIT_AT_LOW_PRIORITY (MAX_DURATION = 10 minutes, ABORT_AFTER_WAIT = SELF )))''
			+'' WITH (SORT_IN_TEMPDB = ON, MAXDOP = 0)''
			+'';''

	END

		Raiserror(@stmt,0,1) with nowait 
		
		if isnull(@debug,0) < 2
		BEGIN

		Begin Transaction
				update ops.dbo.idxHealth set [Status] = ''Rebuild'', [spid]=@@spid where idRow=@idRow 
		Commit transaction

				Exec(@Stmt) 

			select @stmt = ''UPDATE STATISTICS [''+ @schema +''].[''+ @table +'']'' -- ['' + @index +''];'' 
			
			if @debug > 0 Raiserror(@stmt,0,1) with nowait 
			Exec(@Stmt) 

		Begin Transaction
			update ops.dbo.idxHealth set [spid]=null where idRow=@idRow 
		Commit Transaction 

		END
				

		END TRY

		Begin Catch

		select @ERM = isnull(@stmt,''Null @stmt'') + '' Raised Error''+ char(10) + ERROR_MESSAGE(), @ERS = ERROR_SEVERITY() 
		Raiserror(@ERM,@ERS,1)

				update ops.dbo.idxHealth set [Status]=''Failed in Rebuild'', [Action] = isnull([Action],'''') +'': '' + @ERM, [spid]=null  where idRow=@idRow 

			Goto OnErrorExitCursor

		End Catch

		/* Exit every so often to let trn backups clear the logs */
		select @MaxFragActions = @MaxFragActions - 1 
			  if @MaxFragActions=0 GOTO OnErrorExitCursor

	END
	FETCH NEXT FROM idxcursor INTO @idrow, @schema, @Table, @index, @statsdate,@partition_number, @scantype, @typeDesc
END

OnErrorExitCursor: 

CLOSE idxcursor
DEALLOCATE idxcursor

while @@TRANCOUNT > 0 
Begin 
  Rollback
End 


ExitScript:


if @debug >= 1
SELECT 
  [DatabaseName]
  , [Action] 
  , Status
  , Count(*) [Indexes]
FROM
	ops.dbo.idxHealth ix
where 1=1 
 and DatabaseName=DB_NAME() 
 --and IndexName=''PK_SoftDeletedResultSummaryResults''
--and (1=0 
--	or ix.page_count <= Cast(ops.dbo.fnSetting(''Fragmentation'',''MinPageCount'') as int)
--	OR ix.type_desc=''CLUSTERED'' and ix.avg_fragmentation_in_percent < ops.dbo.fnSetting(''Fragmentation'',''Clustered'')  
--	OR ix.type_desc=''NONCLUSTERED'' and ix.avg_fragmentation_in_percent <  ops.dbo.fnSetting(''Fragmentation'',''NonClustered'') 
--	)
Group by 
  [DatabaseName]
  , [Action] 
  , Status
order by 
	CHARINDEX([Action],''Discovery, Sampling'')
	, CHARINDEX([Status],''Discovery, Complete, Sampled, Detailed, Rebuilt, Retested'')

--if @ers is null 
-- goto nukeemdanno

/*REBUILDING*/', 
		@database_name=N'Ops', 
		@output_file_name=@LogPath, 
		@flags=2
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Reporting]    Script Date: 1/31/2017 11:16:36 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 4)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Reporting', 
		@step_id=4, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'
SET QUOTED_IDENTIFIER ON;
SET QUERY_GOVERNOR_COST_LIMIT 2000;
DECLARE @dbname nvarchar(300)
SET @dbname=db_name()
EXECUTE [ops].[dbo].idxHealthReport @dbname=@dbname
', 
		@database_name=N'Ops', 
		@output_file_name= @LogPath , 
		@flags=2
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Retasking]    Script Date: 1/31/2017 11:16:36 AM ******/
IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobsteps WHERE job_id = @jobId and step_id = 5)
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Retasking', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'/*RETASKING*/
SET NOCOUNT ON; 
declare @command nvarchar(4000) , @filename varchar(max), @rc int 
DECLARE @jobName nvarchar(255), @id int, @StepName nvarchar(max), @ERM nvarchar(max) , @ERS int, @ERN int 
declare @database_id int , @dbname nvarchar(128), @flags int, @strid nvarchar(10) , @servername nvarchar(255)
, @debug int = null 

Select @Servername = Convert(nvarchar(128),SERVERPROPERTY(''servername'')) --, @dbname = convert(nvarchar(128),db_name())

/*Rename the log file */

IF 1=1
BEGIN

  select @filename = ops.dbo.fnSetting(''dbaIndexoptimize'',''Log File Path'') 
  if @Filename is null 
   Select @filename = ops.dbo.fnSetting(''Instance'',''BackupDirectory'') +''\dbaindexoptimize.log''

   /*SET IT HERE AND IT STICKS*/
   exec ops.dbo.Settings_put @context=''dbaIndexoptimize'', @name=''Log File Path'', @value=@filename
   
DECLARE @tmstamp varchar(max)
	SELECT @tmstamp = CONVERT(varchar(100),getdate(),21)
	SELECT @tmstamp = REPLACE(REPLACE(REPLACE(REPLACE(@tmstamp,''-'',''''),''.'',''''),'':'',''''),'' '',''-'')
	declare @cmdout table (Line nvarchar(max)) 

	select top 1 @command = [value] from ops.dbo.fn_Split(@filename,''\'') order by idx desc 

	select @command = ''REN "''+@filename+''" '' + REPLACE(@command,''.log'',''-''+@tmstamp + ''.log'')  
	insert into @cmdout(line)
	exec @rc = xp_cmdshell @command 

	select @ERM = isnull(@command,''Null @command'') + char(10)+ ''Return Code:'' + cast(@RC as varchar(100)) 

	SELECT @ERM = COALESCE(@ERM+char(10),'''') + isnull(Line,''NULL'') from @cmdout 
	if @debug > 0
	Raiserror(@ERM,0,1) with nowait 

END
/*Updates the job steps to point to the next database */
IF 1=1
BEGIN
  -- select * from ops.dbo.Database_status_v 
  select @dbname = null 

select top 1 @database_id=database_id,  @dbname=DatabaseName
 -- select * 
   FROM ops.dbo.Database_status_v 
where 1=1 
 and DatabaseName not in (''model'',''tempdb'') 
 and isnull(HARole,''PRIMARY'') in (''PRIMARY'')
 and is_in_standby=0 
 and state_desc=''ONLINE''
 and Database_id > isnull(ops.dbo.fnSetting(''dbaIndexoptimize'',''DatabaseID''),0) 
 order by database_id 

 --select @strid ,@database_id, @dbname

select @strid = isnull(Convert(nvarchar(10),@database_id),''1''), @dbname=isnull(@dbname,''master''), @database_id = isnull(@database_id,1) 
--select @strid ,@database_id, @dbname 

exec ops.dbo.Settings_put @context=''dbaIndexoptimize'',@Name=''DatabaseID'', @value=@strid, @debug=@debug
 
SELECT @ERM = ''Moving TO '' + @dbname
Raiserror(@ERM,0,1) with nowait 

DECLARE jobStep CURSOR READ_ONLY FOR 
Select jb.name, step_id, step_name  from msdb.dbo.sysjobsteps js 
 inner join msdb.dbo.sysjobs jb on jb.job_id = js.job_id and jb.name=''dbaIndexOptimize''
where 1=1
order by step_id 

OPEN jobStep

FETCH NEXT FROM jobStep INTO @jobName, @id, @StepName
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		if @debug > 0
		raiserror(@StepName,0,1) with nowait 
		Begin Try 

			SELECT @flags = CASE WHEN @ID=1 then 0 else 2 end -- Sets Step one to overwrite / Create a New File
			if @StepName=''Retasking'' 
				select @Filename = '''', @Flags=null -- Prevents the Retasking Step from Failing becuase it is trying to rename a file it is using. 
				, @dbname=''Ops''

			exec msdb.dbo.sp_update_jobstep @job_name=@jobname , @step_id=@id, @step_name=@stepName , @database_name=@dbname,@output_file_name=@Filename, @flags=@flags

		End Try

		Begin Catch

			select @ERM = ERROR_MESSAGE()
			, @ERN = ERROR_NUMBER() 
			, @ERS = ERROR_SEVERITY() 
								
			SELECT @ERM = ''ErrorNumber:'' + CAST(@ERN as varchar(10))+'' ErrorSeverity:''+Cast(@ERS as varchar(10)) + char(10) + @ERM 

			Raiserror(@ERM,@ERS,1)

			IF @ERS > 11 Goto OnErrorExitCursor

		End Catch

	END
	FETCH NEXT FROM jobStep INTO @jobName, @id, @StepName
END

OnErrorExitCursor: 

CLOSE jobStep
DEALLOCATE jobStep 
END 
/* RETASKING */
', 
		@database_name=N'Ops', 
		@flags=20
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'dbaIndexOptimize', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=8, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20170126, 
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




