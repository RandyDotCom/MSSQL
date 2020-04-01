USE OPS
GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'HADRJobManager' )
   DROP PROCEDURE dbo.HADRJobManager
GO

-- =============================================
-- Author:		Randy
-- Create date: 20160811
-- Description:	Manages SQL Agent Jobs on HADR Clusters
-- =============================================
CREATE PROCEDURE dbo.HADRJobManager 
	@debug int = null, 
	@sendto nvarchar(max) = null  
AS
BEGIN
SET NOCOUNT ON; 
SET XACT_ABORT ON
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 

 
BEGIN TRY 

select 
	ars.connected_state_desc
	, ar.replica_server_name
	, database_name
	, ars.role_desc
	--, rs.last_commit_time
	--, synchronization_state_desc
	--, rs.synchronization_health_desc
	--, log_send_queue_size
	--, log_send_rate
	--, redo_queue_size
	--, redo_rate
	--, availability_mode_desc
	--, failover_mode_desc
	--, is_suspended
	--, suspend_reason_desc
	--, is_failover_ready 
	--, is_pending_secondary_suspend
	--, secondary_role_allow_connections_desc
  into #MyHadr 
from master.sys.dm_hadr_database_replica_states rs
inner join master.sys.availability_replicas ar on rs.replica_id = ar.replica_id
inner join sys.dm_hadr_database_replica_cluster_states dcs on dcs.group_database_id = rs.group_database_id and rs.replica_id = dcs.replica_id
inner join sys.dm_hadr_availability_replica_states ars on ars.replica_id=rs.replica_id


END TRY 
BEGIN CATCH 

		SELECT @ERM = ERROR_MESSAGE(), @ERN=ERROR_NUMBER(), @ERS=ERROR_SEVERITY() 
		Raiserror(@ERM,11,1)
		Return 0; 

END CATCH 


IF @debug = 2 
Begin 
  SELECT * FROM #MyHadr 
  Return 1
END

IF Not exists(select 1 from #MyHadr)
begin 
	if @Debug > 0 
		Raiserror('This is not a HADR implementation',0,1) with nowait 

		Return 1; 
end 
if @debug is not null 
  Raiserror('This is a HADR implementation',0,1) with nowait 

DECLARE @ServerName nvarchar(300) 


ManageJobs: 
Declare @Name nvarchar(max) , @SetScheduleTo bit, @Role nvarchar(50) , @schedule_id int , @jobEnabled bit 

exec sp_msdroptemptable '#CursorToDoList'
exec ops.dbo.Settings_put @context='HADRJobManager', @name='dbaIndexOptimize', @value='Exceptions' 

SELECT * 
 Into #CursorToDoList
FROM (
select Distinct 
		Job.Name [Job]
		, job.enabled [JobEnabled]
		, sc.name 
		, sc.enabled
		, sc.schedule_id
		, CASE 
			WHEN mh.role_desc = 'PRIMARY' then 1
			when mh.role_desc != 'PRIMARY' then 0 
		   else sc.enabled end [SetScheduleTo] 
		--, mh2.replica_server_name
		--, mh2.role_desc
from 
	msdb.dbo.sysjobs job 
	inner join msdb.dbo.sysjobsteps js on js.job_id = job.job_id 
	inner join msdb.dbo.sysjobschedules jss on jss.job_id = job.job_id 
	inner join msdb.dbo.sysschedules sc on sc.schedule_id = jss.schedule_id
	inner join #MyHadr MH on js.database_name = MH.database_name and mh.replica_server_name = @@SERVERNAME 
	--CROSS join (select replica_server_name, role_desc from #MyHadr Group by replica_server_name, role_desc) MH2 
where 1=1 
  and job.name not in (select Name from ops.dbo.settings where Context='HADRJobManager' and Value='Exceptions')
) md 

declare @MyRole nvarchar(50) 
select @MyRole = (select top 1 role_desc from #MyHadr where replica_server_name = @@SERVERNAME)

/*
	How to make SSIS packages discoverable 

exec ops.dbo.Settings_put @context='HADRJobManager', @name='MRDashboard-LoadMRData', @value='Primary' 
exec ops.dbo.Settings_put @context='HADRJobManager', @name='MRDashboard-LoadT3Data', @value='Primary'

*/


insert into #CursorToDoList (job, JobEnabled, name, enabled, schedule_id, SetScheduleTo)
select 
  job.Name 
  , job.enabled [jobEnabled]
  , sc.name 
  , sc.enabled [schedenabled]
  , jss.schedule_id 
  , CASE WHEN ss.Value = @MyRole then 1 else 0 end [SetScheduleTo]
from 
	msdb.dbo.sysjobs job 
	--left outer join msdb.dbo.sysjobsteps js on js.job_id = job.job_id
	left outer join msdb.dbo.sysjobschedules jss on jss.job_id = job.job_id
	left outer join msdb.dbo.sysschedules sc on sc.schedule_id = jss.schedule_id  
    inner join  ops.dbo.Settings ss on job.name = ss.Name 
where 1=1


IF @DEBUG = 3
Begin 
 SELECT * FROM #MyHadr 
 select * from #CursorToDoList 
 REturn 1 
END 

DECLARE JobC CURSOR READ_ONLY FOR 
 select Name, JobEnabled, schedule_id, SetScheduleTo from #CursorToDoList

OPEN JobC

FETCH NEXT FROM JobC INTO @name, @jobEnabled, @schedule_id , @SetScheduleTo 
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		
		Begin Try 

		DECLARE @stmt varchar(max)
		/* I have filtered to jobs in the Incorrect state */
			SELECT @stmt = 'Setting Job: ' + @name + ' TO ' + CASE WHEN @SetScheduleTo = 1 then 'ENABLED' ELSE 'DISABLED' END 

			IF @Debug is not null 
				Raiserror(@STMT,0,1) with nowait 
		
			EXEC msdb.dbo.sp_update_schedule @schedule_id=@schedule_id, @enabled=@SetScheduleTo

		End Try

		Begin Catch

			select @ERM = isnull(@name,'Null @name') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 

			Raiserror(@ERM,@ERS,1)

			IF @ERS > 11 Goto OnErrorExitCursor

		End Catch

	END
	FETCH NEXT FROM JobC INTO @name, @jobEnabled, @schedule_id , @SetScheduleTo 
END

OnErrorExitCursor: 

CLOSE JobC
DEALLOCATE JobC



IF @DEBUG > 1 
BEGIN
  select * from #MyHadr 
  select * from #CursorToDoList
END 

END
GO


IF 1=2
BEGIN
	--exec sp_help_executesproc @procname='HADRJobManager'

DECLARE @debug int  = null 
	,@sendto nvarchar(max) = null 

SELECT @sendto = @sendto --nvarchar

EXECUTE [dbo].HADRJobManager @debug = 3--int
	,@sendto = @sendto --nvarchar

END


