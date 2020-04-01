use ops
go

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'idxHealthReport' )
   DROP PROCEDURE dbo.idxHealthReport
GO

-- =============================================
-- Author:		Randy
-- Create date: 2015032017
-- Description:	Manages and returns idxHealth Status
-- =============================================
CREATE PROCEDURE dbo.idxHealthReport 
	@Action varchar(100)= NULL, 
	@dbname nvarchar(300) = null , 
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
SET XACT_ABORT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
if @Action is null
  Return 1;
/*
   the default does not return anything, but truncates the table when appropropriate 		
*/	
if @Action='Settings'
BEGIN
  SELECT 
   Cast(ops.dbo.fnSetting('Fragmentation','MinPageCount') as int) [MinPageCount]
  , CAST(ops.dbo.fnSetting('Fragmentation','Clustered') as INT) [maxClusteredFragmentation]
  , CAST(ops.dbo.fnSetting('Fragmentation','NonClustered') as INT) as [MaxFragNonClustered]
  , CAST(ops.dbo.fnSetting('Fragmentation','MaxActions') as tinyint) [MaxFragActions]


END


if @Action='Summary'
BEGIN 
select 
   [DatabaseName]
  , [Action] 
  , ix.type_desc 
  , Status
  , Count(*) [Indexes]
  , max(ix.avg_fragmentation_in_percent) [MaxFrag]
FROM
	ops.dbo.idxHealth ix 
	--inner join master.sys.databases m on m.name = ix.DatabaseName
where 1=1 
	and ((isnull(@dbname,'') = '') or (ix.DatabaseName=@dbname))
Group by 
  [DatabaseName]
  , [Action] 
  , ix.type_desc 
  , Status
order by 
	db_id(ix.DatabaseName)
	,CHARINDEX([Action],'Discovery, Sampling')
	, ix.type_desc 
	, CHARINDEX([Status],'Discovery, Skipped, Scan Complete, Complete, Sampled, Detailed, Rebuild, Retested')
end 

if 1=2

select 
	ix.DatabaseName
   , ix.TableName
   , ix.IndexName
   , ix.type_desc 
   , round(min(avg_fragmentation_in_percent),1) [StartingFrag]
   , round(max(avg_fragmentation_in_percent),1) [endFrag]
from 
	dbo.idxHealth ix 
where 1=1 
	and ix.page_count > Cast(ops.dbo.fnSetting('Fragmentation','MinPageCount') as int)
and (1=0 
	OR ix.type_desc='CLUSTERED' and ix.avg_fragmentation_in_percent >= ops.dbo.fnSetting('Fragmentation','Clustered')  
	OR ix.type_desc='NONCLUSTERED' and ix.avg_fragmentation_in_percent >=  ops.dbo.fnSetting('Fragmentation','NonClustered') 
	)
Group by 
  	ix.DatabaseName
   , ix.TableName
   , ix.IndexName
   , ix.type_desc 
order by  
	ix.DatabaseName
	, ix.TableName 
	, ix.type_desc 


select 
	ix.DatabaseName
   , ix.TableName
   , ix.IndexName
   , ix.type_desc 
   , ix.avg_fragmentation_in_percent 
   , ix.Action
   , ix.Status 
from 
	dbo.idxHealth ix 
where 1=1 
  and ix.DatabaseName = @dbname 
  and Action not in ('Discovery')
  and avg_fragmentation_in_percent is not null 
  and ix.page_count > Cast(ops.dbo.fnSetting('Fragmentation','MinPageCount') as int)
  and status in ('Sampled','Retest') 
and (1=0 
	OR ix.type_desc='CLUSTERED' and ix.avg_fragmentation_in_percent >= ops.dbo.fnSetting('Fragmentation','Clustered')  
	OR ix.type_desc='NONCLUSTERED' and ix.avg_fragmentation_in_percent >=  ops.dbo.fnSetting('Fragmentation','NonClustered') 
	)
order by 
	ix.type_desc 
 , ix.avg_fragmentation_in_percent  DESC 

 if 1 = NULL 
 BEGIN
  raiserror('NO NOT DO THIS',11,1)

 exec msdb.dbo.sp_update_job @job_name='dbaIndexOptimize', @enabled=0
 EXEC msdb.dbo.sp_stop_job @job_name='dbaIndexOptimize'
-- Truncate table ops.dbo.idxHealth

 end

/*
	DO I NUKE THE TABLE 
*/
if exists (select * from master.sys.databases where name not in ('model','tempdb')
				and state_desc='ONLINE' 
				and is_in_standby != 1
				and name not in (select databasename from ops.dbo.idxhealth) 
			)
begin 
	select @ERM = Coalesce(@ERM + ',','') + name 
		from master.sys.databases where name not in ('model','tempdb') 
				and name not in (select databasename from ops.dbo.idxhealth) 
	raiserror(@ERM,0,1) with nowait 
Return 1; -- First pass on each DB after Truncate 
end 


/*Resets on Nothing to do or Wednedsay at 4:00pm */
--declare @boolreset bit 

--if not exists( select 1 from dbo.idxHealth ix
--	where 1=1
--	and ix.Action = 'Sampling'
--	and ix.Status in ('Sampled','Retest')
--	and (1=0 
--		or ix.page_count > Cast(ops.dbo.fnSetting('Fragmentation','MinPageCount') as int)
--		OR ix.type_desc='CLUSTERED' and ix.avg_fragmentation_in_percent > ops.dbo.fnSetting('Fragmentation','Clustered')  
--		OR ix.type_desc='NONCLUSTERED' and ix.avg_fragmentation_in_percent >  ops.dbo.fnSetting('Fragmentation','NonClustered') 
--)) 
-- SET @boolreset =1 
 
IF (DATEPART(hour,dATEADD(hour,13,GETDATE())) = 16 and @dbname='Ops')
BEGIN
		exec('Truncate table ops.dbo.idxHealth')
END

END
GO

IF 1=2
BEGIN

--exec sp_help_executesproc @procname='idxHealthReport'

DECLARE @Action varchar(100)  
	,@dbname nvarchar(max) 
	,@debug int  

SELECT @Action = 'Report' --varchar
	--,@dbname = 'ServerPlaceHolder' --nvarchar
	,@debug = @debug --int

EXECUTE [dbo].idxHealthReport @Action = @Action --varchar
	,@dbname = @dbname --nvarchar
	,@debug = @debug --int

--select @@version
	
END
GO
IF 1=2
BEGIN

declare @Report xml 
if exists (select 1 from msdb.dbo.sysjobs where name='dbaIndexOptimize' and enabled = 1 )
Begin 
	set @Report = (
SELECT 
	Convert(nvarchar(300),SERVERPROPERTY('servername')) [Servername]
	, DatabaseName
	, [Status] 
	, ix.type_desc
	, Max(ix.avg_fragmentation_in_percent) [MaxFragFound]
	--, ix.page_count
	--, ix.record_count
	, ops.dbo.fnSetting('Fragmentation','Clustered') [ClusteredMaxSetting]
	, ops.dbo.fnSetting('Fragmentation','NonClustered') [NonClusteredMaxSetting]
from 
	[ops].[dbo].[idxHealth] ix with (nolock)
where 1=1 
and ix.[Status] in ('Sampled','Retest')
and (1=0						
	OR ix.type_desc='CLUSTERED' and ix.avg_fragmentation_in_percent > ops.dbo.fnSetting('Fragmentation','Clustered')
	OR ix.type_desc='NONCLUSTERED' and ix.avg_fragmentation_in_percent > ops.dbo.fnSetting('Fragmentation','NonClustered') 
	)
Group by 
	 DatabaseName
	, [Status] 
	, ix.type_desc
for xml auto, root('idxhealth')
	
  ) 

  
	if @Report is null 
	   if not exists(select * from ops.dbo.idxHealth)
			SELECT '<Error servername="' + convert(nvarchar(300),serverproperty('Servername')) + '">Job is enabled but does not have any data</Error>' as [Report]
		else
		 Begin
			Select @Report = (
			select Servername, DatabaseName, count(*) IxCount, Max(StatsDate) [MaxStatsDate] from ops.dbo.idxHealth idxHealth group by Servername, DatabaseName for xml auto, root('JOB') 
			) 
			select @Report [Report]
		  end 

	else
		select @Report [Report]
end 
else
begin 
	SELECT '<Error servername="' + convert(nvarchar(300),serverproperty('Servername')) + '">dbaIndexOptimize is not enabled or does not exist</Error>' as [Report]
	-- raiserror('dbaIndexOptimize is not enabled or does not exist',11,1) 
end 

--Truncate table ops.dbo.idxhealth 
END
GO

