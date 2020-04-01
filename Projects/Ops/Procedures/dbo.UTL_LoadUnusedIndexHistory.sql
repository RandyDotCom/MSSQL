USE [OPS]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UTL_LoadUnusedIndexHistory]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[UTL_LoadUnusedIndexHistory]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO
/*

		DEADLOCKS ITSELF 

*/
--IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UTL_LoadUnusedIndexHistory]') AND type in (N'P', N'PC'))
--BEGIN
--EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[UTL_LoadUnusedIndexHistory] AS' 
--END
--GO


--ALTER procedure [dbo].[UTL_LoadUnusedIndexHistory]
--AS 
--SET NOCOUNT ON 
--truncate table OPS.dbo.IndexUsageHistoryStage ;
--EXEC sp_msforeachdb 'USE ?;
--Insert  OPS.dbo.IndexUsageHistoryStage
 
--select CAST(GETDATE() AS Date) ,db_name(),

--t1.object_id,object_name(object_id) AS Tablename,t2.name AS indexname,
--user_seeks,
--user_scans,
--User_lookups 
--from sys.dm_db_index_usage_stats t1
--	join dbo.sysindexes t2 on (t1.object_id = t2.id and t1.index_id = t2.indid)
--where 1 = 1 -- database_id = db_ID(?)
--AND user_seeks = 0
--AND user_scans = 0
--and user_lookups = 0
--and t1.database_ID > 4
--AND db_name() <> ''OPS''
--order by 2;
--';

--EXEC sp_msforeachdb 'USE ?;
--INSERT OPS.dbo.UNUSEDIndexHistory
--SELECT t3.collectiondate,t3.database_name,
--	t3.tablename,
--    i.name                  AS IndexName,
--	user_seeks,
--	user_scans,
--	User_lookups ,
--    SUM(s.used_page_count) * 8   AS IndexSizeKB,
--	SUM(s.used_page_count) * 8/1024 AS IndexSizeMB,
--	SUM(s.used_page_count) * 8/1048576 AS IndexSizeGB
--FROM sys.dm_db_partition_stats  AS s 
--JOIN sys.indexes                AS i ON s.[object_id] = i.[object_id] AND s.index_id = i.index_id
--JOIN  OPS.dbo.IndexUsageHistoryStage t3 on t3.object_id = s.object_id and t3.indexname = i.name 
----WHERE s.[object_id] = object_id(@tablename)
--GROUP BY t3.collectiondate,t3.database_name,t3.tablename, i.name,user_seeks,user_scans,user_lookups --HAVING SUM(s.used_page_count) * 8/1024 >= @threshold
--ORDER BY 3 desc
--';

GO


