USE [Ops]
GO

IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[SQLAgentJobs_v]'))
	DROP VIEW [dbo].[SQLAgentJobs_v]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[SQLAgentJobs_v]'))
EXEC dbo.sp_executesql @statement = N'
Create View [dbo].[SQLAgentJobs_v]
as 
select 
	serverproperty(''Servername'') [Servername]
, job.name [job],jc.name [category]
, job.job_id
, job.enabled [JobEnabled]
, job.date_created 
, job.date_modified
, isnull(cast(jsc.next_run_date as varchar(100)),''ND'') + '' T '' + isnull(cast(jsc.next_run_time as varchar(100)),''NT'') as [NextScheduledRun]
--, Case when jsc.next_run_date is null then null else msdb.dbo.jobtime(rtrim(ltrim(cast(jsc.next_run_date as varchar(100)))),rtrim(ltrim(isnull(cast(jsc.next_run_time as varchar(100)),''''))),null) end as [NextScheduledRun] 
, sc.Name [Schedule]
, sc.Enabled [SchedEnabled]
, (select count(*) from  msdb.dbo.sysjobhistory tj0 where tj0.job_id=job.job_id and tj0.step_id=0) [RunsStarted] 
, (select max(msdb.dbo.jobtime(run_date,run_time,null)) from  msdb.dbo.sysjobhistory tj1 where tj1.job_id=job.job_id and tj1.step_id=0 and tj1.run_status=0) [LastFailedRun]
, (select max(msdb.dbo.jobtime(run_date,run_time,null)) from  msdb.dbo.sysjobhistory tj2 where tj2.job_id=job.job_id and tj2.step_id=0 and tj2.run_status=1) [LastSuccessfulRun]
, (select max(msdb.dbo.jobtime(run_date,run_time,null)) from  msdb.dbo.sysjobhistory tj3 where tj3.job_id=job.job_id and tj3.step_id=0) [LastRun]
 from  msdb.dbo.sysjobs job 
	left outer join msdb.dbo.syscategories jc on jc.category_id = job.category_id 
	left outer join msdb.dbo.sysjobschedules jsc on jsc.job_id = Job.job_id
	left outer join msdb.dbo.sysschedules sc on jsc.schedule_id = sc.schedule_id
' 
GO


