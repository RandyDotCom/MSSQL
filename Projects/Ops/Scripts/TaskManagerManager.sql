
if object_id('tempdb..#retestlist') is null 
begin
	
	if object_id('tempdb..#retestlist') is not null 
	Drop Table #retestlist 


Select top 10 Servername 
  , svr.env
  , svr.status
  , svr.service
  , xr.context 
  , xr.DateCollected 
into #retestlist 
from dbo.servers svr 
	left outer join dbo.xmlReports xr on xr.property = svr.servername 
where 1=1 
	and svr.status not in ('DECOM','DELETE','CNAME')
	and xr.context='Services Audit'
 -- and svr.env='devtest' 
order by 
	xr.datecollected 

 select * from #retestlist 

if 1=2
BEGIN

DECLARE ServerCursor CURSOR READ_ONLY FOR 
Select Servername FROM #retestlist


DECLARE @name nvarchar(max), @ERM nvarchar(max) , @ERS int
OPEN ServerCursor

FETCH NEXT FROM ServerCursor INTO @name
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		Begin Try 

			EXECUTE [bcp].RefreshServer @Servername = @name --varchar
		
		End Try

		Begin Catch

			select @ERM = isnull(@name,'Null @name') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			

			Raiserror(@ERM,@ERS,1)

			IF @ERS > 11 Goto OnErrorExitCursor

		End Catch

	END
	FETCH NEXT FROM ServerCursor INTO @name
END

OnErrorExitCursor: 


CLOSE ServerCursor
DEALLOCATE ServerCursor
END

END
GO 


select TaskState, Count(Distinct JOB_ID) 
	from ops.dbo.tasks 
Group by Taskstate

Exec ops.dbo.TaskManager 


		Select 
			Job.name [Job]
			, job.job_id
			, ja.start_execution_date 
			, ja.stop_execution_date
		 --into #Workers
		from 
		  msdb.dbo.sysjobs job 
		  inner join msdb..sysjobactivity JA on JA.job_id = job.job_id
		  --inner join msdb.dbo.sysjobhistory jh on jh.job_id=job.job_id and jh.step_id=0
		  --left outer join msdb.dbo.sysjobsteps js on js.job_id = job.job_id and jh.step_id=js.step_id
		where 1=1 
			and ja.stop_execution_date is null
		and (1=0
		 or job.name like 'worker%'
		 or job.name = 'Ops TaskManager'
		 --or ja.stop_execution_date is null
		 )


SELECT step_name,  Replace(result,'[SQLSTATE',char(10)+'[SQLSTATE') [result]
from ops.dbo.tasks 
where 1=1 
 --and TaskState='Failed' 
 for xml Auto, elements 