use ops
go

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'idxAnalysis_get' )
   DROP PROCEDURE dbo.idxAnalysis_get
GO

-- =============================================
-- Author:		Randy
-- Create date: 20150520
-- Description:	Returns the status of indexes on the instance
-- =============================================
CREATE PROCEDURE dbo.idxAnalysis_get 
	@databasename nvarchar(255) = null, 
	@outfile varchar(max) = null  ,
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 

--if not exists(select top 1 * from ops.dbo.idxHealth where databasename=@databasename)
if @debug > 1 
begin 
	select @ERM = coalesce(@ERM,'') + h.DatabaseName+ char(10)
	from ops.dbo.idxHealth h
	group by h.DatabaseName
	select @ERM = '@databasename is required or was not found, select from the following;' + char(10) + @ERM 
	Raiserror(@ERM,0,1) with nowait 
end 

if object_id('tempdb..#Filter') is not null 
	Drop Table #Filter 

select 
	ix.databasename
	, ix.[schema] 
	, ix.tablename 
	, ix.indexname 
	, ix.partition_number
	into #Filter 
from 
	[ops].[dbo].[idxHealth] ix with (nolock)
where 1=1 
and ix.status='Retest'
and ((isnull(@DatabaseName,'')='') OR ([databasename]=@databasename ))
Group by 
	ix.databasename
	, ix.[schema] 
	, ix.tablename 
	, ix.indexname 
	, ix.partition_number

--if @debug = 2 
 select 'Filter' as [Temptable], * from #Filter 


select 
	h.databasename
	, h.[schema] 
	, h.tablename 
	, h.indexname 
	, h.partition_number 
	, h.[action] 
	, h.[status]  
	, h.avg_fragmentation_in_percent
	, collected 
from 
	ops.dbo.idxHealth h
	inner join #Filter f on f.DatabaseName=h.DatabaseName and f.[schema] = h.[schema] and f.TableName=h.TableName and f.IndexName=h.IndexName
where 1=1 
Order by 
	h.databasename
	, h.[schema] 
	, h.tablename 
	, h.indexname 
	, isnull(h.partition_number,0) 



END
GO


IF 1=2
BEGIN

	exec sp_help_executesproc @procname='idxAnalysis_get', @schema='dbo'

DECLARE @databasename nvarchar(max) = null 
	,@outfile varchar(max) = null 
	,@debug int  = null 

SELECT @databasename = 'PerfGate' --nvarchar
	,@outfile = @outfile --varchar
	,@debug = 1 --int

EXECUTE [dbo].idxAnalysis_get @databasename = @databasename --nvarchar
	,@outfile = @outfile --varchar
	,@debug = @debug --int


END