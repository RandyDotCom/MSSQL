USE [OPS]
GO

/****** Object:  StoredProcedure [dbo].[IndexUsageHistory_get]    Script Date: 8/2/2016 11:38:07 AM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexUsageHistory_get]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[IndexUsageHistory_get]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexUsageHistory_get]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[IndexUsageHistory_get] AS' 
END
GO


--ALTER procedure [dbo].[IndexUsageHistory_get]
--	@tablename nvarchar(300)=null
--	, @threshold bigint = null 
--	, @debug int = null 
--AS 
--BEGIN
--/* Original Author was likely Geoffrey Glanz
--   RE-Factored by Randy Pitkin 2016-08-01 
--*/
--SET NOCOUNT ON; 
--truncate table OPS.dbo.IndexUsageHistoryStage ;
--EXEC sp_msforeachdb 'USE ?;
--Insert  OPS.dbo.IndexUsageHistoryStage([CollectionDate],[database_name],[object_id],[tablename],[indexname],[user_seeks],[user_scans],[User_lookups])
--select 
--	CAST(GETDATE() AS Date) 
--	,db_name()
--	,t1.object_id
--	,convert(nvarchar(300),object_name(object_id)) AS Tablename
--	,Convert(nvarchar(300),t2.name) AS indexname
--	,user_seeks
--	,user_scans
--	,User_lookups 
--from 
--	sys.dm_db_index_usage_stats t1
--	inner join dbo.sysindexes t2 on (t1.object_id = t2.id and t1.index_id = t2.indid)
--where 1 = 1 -- database_id = db_ID(?)
--AND user_seeks = 0
--AND user_scans = 0
--and user_lookups = 0
--and t1.database_ID > 4
--AND db_name() <> ''OPS''
--order by 2;
--';

--EXEC sp_msforeachdb 'USE ?;
--INSERT OPS.dbo.IndexUsageHistory(
--	CollectionDate
--	, database_name
--	, tablename
--	, indexname
--	, user_seeks
--	, user_scans
--	, User_lookups
--	, IndexSizeKB
--	, IndexSizeMB
--	, IndexSizeGB)
--SELECT 
--	t3.collectiondate
--	, t3.database_name
--	, convert(nvarchar(300),t3.tablename) tablename
--    , convert(nvarchar(300),i.name) AS IndexName
--	, user_seeks
--	, user_scans
--	, User_lookups 
--	, SUM(s.used_page_count) * 8   AS IndexSizeKB
--	, SUM(s.used_page_count) * 8/1024 AS IndexSizeMB
--	, SUM(s.used_page_count) * 8/1048576 AS IndexSizeGB
--FROM 
--	sys.dm_db_partition_stats  AS s 
--	INNER JOIN sys.indexes AS i ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id
--	INNER JOIN OPS.dbo.IndexUsageHistoryStage t3 on t3.object_id = s.object_id and t3.indexname = i.name 
--WHERE 1=1 
-- --and s.[object_id] = object_id(@tablename)
--GROUP BY 
--	t3.collectiondate
--	,t3.database_name
--	,t3.tablename
--	, i.name
--	,user_seeks
--	,user_scans
--	,user_lookups
----HAVING SUM(s.used_page_count) * 8/1024 >= @threshold
--ORDER BY 3 desc
--';

--if 1=2
--BEGIN
--	declare @cols nvarchar(max) 
--	select @cols = coalesce(@cols+',','') + '[' + name + ']' from sys.columns where object_id=object_id('IndexUsageHistoryStage') 
--	Print @cols 
--END

--if @debug > 0 
--  select * from dbo.IndexUsageHistory

--END
--GO

----if 1=2
--Begin

----exec sp_help_executesproc 'IndexUsageHistory_get','dbo'
--DECLARE @tablename nvarchar(max) = null 
--	,@threshold bigint  = null 
--	,@debug int  = null 

--SELECT @tablename = @tablename --nvarchar
--	,@threshold = @threshold --bigint
--	,@debug = @debug --int

--EXECUTE [dbo].IndexUsageHistory_get @tablename = @tablename --nvarchar
--	,@threshold = @threshold --bigint
--	,@debug = @debug --int

--end  

----IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UNUSEDIndexHistory]') AND type in (N'U'))
----DROP TABLE [dbo].[UNUSEDIndexHistory]
----GO

----IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexUsageHistory]') AND type in (N'U'))
----Raiserror('Table IndexUsageHistory is missing',11,1) with nowait 
----GO

----IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexUsageHistoryStage]') AND type in (N'U'))
----Raiserror('Table IndexUsageHistorystage is missing',11,1) with nowait 
----GO