USE OPS 
GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'sp_who3' )
   DROP PROCEDURE dbo.sp_who3
GO

-- =============================================
-- Author:		Randy
-- Create date: 20170719
-- Description:	Extends sp_who2 for better tools
-- =============================================
CREATE PROCEDURE dbo.sp_who3 
	@doAggregate bit = NULL , 
	@IgnoreBlockers bit = null, 
	@getDetails bit = NULL , 
	@GetSpid int = null, 
    @login sysname = NULL, 
	@database sysname = NULL  ,
	@hostname sysname = NULL ,
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
SET XACT_ABORT ON
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 

--if object_id('tempdb..#sp_who3') is not null
--   drop table #sp_who3 

CREATE TABLE #sp_who3 
( 
    SPID INT, 
    [Status] SYSNAME NULL, 
    [Login] SYSNAME NULL, 
    HostName SYSNAME NULL, 
    BlkBy SYSNAME NULL, 
    DBName SYSNAME NULL, 
    Command SYSNAME NULL, 
    CPUTime INT NULL, 
    DiskIO INT NULL, 
    LastBatch varchar(400) NULL, 
    ProgramName SYSNAME NULL, 
    SPID2 INT null,
    RequestID int null  
) 
 
INSERT #sp_who3 EXEC sp_who2 --'active' 



update #sp_who3 SET LastBatch = LEFT(LastBatch,5) + '/' + cast(YEAR(getdate()) as char(4)) +' '+ RIGHT(LastBatch,8)
update #sp_who3 set [BlkBy]=null where [BlkBy] = '  .'

if @debug=2 
BEGIN
	select * from #sp_who3 
	return 1; 
END

IF @doAggregate =1 -- Aggregate 
BEGIN

SELECT 
	DBName
	, HostName
	, [Login] 
	, COUNT(*) [Spids]
	, MAX(CONVERT(Datetime,LastBatch)) [LastBatch]
	, datediff(minute,MAX(CONVERT(Datetime,LastBatch)),getdate()) AgeinMins
FROM 
	#sp_who3
where 1=1 
	and [Login] != 'sa'	
	and dbname not in ('master','msdb')
GROUP BY
	 DBNAME, HostName , [Login]
Order by 
	AgeinMins, DBNAME, HostName , [Login] 

Return 1; 
END 

	
if exists (select * from #sp_who3 where blkby is not null ) and (isnull(@IgnoreBlockers,0)=0)
Begin 


Begin Try 

;with spidCTE ([BlockingLevel],[BlkBy],[Spid],Status,[HostName],[Login],[DBName],[CPUTime],[Diskio],[LastBatch],[ProgramName]) AS
(
  select 1 as [BlockingLevel],[BlkBy],[Spid],Status,[HostName],[Login],[DBName],[CPUTime],[Diskio],[LastBatch],[ProgramName] 
	From #sp_who3 where spid in (select blkby from #sp_who3 ) and blkby is null 
  UNION ALL 
  select [BlockingLevel]+1,s.[BlkBy],s.[Spid],s.Status,s.[HostName],s.[Login],s.[DBName],s.[CPUTime],s.[Diskio],s.[LastBatch],s.[ProgramName]
	From #sp_who3 s
	  inner join spidCTE on spidCTE.[Spid] = s.BlkBy and s.SPID != S.BlkBy
)
Select *
from spidCTE 
  order by BlockingLevel
  , LastBatch 
  OPTION (MAXRECURSION 400); 
  
 End Try 
 Begin Catch 
	Print convert(nvarchar(max),Error_message()) 

 end Catch 
   

select * From #sp_who3 
where spid in (select blkby from #sp_who3 where isnull(blkby,spid) != spid )
and blkby is null 

end 


if isnull(@getDetails,0) =0 and isnull(@GetSpid,0)=0 
Begin 

SELECT 
	isnull(('Kill ' + CASE WHEN [BlkBy] = '  .' then NULL else CAST([BlkBy] as varchar(10)) end),'') as [KillMe]
	,[SPID]
	,[Status]
	,[Login]
	,[HostName]
	,[DBName]
	,[CPUTime]
	,[DiskIO]
	,Convert(varchar(20),(Convert(datetime,[LastBatch])),0) [LastBatch]
	,[ProgramName]
	--,[Command]
	--,[SPID2]
	--,[RequestID]
	--,[BlkBy]
FROM 
	#sp_who3 
WHERE 1=1
  and  ([login] <> 'sa' or [Login]=@login) 
  and (isnull(@login,'')='' or [login] like @login )  
  and (isnull(@hostname,'')='' or [HostName] like @hostname )  
  and ([DBName] not in ('master','tempdb','msdb','model','AdminTools') or [DBName] = @database )
  and (isnull(@database,'')='' or [DBName] = @database) 
ORDER by
 CASE WHEN @IgnoreBlockers=1 then null else [BlkBy] end  DESC 
--, CONVERT(Datetime,LastBatch)  
 , CASE WHEN Diskio > CpuTime then Diskio else cputime end desc 	

end 

if @getDetails=1 or @GetSpid > 0
BEGIN

SELECT 
	es.host_name 
	, es.login_name 
	, es.session_id [SPID]
	   , st.objectid as ModuleObjectId
	   -- ,convert(XML,'<nd><![CDATA[' + SUBSTRING(st.text, er.statement_start_offset/2 + 1,(CASE WHEN er.statement_end_offset = -1 THEN LEN(CONVERT(nvarchar(max),st.text)) * 2 ELSE er.statement_end_offset + 10  END - er.statement_start_offset)/2) + ']]></nd>') as [Query_Text]
	   , convert(xml,('<nd><![CDATA[' + st.text + ']]></nd>')) as [text]
	   , DB_NAME(st.dbid) as QueryExecContextDBNAME
	   , es.program_name
			, tsu.session_id ,tsu.request_id, tsu.exec_context_id, 
       (tsu.user_objects_alloc_page_count - tsu.user_objects_dealloc_page_count) as OutStanding_user_objects_page_counts,
       ((tsu.user_objects_alloc_page_count - tsu.user_objects_dealloc_page_count)) * 8 / 1000 as OutStanding_user_objects_page_counts_MB,
       (tsu.internal_objects_alloc_page_count - tsu.internal_objects_dealloc_page_count) as OutStanding_internal_objects_page_counts,
       ((tsu.internal_objects_alloc_page_count - tsu.internal_objects_dealloc_page_count)) * 8 / 1000 as OutStanding_internal_objects_page_counts_MB,
       er.start_time, er.command, er.open_transaction_count, er.percent_complete, er.estimated_completion_time, er.cpu_time, er.total_elapsed_time, er.reads,er.writes, 
       er.logical_reads, er.granted_query_memory
FROM sys.dm_db_task_space_usage tsu 
	inner join sys.dm_exec_requests er ON ( tsu.session_id = er.session_id and tsu.request_id = er.request_id) 
	inner join sys.dm_exec_sessions es ON ( tsu.session_id = es.session_id ) 
    CROSS APPLY sys.dm_exec_sql_text(er.sql_handle) st
WHERE 1=1 
  and ((es.session_id in (select Blocked from master..sysprocesses where blocked > 0)) and (isnull(@getspid,0)=0))
  or (es.session_id=@GetSpid) 

 -- and (tsu.internal_objects_alloc_page_count + tsu.user_objects_alloc_page_count) > 0
ORDER BY (tsu.user_objects_alloc_page_count - tsu.user_objects_dealloc_page_count)+(tsu.internal_objects_alloc_page_count - tsu.internal_objects_dealloc_page_count) 
DESC

 


END

IF 1=2 
BEGIN
 
 select distinct hostname from #sp_who3 
 where 1=1 and Login != 'SA'
 
  select distinct hostname from #sp_who3 
 where 1=1 and Login != 'SA'

 declare @stmt nvarchar(max) 

 select @stmt = COALESCE(@STMT+char(10),'') +'KILL ' + CAST([Spid] as Varchar(100))
   -- select 'KILL ' + cast(Spid as varchar(10)) 
  from #sp_who3 
  where 1=1 
  and [BlkBy] is null 
  and [Spid] in (select BlkBy from #sp_who3)
   --and LastBatch <= DATEADD(Day,-2,getdate()) 
  and ProgramName like '%SQL Server Management Studio%' 
  and CHARINDEX('\',[Login]) != 0
  and [Spid] != @@SPID

EXEC (@STMT)


if 1=2
BEGIN

exec sp_msdroptemptable '#Jobs' 

Create Table #jobs(
	[session_id] int null
	,[job_id] uniqueidentifier 
	,[job_name] sysname null
	,[run_requested_date] datetime null
	,[run_requested_source] sysname null
	,[queued_date] datetime null
	,[start_execution_date] datetime null
	,[last_executed_step_id] int null
	,[last_exectued_step_date] datetime null
	,[stop_execution_date] datetime null
	,[next_scheduled_run_date] datetime null
	,[job_history_id] int null
	,[message] nvarchar(1024) null
	,[run_status] int null
	,[operator_id_emailed] int null
	,[operator_id_netsent] int null
	,[operator_id_paged] int null
) 

insert into #jobs
EXEC msdb.dbo.sp_help_jobactivity  ;                                        

select 
 job_name
 , last_executed_step_id 
 , *  
from #Jobs 
where 1=1 
 and [start_execution_date] is not null 
 and [stop_execution_date] is null

end 

END
	
END
GO


IF 1=2
BEGIN
	exec sp_help_executesproc @procname='sp_who3'
	DECLARE @doAggregate bit  = null 
	,@IgnoreBlockers bit  = null 
	,@getDetails bit  = null 
	,@GetSpid int  = null 
	,@login sysname  = null 
	,@database sysname  = null 
	,@hostname sysname  = null 
	,@debug int  = null 

SELECT @doAggregate = @doAggregate --bit
	,@IgnoreBlockers = 1 --bit
	,@getDetails = 1 --bit
	,@GetSpid = @GetSpid --int
	,@login = @login --sysname
	,@database = @database --sysname
	,@hostname = @hostname --sysname
	,@debug = @debug --int

EXECUTE [dbo].sp_who3 @doAggregate = @doAggregate --bit
	,@IgnoreBlockers = @IgnoreBlockers --bit
	,@getDetails = @getDetails --bit
	,@GetSpid = @GetSpid --int
	,@login = @login --sysname
	,@database = @database --sysname
	,@hostname = @hostname --sysname
	,@debug = @debug --int


END