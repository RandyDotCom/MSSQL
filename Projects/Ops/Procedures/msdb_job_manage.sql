use Ops
GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'msdb_job_manage' )
   DROP PROCEDURE dbo.msdb_job_manage
GO

-- =============================================
-- Author:		Randy
-- Create date: 20141224
-- Description:	Allows robust management of SQLAgent Jobs
-- =============================================
CREATE PROCEDURE dbo.msdb_job_manage 
	@job_name varchar(max) = null, 
	@job_id uniqueidentifier = null  ,
	@enabled bit = null,
	@stop bit = null,
	@start bit = null,
	@active bit = null output,
	@report bit = null, 
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 


select @job_id = job_id, @enabled = isnull(@enabled,[enabled]) from msdb.dbo.sysjobs where name= @job_name

IF @job_id is null 
BEGIN
	Select @ERM = 'Job ' + isnull(@job_name,'NULL') + ' was not found'
	Raiserror(@ERM,11,1) 
	Return 0;
END


EXEC msdb.dbo.sp_update_job @job_name=@job_name, @enabled=@enabled

create table #enum_job ( 
Job_ID uniqueidentifier, 
Last_Run_Date int, 
Last_Run_Time int, 
Next_Run_Date int, 
Next_Run_Time int, 
Next_Run_Schedule_ID int, 
Requested_To_Run int, 
Request_Source int, 
Request_Source_ID varchar(100), 
Running int, 
Current_Step int, 
Current_Retry_Attempt int, 
State int 
)       

insert into #enum_job 
exec master.dbo.xp_sqlagent_enum_jobs 1,'sa',@job_id  

SELECT @Active = case when [STATE] in (4,5) then 0 else 1 end from #enum_job

if @stop = 1 and @Active=1 
BEGIN
	EXEC msdb.dbo.sp_stop_job @job_id=@job_id 
END

if @start = 1 and @Active=0 
BEGIN
	EXEC msdb.dbo.sp_start_job @job_id=@job_id 
END

if @debug > 0 or @report > 0
select @job_name, case [STATE] WHEN 4 then 'Idle' WHEN 5 then 'Suspended' else 'Active' end [CurrentState]
 , * from #enum_job



	
END
GO

--GRANT EXECUTE ON [dbo].[msdb_job_manage] TO [REDMOND\wpopsdsh]
--GO

--GRANT EXECUTE ON [dbo].[msdb_job_manage] TO [YDPages]
--GO

IF 1=2
BEGIN
	--exec Ops..sp_help_executesproc @procname='msdb_job_manage', @schema='dbo'

DECLARE @job_name varchar(max) = null 
	,@job_id uniqueidentifier  = null 
	,@enabled bit  = null 
	,@stop bit  = null 
	,@start bit  = null 
	,@debug int  = null 

SELECT @job_name = 'Perfgate_standby Version' --varchar
	,@job_id = @job_id --uniqueidentifier
	,@enabled = @enabled --bit
	,@stop = @stop --bit
	,@start = @start --bit
	,@debug = @debug --int

EXECUTE [dbo].msdb_job_manage @job_name = @job_name --varchar
	,@job_id = @job_id --uniqueidentifier
	,@enabled = @enabled --bit
	,@stop = @stop --bit
	,@start = @start --bit
		,@debug = @debug --int

END