use Ops
GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'SQLAgentJobs_Report' )
   DROP PROCEDURE dbo.SQLAgentJobs_Report
GO

-- =============================================
-- Author:		Randy
-- Create date: 09302014
-- Description:	Returns the status of SQLAgent jobs
-- =============================================
CREATE PROCEDURE dbo.SQLAgentJobs_Report 
	@job_name varchar(max) = null, 
	@ErrorsOnly bit = null, 
	@category varchar(50) = null,
	@ReportType varchar(100) = null, 
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
SET NOCOUNT ON;

declare @enum  table (v int, d varchar(10))
insert into @enum (v,d) 
SELECT 0,'Failed'
union 
SELECT 1,'Succeeded'
union 
SELECT 2,'Retry'
union 
SELECT 3,'Canceled'

if @debug is not null 
  begin
	select @ERM = '@ReportType=' +@ReportType 
	Raiserror(@ERM,0,1) with nowait 
  end 

select 
	job.job_id
  , job.name 
  , Sum(CASE WHEN jh.run_status=1 then 0 else 1 end) [Fails]
  , Count(JH.instance_id) [Runs] 
into #RunData
from 
 msdb.dbo.sysjobs job 
 left outer join msdb.dbo.sysjobhistory jh on jh.job_id = job.job_id 
where 1=1 
 and jh.step_id=0 
group by 
	job.name , job.job_id


if object_id('tempdb..#lastruns') is not null 
 drop Table #LastRuns 

select 
	serverproperty('Servername') [Servername]
, job.name [job]
, jc.name [category]
, job.job_id
, job.enabled [JobEnabled]
, sp.name [Owner]
, (select max(msdb.dbo.jobtime(run_date,run_time,null)) from  msdb.dbo.sysjobhistory tj1 where tj1.job_id=job.job_id and tj1.step_id=0 and tj1.run_status=0) [LastFailedRun]
--, (select max(msdb.dbo.jobtime(run_date,run_time,run_duration)) from  msdb.dbo.sysjobhistory tj1 where tj1.job_id=job.job_id and tj1.step_id=0 and tj1.run_status=0) [LastFailedRunEnd]
, (select max(msdb.dbo.jobtime(run_date,run_time,null)) from  msdb.dbo.sysjobhistory tj2 where tj2.job_id=job.job_id and tj2.step_id=0 and tj2.run_status=1) [LastSuccessfulRun]
, (select max(msdb.dbo.jobtime(run_date,run_time,null)) from  msdb.dbo.sysjobhistory tj3 where tj3.job_id=job.job_id and tj3.step_id=0) [LastRun]
, (select sc.name , sc.enabled from msdb.dbo.sysjobschedules jsc 
	   left outer join msdb.dbo.sysschedules sc on jsc.schedule_id = sc.schedule_id
	where  jsc.job_id = Job.job_id for xml auto) [Schedules]
, rd.Fails
, rd.[Runs]
into #LastRuns
 from  msdb.dbo.sysjobs job 
	left outer join msdb.dbo.syscategories jc on jc.category_id = job.category_id 
	left outer join master.sys.server_principals sp on sp.sid = job.owner_sid 
	left outer join #RunData RD on rd.job_id = job.job_id 
WHERE 1=1 
	and ((isnull(@job_name,'')='') OR (job.name=@job_name))
	and ((isnull(@category,'')='') OR (jc.name=@category))



if object_id('tempdb..#JobErrorDetails') is not null 
 drop Table #JobErrorDetails 

select 
  job.name [Job]
  , job.job_id 
  , jh.step_id
  , jh.step_name 
  , nm.d [run_status]
  , msdb.dbo.jobtime(jh.run_date, jh.run_time, null) [stepStart]
  , msdb.dbo.jobtime(jh.run_date, jh.run_time, jh.run_duration) [stepend]
  , jh.run_duration
  , jh.sql_severity
  , jh.message
  --, Convert(xml,replace(jh.message,'  ',char(10) + ' ')) [ErrorMessage]
into #JobErrorDetails 
from 
  msdb.dbo.sysjobs job 
  inner join msdb.dbo.sysjobhistory jh on jh.job_id = job.job_id 
  inner join #LastRuns lr on lr.job_id = job.job_id 
  inner join @enum nm on nm.v = jh.run_status
where 1=1 
	and lr.[LastFailedRun] >= lr.LastRun
    and msdb.dbo.jobtime(jh.run_date, jh.run_time, null) >= lr.[LastFailedRun]
	--and msdb.dbo.jobtime(jh.run_date, jh.run_time, null) >= lr.[LastFailedRun]
	and ((isnull(@ErrorsOnly,0)=0) OR (nm.d='Failed'))
order by 
	msdb.dbo.jobtime(jh.run_date, jh.run_time, null)

	--select * From msdb.dbo.sysjobhistory

IF @reporttype='XML'
BEGIN
--select * from #JobErrorDetails

declare @report XML 
SELECT @report = (
SELECT 
		[LastRun].Servername
		,[LastRun].category
		,[LastRun].job
		, Case WHEN LastRun is null then 'NoHistory'
				WHEN LastFailedRun = LastRun then 'Failed' 
				WHEN LastSuccessfulRun = LastRun then 'Succeeded' 
				ELSE 'Running' end [Status]
		, [LastRun].job_id
		,JobEnabled
		,LastFailedRun
		,LastSuccessfulRun
		,LastRun
		, [Fails]
		, [Runs]
		, Schedules.name
		, Schedules.enabled
		, Schedules.next_run_date
		, Schedules.next_run_time
		, JobErrors.step_id 
		, JobErrors.step_name 
		, JobErrors.run_status
		, JobErrors.message
	from 
		#LastRuns [LastRun]
		left outer join (select js.job_id,ss.Name, ss.enabled, js.next_run_date,js.next_run_time from msdb.dbo.sysjobschedules js
						left outer join msdb.dbo.sysschedules [ss]  on js.schedule_id=[ss].schedule_id
						) Schedules on Schedules.job_id=[LastRun].job_id
		left outer join #JobErrorDetails JobErrors on JobErrors.job_id=LastRun.job_id and stepstart>= LastRun and step_id> 0
	FOR XML AUTO, Root('Jobs')	
	) 

	--if @report is not null 
	--Begin
	--	exec [dbo].[xmlReports_put] @Property='SQLAgent', @context='Jobs Report', @xdata=@Report, @debug=@debug  
	--End 


IF OBJECT_ID('tempdb..#drives') is not null 
	DROP TABLE #drives 

	Create Table #drives (drive varchar(1), mbfree int) 

	insert into #drives(drive,mbfree) 
	exec master.sys.xp_fixeddrives 

IF OBJECT_ID('tempdb..#FileStats') is not null 
	DROP TABLE #FileStats 

		SELECT * 
		into #FileStats 
		FROM sys.dm_io_virtual_file_stats(Null,null) 
			--  cross apply sys.dm_io_virtual_file_stats (md.database_id, md.file_id ) fd 
			--  select * from #filestats

declare @xdata xml 

  select @xdata = (
  select 
  	convert(nvarchar(255),serverproperty('servername')) [Servername], 
	convert(nvarchar(255),serverproperty('ProductVersion')) [ProductVersion], 
	--@@VERSION as [ProductVersion],
	* from (
select top 100 PERCENT 
	md.DatabaseName
	, md.recovery_model_desc
	, CASE WHEN is_in_standby=1 then 'Standby' else  isnull(md.HARole,'Online') end [DBStatus] 
	-- , md.is_in_standby 
	, mf.NAme [LogicalName]
	, mf.[type_desc]
	, mf.Physical_name 
	, mf.size 
	--, cast((mf.growth / 128) as varchar(100)) + ' ' + case when mf.is_percent_growth =1 then '%' else 'mb' end [Growth]
	, mf.max_size 
	, dr.mbfree 
	--, (dr.mbfree  / (mf.growth / 128)) [Growths]
	--, Round((CAST(mf.size as real) / CAST((fs.size_on_disk_bytes / 8032) as REal)) * 100,0) [Fullness]
from 
  ops.[dbo].[Database_status_v] md
  inner join master.sys.master_files mf on md.database_id = mf.database_id 
  inner join #drives dr on dr.drive = left(mf.Physical_name,1) 
  inner join #filestats fs on fs.database_id = mf.database_id and fs.[file_id] = mf.[file_id] 
where 1=1 
 --and mf.database_id > 4 /* Excludes System Databases */
 and (is_in_standby=0 and ISNULL([HARole],'Primary')='Primary') 
 --and type_desc != 'ROWS'
order by 
	md.DatabaseName
	, mf.file_id
	, mf.Physical_name 
) [agg]
for xml auto, root('FileData')

) 


select @xdata = '<MSSQL>' + convert(varchar(max),@xdata) + '</MSSQL>'
Set @xdata.modify('insert sql:variable("@report") as last into (/MSSQL)[1]')

if Object_ID('master.sys.dm_hadr_availability_replica_cluster_nodes') is not null 
BEGIN

	if @debug is not null 
	  Raiserror('Trying for HADR Data',0,1) with nowait 

declare @hadr xml 
Create Table #MyHadr (replica_server_name nvarchar(300),AG_Group nvarchar(300),role_desc nvarchar(300),database_name nvarchar(300),Listener_Name nvarchar(300), synchronization_state_desc nvarchar(300),synchronization_health_desc nvarchar(300))

declare @stmt nvarchar(max) 
SELECT @STMT = '
select 
	ar.replica_server_name as replica_server_name,
	ag.name as AG_Group,
	ars.role_desc,
	dcs.database_name, 
	agl.dns_name as Listener_Name
		, rs.synchronization_state_desc
	, rs.synchronization_health_desc
from 
	master.sys.dm_hadr_database_replica_states rs
	inner join master.sys.availability_replicas ar on rs.replica_id = ar.replica_id
	inner join sys.dm_hadr_database_replica_cluster_states dcs on dcs.group_database_id = rs.group_database_id and rs.replica_id = dcs.replica_id
	inner join sys.dm_hadr_availability_replica_states ars on ars.replica_id=rs.replica_id
	INNER JOIN master.sys.availability_groups ag on ag.group_id = rs.group_id and ag.group_id = ar.group_id
	left join sys.availability_group_listeners agl on ag.group_id = agl.group_id
	--left join sys.availability_group_listener_ip_addresses aglip on aglip.listener_id=agl.listener_id 
where 1=1 
	--and ar.replica_server_name = @@servername and aglip.state=1
order by 3
' 
insert into #MyHadr(replica_server_name ,AG_Group ,role_desc ,database_name ,Listener_Name , synchronization_state_desc ,synchronization_health_desc )
Exec (@STMT)

  if @debug=1 
    select * from #MyHadr 

IF object_id('tempdb..#MyHadr') is not null 
select @hadr=(
  SELECT * FROM #MyHadr for XML RAW, ROOT('hadr')
)

IF @hadr is not null
Set @xdata.modify('insert sql:variable("@hadr") as last into (/MSSQL)[1]')

	 --set @history.modify('insert sql:variable("@history") as last into (/history/object)[0]')
END 


  select @ReportType as [ReportType],@xdata as Report,@report as [JobReport], @hadr [hadrdata]  
  Return 1; 

end 

	SELECT 
		Servername,
		category, 
		job, 
		Case WHEN LastFailedRun = LastRun then 'Failed' 
		WHEN LastSuccessfulRun = LastRun then 'Succeeded'
		when [LastRun] is null then 'No History' 
		ELSE 'Running' end [Status],
		job_id, 
		JobEnabled, 
		LastFailedRun, 
		LastSuccessfulRun,
		LastRun,
		Schedules
	from #LastRuns
	ORDER BY Category,Job 


--select * from #JobErrorDetails

	
END
GO


IF 1=2
BEGIN

exec sp_help_executesproc 'SQLAgentJobs_Report','dbo' 

SET QUERY_GOVERNOR_COST_LIMIT 0


DECLARE @job_name varchar(max) = null 
	,@ErrorsOnly bit  = null 
	,@category varchar(50) = null 
	,@ReportType varchar(100) = null 
	,@debug int  = null 

SELECT @job_name = @job_name --varchar
	,@ErrorsOnly = 1 --bit
	,@category = @category --varchar
	,@ReportType = @ReportType --varchar
	,@debug = 1 --int

EXECUTE [dbo].SQLAgentJobs_Report @job_name = @job_name --varchar
	,@ErrorsOnly = @ErrorsOnly --bit
	,@category = @category --varchar
	,@ReportType = 'XML' --varchar
	,@debug = @debug --int



END 	

GO
