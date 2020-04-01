use ops 


--INSERT INTO Ops.[dbo].[Tasks]([job_id],[step_name],[commandtype],[command])
--     VALUES (@job_id,@Step_Name,@command_type,@command)
IF 1=2
BEGIN

with MyTasks (ID,Job_id,Command,[PassFail] )
as (
	SELECT 1 id, newid() job_id
	, 'waitfor delay ''00:00:' + Right('0'+CAST(Cast(abs(checksum(newid()) % 60) as Tinyint) as varchar(2)),2) + '''' Command 
	, Cast(abs(checksum(newid()) % 100) as Tinyint) [PassFail]
	 Union ALL 
	 SELECT id+1,newid() job_id
	 , 'waitfor delay ''00:00:' + Right('0'+CAST(Cast(abs(checksum(newid()) % 60) as Tinyint) as varchar(2)),2)+''''
	 , Cast(abs(checksum(newid()) % 100) as Tinyint) [PassFail]
	 from MyTasks
	)
INSERT INTO Ops.[dbo].[Tasks]([job_id],[step_name],[commandtype],[command])
select top 100 
	Job_id, 'WorkerTestID' + cast(ID as varchar(20)),'TSQL'
	,Command + char(10) + CASE when [PassFail] < 10 then char(10)+ 'Raiserror(''Failed'',11,1);' else '' end 
from MyTasks OPTION (MAXRECURSION 500);

END 

if 1=2
 EXECUTE ops.[dbo].Task_Manager 
        @maxworkers=30
        ,@debug=1




if 1=2 

SELECT TOP 1000 [idTask]
      ,[job_id]
      ,[WorkerName]
      ,[step_name]
      ,[commandtype]
      ,[command]
      ,[result]
      ,[LoginName]
      ,[RequestDate]
      ,[TaskState]
      ,[spid]
  FROM [Ops].[dbo].[Tasks]




--if object_id('tempdb..#enum_job') is null 
--begin
	
--	if object_id('tempdb..#enum_job') is not null 
--	Drop Table #enum_job 


--  create table #enum_job ( 
--Job_ID uniqueidentifier, 
--Last_Run_Date int, 
--Last_Run_Time int, 
--Next_Run_Date int, 
--Next_Run_Time int, 
--Next_Run_Schedule_ID int, 
--Requested_To_Run int, 
--Request_Source int, 
--Request_Source_ID varchar(100), 
--Running int, 
--Current_Step int, 
--Current_Retry_Attempt int, 
--State int 
--)       

--insert into #enum_job 
--exec master.dbo.xp_sqlagent_enum_jobs 1,'sa',null  
--END 

--SELECT 
--	job.name
--FROM 
--    msdb.dbo.sysjobs job 
--    left outer join msdb.dbo.syscategories sc on sc.category_id = job.category_id 
--where 1=1 
--    --and sc.name in ('EIAOPS','YDPAGES') 
--    and sc.name = 'OpsWorker' 



select
  t.TaskState
  , count(*)
from 
  ops.dbo.Tasks t 
Group by 
  T.TaskState


select 
  job.name [Job]
  , sc.name [schedule]
  , sc.enabled 
from 
  msdb.dbo.sysjobs job 
  inner join msdb.dbo.syscategories ct on ct.category_id = job.category_id 
  inner join msdb.dbo.sysjobschedules jsc on jsc.job_id = job.job_id 
  inner join msdb.dbo.sysschedules sc on sc.schedule_id = jsc.schedule_id 
where ct.name in ('eiaops','ydpages','opsworker')



select top 10 
  t.commandtype
  , t.command
  , replace(t.result,'.','.'+char(10)) [Result]
  , t.spid
from 
 ops.dbo.Tasks t
 where 1=1 
  and TaskState ='Failed'
order by 
   t.starttime Desc 
for xml auto, elements , root('Tasks')




  -- Executed as user: SLTAD\svc_sqla_bidbdev01ph. Incorrect syntax near 'Raiserrror'. [SQLSTATE 42000] (Error 102).  The step failed.
