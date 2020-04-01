SET QUERY_GOVERNOR_COST_LIMIT 0
go

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

Print 'Server:' + convert(varchar(100),Serverproperty('Servername')) 

DECLARE
	 @RebuildTableFrag tinyint 
	,@RebuildIndexFrag tinyint 
	,@ReOrgIndexFrag tinyint 
	,@Reportonly bit 
	,@MaxRunMinutes int 
	,@doStats bit 
	,@SampleType varchar(10)
	,@Debug int 

SET NOCOUNT ON;
SET ROWCOUNT 0;

SET @debug=0

SELECT @RebuildTableFrag=ISNULL(@RebuildTableFrag,60)
, @RebuildIndexFrag=ISNULL(@RebuildIndexFrag,30)
, @ReOrgIndexFrag = isnull(@ReOrgIndexFrag,5) 
, @SampleType = 'Sampled'
, @SampleType = 'Detailed'


 if object_id('tempdb..#Results') is null
 BEGIN

 if object_id('tempdb..#Results') is not null
   drop table #Results 

SELECT 
 sc.name [schema]
, ob.name [Table]
,b.[name] as [IndexName]
,b.type_desc 
,a.[index_id]
,a.[index_type_desc]
,a.[avg_fragmentation_in_percent]
,a.[fragment_count]
,a.[page_count]
,a.[record_count]
, CASE WHEN a.[avg_fragmentation_in_percent] > 75 then '[RebuildTable]'
	WHEN [avg_fragmentation_in_percent] > 30 then '[RebuildIndex]'
	WHEN [avg_fragmentation_in_percent] > 5 then '[ReOrgIndex]'
	ELSE 'NO ACTION REQUIRED' END as [Recomendation]
, 'ALTER INDEX ALL ON ['+sc.name+'].[' + OBJECT_NAME (a.[object_id]) + '] REBUILD WITH (FILLFACTOR = 80, SORT_IN_TEMPDB = ON, STATISTICS_NORECOMPUTE = OFF);' as [RebuildTable]
, 'ALTER INDEX [' + b.[name] + '] ON ['+ sc.name+'].[' + OBJECT_NAME (a.[object_id]) + '] REBUILD WITH (FILLFACTOR = 80, SORT_IN_TEMPDB = ON, STATISTICS_NORECOMPUTE = OFF);' as [RebuildIndex]
, 'ALTER INDEX [' + b.[name] + '] ON ['+ sc.name+'].[' + OBJECT_NAME (a.[object_id]) + '] REORGANIZE;' as [ReOrgIndex]
, 'ALTER INDEX [' + b.[name] + '] ON ['+ sc.name+'].[' + OBJECT_NAME (a.[object_id]) + '] REBUILD WITH ( FILLFACTOR = 90, PAD_INDEX  = ON, STATISTICS_NORECOMPUTE  = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON, ONLINE = OFF, SORT_IN_TEMPDB = ON )' as [SQL2005] 
into #Results
FROM 
	sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, @SampleType) AS a
	-- sys.dm_db_index_operational_stats
    INNER JOIN sys.indexes AS b ON a.object_id = b.object_id AND a.index_id = b.index_id
	INNER JOIN sys.objects ob on ob.[object_id] = b.[object_id]
	inner join sys.schemas sc on sc.[schema_id] = ob.[schema_id]
WHERE 1=1
 and b.type_desc not in ('HEAP','XML')
 and a.index_level=0
 and a.[page_count] > 4
Order by
  OBJECT_NAME (a.[object_id]), index_type_desc ,a.index_id


update #Results SET [Recomendation] = 'NO ACTION REQUIRED' 
where  1=1 
 and index_id != 1 
 and [Table] in (select [Table] from #Results where [Recomendation]='[RebuildTable]')

Raiserror('Collection Complete',0,1) with nowait 

END 

DECLARE @Tablename sysname
, @indexname sysname
, @Recomended varchar(40)
, @stmt nvarchar(4000)
, @msg nvarchar(max)
, @frag real


RecurseMe: 
select @stmt = 'KILL ' + cast(@@spid as varchar(50)) + char(10) 
Raiserror(@stmt,0,1) 

DECLARE IXC CURSOR READ_ONLY FOR 
Select top 1 [Table], [IndexName],[Recomendation],
	 Case [Recomendation] when '[RebuildTable]' then [RebuildTable]
	 when '[RebuildIndex]' then [RebuildIndex] 
	 when '[ReOrgIndex]' then [ReOrgIndex] 
	 end as [stmt] 
	 , [avg_fragmentation_in_percent]
	from #Results 
WHERE [Recomendation] != 'NO ACTION REQUIRED'
order by 
  CHARINDEX([Recomendation],'[RebuildTable] [RebuildIndex] [ReOrgIndex]') 


OPEN IXC
  declare @Then datetime 
  select @then = getdate() 

FETCH NEXT FROM IXC INTO @tableName, @indexname, @Recomended, @stmt, @frag
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		Begin Try


		  Raiserror(@stmt,0,1) with nowait	
		  IF ISNULL(@Debug,1)=0 
		    Exec (@stmt)

		  if @Recomended = '[RebuildTable]' 
		  	 select @stmt='UPDATE STATISTICS ' + @tablename
		  else 
		     select @stmt='UPDATE STATISTICS ' + @tablename + ' ' + @indexname 

		   Raiserror(@stmt,0,1) with nowait
		   IF ISNULL(@Debug,1)=0 
		     Exec (@stmt)

		update #results set [Recomendation]='NO ACTION REQUIRED' where [IndexName] = @indexname
		  /* http://msdn.microsoft.com/en-us/library/ms187348.aspx  */
		  --UPDATE STATISTICS @tableName

		End Try 
		Begin Catch

			SELECT @stmt = COALESCE(@stmt,'') + char(10) + ERROR_MESSAGE()
			Raiserror(@stmt,0,1) with nowait 

	
		End Catch
	END
	FETCH NEXT FROM IXC INTO @tableName, @indexname, @Recomended, @stmt, @frag
END

onErrorExitCursor: 

CLOSE IXC
DEALLOCATE IXC

if exists (select * from #Results where Recomendation != 'NO ACTION REQUIRED')
  GOTO RecurseMe 

ExitScript: 
