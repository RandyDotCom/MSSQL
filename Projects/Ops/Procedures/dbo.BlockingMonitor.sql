use ops
go

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'BlockingMonitor' )
   DROP PROCEDURE dbo.BlockingMonitor
GO
-- =============================================
-- Author:		Randy
-- Create date: 20160414
-- Description:	Monitors For Blocking
-- =============================================
CREATE PROCEDURE dbo.BlockingMonitor 
	@sendto nvarchar(max) = null, 
	@Purge bit = null  ,
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
SET XACT_ABORT ON
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 



SET NOCOUNT ON ;
--if object_id('tempdb..#sp_who3') is null -- Comment this out to ReExecute 
BEGIN
 
 if object_id('tempdb..#sp_who3') is not null
   drop table #sp_who3 

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

END  
 
BEGIN 

IF 1=2 -- Aggregate 
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

END 

BEGIN 

 if 1=2
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
  and  [login] <> 'sa'  
  --and [BlkBy] <> '  .'
	--and [DBName] not in ('master','tempdb','msdb','model','AdminTools')
ORDER by
 [BlkBy] DESC 
--, CONVERT(Datetime,LastBatch)  
 , CASE WHEN Diskio > CpuTime then Diskio else cputime end desc 	
	
END 

	



if exists (select * from #sp_who3 where isnumeric(blkby)=1 )
Begin
if @debug > 0 
	Raiserror('Building CTE',0,1) with nowait ; 

with spidCTE ([BlockingLevel],[BlkBy],[Spid],Status,[HostName],[DBName],[CPUTime],[Diskio],[LastBatch],[ProgramName]) AS
(
  select 1 as [BlockingLevel],[BlkBy],[Spid],Status,[HostName],[DBName],[CPUTime],[Diskio],[LastBatch],[ProgramName] 
	From #sp_who3 where spid in (select blkby from #sp_who3 ) and blkby is null 
  UNION ALL 
  select [BlockingLevel]+1,s.[BlkBy],s.[Spid],s.Status,s.[HostName],s.[DBName],s.[CPUTime],s.[Diskio],s.[LastBatch],s.[ProgramName]
	From #sp_who3 s
	  inner join spidCTE on spidCTE.[Spid] = s.BlkBy and s.SPID != S.BlkBy
	  where 1=1 
	  /*IF Blocking exists you will get BlockingLevel 1 the Clause Below should only be unintended Victoms*/
	   --and (1=0 or spidCTE.ProgramName != S.ProgramName or  spidCTE.HostName != s.HostName) 
)
Select * into #Blocking from spidCTE; 



end 

if object_id('tempdb..#Blocking') is not null 
Begin
	select * from #Blocking 

	if not exists(select 1 from #Blocking) 
	begin
		update dbo.xmlReports set Property='BlockingHistory' where Property='Blocking'
		Return 1; 
	end 
END 


IF 1=2 
BEGIN
	DECLARE @xdid int  = null 
		,@Property varchar(50) = null 
		,@Context varchar(50) = null 
		,@xData xml  = null 

	SET @xdata = (select * from #Blocking Blocking for xml auto, root('RandyPitkin')) 

	SELECT @Property = 'Blocking' --varchar
		,@Context = Convert(nvarchar(255),NEWID()) 
	

	EXECUTE [dbo].xmlReports_put @xdid = @xdid OUTPUT  --int
		,@Property = @Property --varchar
		,@Context = @Context --varchar
		,@xData = @xData --xml
		,@debug = @debug --int
END 


select 
	s.n.value('@BlockingLevel','int') [BlockingLevel]
	,s.n.value('@BlkBy','int') [BlkBy]
	,s.n.value('@Spid','int') [Spid]
	,s.n.value('@Status','varchar(50)') [Status]
	,s.n.value('@HostName','varchar(50)') [HostName]
	,s.n.value('@DBName','nvarchar(300)') [DBName]
	,s.n.value('@LastBatch','datetime') [LastBatch]
	,s.n.value('@ProgramName','nvarchar(300)') [ProgramName]
	, DateCollected 
into #BlockingHistory 
from 
  dbo.xmlReports xr 
  Cross Apply xr.xData.nodes('/RandyPitkin/Blocking') s(n) 
where 1=1 
and Property='Blocking'

select 
   c.HostName
   , c.Spid
   , c.LastBatch
from 
  #BlockingHistory p 
  left outer join #BlockingHistory c on c.BlkBy = p.Spid
where 1=0
 or p.ProgramName != c.ProgramName
 or p.HostName != c.HostName

	
END
GO


IF 1=2
BEGIN
SET NOCOUNT ON;

	-- exec sp_help_executesproc @procname='BlockingMonitor'
	 --exec sp_help_executesproc @procname='xmlreports_put'

DECLARE @sendto nvarchar(max) = null 
	,@Purge bit  = null 
	,@debug int  = null 

SELECT @sendto = @sendto --nvarchar
	,@Purge = @Purge --bit
	,@debug = @debug --int

EXECUTE [dbo].BlockingMonitor @sendto = @sendto --nvarchar
	,@Purge = @Purge --bit
	,@debug = @debug --int


END

--select 
--  * 
--from 
--  dbo.xmlReports xr 
--where Property='Blocking'
--delete xr from dbo.xmlReports xr 
--where Property='Blocking'