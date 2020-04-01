USE [Ops]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[idxHealthAuditor]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[idxHealthAuditor]
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

--IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[idxHealthAuditor]') AND type in (N'P', N'PC'))
--BEGIN
--EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[idxHealthAuditor] AS' 
--END
--GO

--ALTER Procedure [dbo].[idxHealthAuditor] 
--	@dbname nvarchar(400) = null , 
--	@table sysname = null,
--	@index sysname = null,
--	@scantype varchar(20) = null, 
--	@debug int = null 
--AS 
--BEGIN
--SET NOCOUNT ON; 

--declare @servername varchar(max) 
--select @servername = convert(Varchar(max),serverproperty('servername')) 

--select @scantype = CASE WHEN @scantype='DETAILED' then 'DETAILED' else 'SAMPLED' end 

---- Valid inputs are DEFAULT, NULL, LIMITED, SAMPLED, or DETAILED. The default (NULL) is LIMITED. 

--Declare @stmt varchar(max) , @tsql varchar(max)
--Select @tsql='
--INSERT INTO [ops].[dbo].[idxFragmentation]
--           ([ServerName]
--           ,[DatabaseName]
--           ,[TableName]
--           ,[IndexName]
--           ,[type_desc]
--           ,[partition_number]
--           ,[object_id]
--           ,[index_id]
--		   ,[StatsDate]
--           ,[index_depth]
--           ,[index_type_desc]
--           ,[avg_fragmentation_in_percent]
--           ,[fragment_count]
--           ,[page_count]
--           ,[record_count]
--           ,[alloc_unit_type_desc]
--		   ,[status])
--SELECT 
--''' + @servername + ''' as servername
--,''@dbname'' as DatabaseName 
--, ob.name [TableName]
--,b.[name] as [IndexName]
--,b.type_desc 
--, a.[partition_number]
--,b.[object_id]
--,a.[index_id]
--, STATS_DATE(b.[object_id], a.index_id) [StatsDate]
--,a.[index_depth]
--,a.[index_type_desc]
--,a.[avg_fragmentation_in_percent]
--,a.[fragment_count]
--,a.[page_count]
--,a.[record_count]
--,a.alloc_unit_type_desc
--,''' + @scantype + '''
--FROM 
--	[@dbname].sys.objects ob 
--	INNER JOIN [@dbname].sys.indexes AS b ON ob.[object_id] = b.[object_id] and b.type_desc in (''CLUSTERED'',''NONCLUSTERED'')
--	Cross Apply [@dbname].sys.dm_db_index_physical_stats (DB_ID(), B.[object_id], B.index_id , NULL, '''+@scantype+''') AS a
--WHERE 1=1
-- and ob.type in (''U'')
-- and a.index_level=0
-- and a.[page_count] > 4
-- ' + CASE WHEN @table is null then '' else ' and ob.name=''' + @table + '''' end + '
-- ' + CASE WHEN @index is null then '' else ' and b.name=''' + @index + '''' end + ''

--DECLARE dbc CURSOR READ_ONLY FOR 
--SELECT [DatabaseName],[database_id]
--      --,[compatibility_level],[state_desc],[recovery_model_desc],[is_in_standby],[HARole]
--  FROM [Ops].[dbo].[Database_status_v]
--WHERE 1=1
--	and [DatabaseName] not in ('tempdb','model') 
--	and [is_in_standby] = 0
--	and [state_desc] = 'ONLINE'
--	and isnull([HARole],'PRIMARY')='PRIMARY'
--	and ((isnull(@dbname,'')='') or ([DatabaseName]=@dbname))


--DECLARE @name nvarchar(max), @database_id varchar(5) 
--, @ERM nvarchar(max) , @ERS int, @ERN int 
--OPEN dbc

--FETCH NEXT FROM dbc INTO @name, @database_id
--WHILE (@@fetch_status <> -1)
--BEGIN
--	IF (@@fetch_status <> -2)
--	BEGIN

--		Raiserror(@name,0,1) with nowait 
--		Begin Try 

--			Select @stmt = replace(@tsql,'@dbname',@name)
--			Select @stmt = replace(@stmt,'@Scantype','sampled')
--			SELECT @stmt = replace(@stmt,'DB_ID()',@database_id)

--		if @debug > 0 raiserror(@stmt,0,1) with nowait 

--		if isnull(@debug,0) < 2
--		exec (@stmt)
		
--		End Try

--		Begin Catch
--			select @ERM = isnull(@name,'Null @name') + ' Raised Error'+ char(10) + ERROR_MESSAGE() + char(10) + @stmt
--			, @ERS = ERROR_SEVERITY() 
--			, @ERN = ERROR_NUMBER() 

--			Raiserror(@ERM,@ERS,1) with nowait 

--			--IF @ERS > 11 Goto OnErrorExitCursor

--		End Catch

--	END
--	FETCH NEXT FROM dbc INTO @name, @database_id
--END

--OnErrorExitCursor: 


--CLOSE dbc
--DEALLOCATE dbc

--END 
--GO


--if 1=2
--BEGIN

--	-- exec sp_help_executesproc 'idxHealthAuditor' 

--DECLARE @dbname nvarchar(max) = null 
--	,@table sysname  = null 
--	,@index sysname  = null 
--	,@scantype varchar(20) = null 
--	,@debug int  = null 

--SELECT @dbname = 'PerfGate' --nvarchar
--	,@table = @table--'ResultsC' --sysname
--	,@scantype = @scantype--'Sampled' --varchar
--	,@index = @index --sysname
--	,@debug = 1 --int

----select @scantype='DETAILED'

--EXECUTE ops.[dbo].idxHealthAuditor @dbname = 'PerfGate' --PerfGate'--nvarchar
--	,@table = @table --sysname
--	,@index = @index --sysname
--	,@scantype = @scantype --varchar
--	,@debug = @debug --int



--END


---- select * FROM OPS.dbo.idxFragmentation


