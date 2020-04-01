USE OPS
go

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'Task_history' )
   DROP PROCEDURE dbo.Task_history
GO

-- =============================================
-- Author:		Randy
-- Create date: 20150304
-- Description:	Report and Cleanup
-- =============================================
CREATE PROCEDURE dbo.Task_history 
	@Sendto varchar(max) = null, 
	@PurgeAge int = null  ,
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 

declare @report nvarchar(max) 

select @PurgeAge = isnull(@PurgeAge,7) 

delete from ops.dbo.tasks where RequestDate < dateadd(Day,-@purgeAge,convert(Date,getdate()))

update ops.dbo.tasks set WorkerName = SUBSTRING(WorkerName,len('Worker_863410A4-2553-40CB-935C-AC91174435E9__'),100) 
where 1=1 
 and TaskState in ('Succeeded','Failed','Job Failed') 
 and WorkerName like 'Worker_%'



if 1=2
Begin
 select top 10 * from ops.dbo.Tasks 
 select distinct taskState from ops.dbo.Tasks 
-- Failed
--Succeeded
--Job Failed
--New
--Starting

end 

select 
	workername 
	, count(distinct job_id) [JobCount]
	, TaskState
	, Convert(date,[RequestDate]) [RequestDay]
from 
	 ops.dbo.Tasks 
Group by 
	workername 
	, TaskState
	, Convert(date,[RequestDate]) 
having 
  count(distinct job_id) > 1 
order by 
	RequestDay DESC, 
	JobCount DESC,
 WorkerName 


END
GO


IF 1=2
BEGIN
	exec sp_help_executesproc @procname='Task_history', @schema='dbo'

DECLARE @Sendto varchar(max) = null 
	,@PurgeAge int  = null 
	,@debug int  = null 

SELECT @Sendto = @Sendto --varchar
	,@PurgeAge = @PurgeAge --int
	,@debug = @debug --int

EXECUTE [dbo].Task_history @Sendto = @Sendto --varchar
	,@PurgeAge = @PurgeAge --int
	,@debug = @debug --int

select * FROM ops.dbo.tasks where step_name like '%OSGTFS01%'
END

