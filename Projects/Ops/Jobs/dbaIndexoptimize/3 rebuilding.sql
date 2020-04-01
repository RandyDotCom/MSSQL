/*REBUILDING*/
SET QUERY_GOVERNOR_COST_LIMIT 2000
go
SET NOCOUNT ON;
/*
	//msdn.microsoft.com/en-us/library/ms188388(v=sql.110).aspx  
*/
declare @ERM nvarchar(max),@ERN int, @ERS int
,@servername nvarchar(128)  , @dbname nvarchar(128)
, @RC int , @debug int , @MaxFragActions int 

-- GOTO ExitScript  --ABORTING

SELECT @debug= 2
select @MaxFragActions = CAST(ops.dbo.fnSetting('Fragmentation','MaxActions') as tinyint) 

if not exists(select * from ops.dbo.Database_status_v where Databasename=db_name() and state_desc='ONLINE' and is_in_standby=0 and isnull(HAROLE,'PRIMARY') = 'PRIMARY')
BEGIN
	select @ERM = 'DB is not available for index optimize'
	Raiserror(@ERM,11,1) with nowait 
	GOTO ExitScript
END
/*  
		TODO: Watch for log file growth 
*/
DEclare @recoverymodel nvarchar(100) 
select @recoverymodel=recovery_model_desc 
from  ops.dbo.Database_status_v where Databasename=db_name()

Select @Servername = Convert(nvarchar(128),SERVERPROPERTY('servername')), @dbname = convert(nvarchar(128),db_name())

UPDATE [ops].[dbo].[idxHealth] SET Spid=null
	, [Action]=COALESCE([ACtion]+char(10),'') + 'Abandonded SPID Found in ' + isnull([Status],'NULL')
	, [Status] = COALESCE([Status],'NULL') + ' ERROR' 
WHERE [Spid] is not null 

/*
	After a detailed SCAN, we can then Skip, mark Completed or leave to the Cursor to rebuild 
*/

if isnull(Cast(ops.dbo.fnSetting('Fragmentation','MinPageCount') as int),0) < 4 
		exec ops.dbo.Settings_put 'Fragmentation','MinPageCount','1000'


Begin

update ix SET status = CASE [status] when 'Retest' then 'Complete' else 'Skipped' end  
from 
	[ops].[dbo].[idxHealth] ix with (nolock)
where 1=1 
and ix.Action = 'Sampling'
and ix.Status in ('Sampled','Retest')
and ix.DatabaseName = db_name() 
and (1=0 
	or ix.page_count <= Cast(ops.dbo.fnSetting('Fragmentation','MinPageCount') as int)
	OR ix.type_desc='CLUSTERED' and ix.avg_fragmentation_in_percent < ops.dbo.fnSetting('Fragmentation','Clustered')  
	OR ix.type_desc='NONCLUSTERED' and ix.avg_fragmentation_in_percent <  ops.dbo.fnSetting('Fragmentation','NonClustered') 
	)
END 

select @ERM = 'Index Fragmentation Allowed for NonClustered:' + 
	ops.dbo.fnSetting('Fragmentation','NonClustered') +
	' And  Clustered:' + ops.dbo.fnSetting('Fragmentation','Clustered') + ' Max number of Tables Touched ' + cast(@MaxFragActions as varchar(10)) + char(10) 

IF @debug >= 1
   Raiserror(@ERM,0,1) with nowait 

	if object_id('tempdb..#RebuildList') is not null 
	Drop Table #RebuildList 


create table [#RebuildList](
	[id] int identity(1,1) ,
	[idrow] int NOT NULL,
	[dbname] nvarchar(256) NOT NULL, 
	[schema] nvarchar(256) NOT NULL,
	[TableName] nvarchar(256) NOT NULL,
	[IndexName] nvarchar(256) NOT NULL,
	[StatsDate] datetime,
	[partition_number] smallint,
	[Status] varchar(150),
	[type_desc] varchar(150),
	[avg_fragmentation_in_percent] float(8),
	[page_count] int,
	[record_count] bigint
)

Declare @stmt nvarchar(max) 
select @stmt='SELECT TOP ' + ops.dbo.fnSetting('Fragmentation','MaxActions')+'
	[idrow]
	, db_name()
	, ix.[schema]
	, ix.TableName
	, ix.IndexName
	, ix.StatsDate
	, ix.partition_number 
	, [Status] 
	, ix.type_desc
	, ix.avg_fragmentation_in_percent
	, ix.page_count
	, ix.record_count
from 
	[ops].[dbo].[idxHealth] ix with (nolock)
where 1=1 
--and ix.Action in (''Detailed'')--,''Rebuild'')
and ix.[Status] in (''Sampled'',''Retest'')
and ix.DatabaseName = db_name() 
and (1=0						
	OR ix.type_desc=''CLUSTERED'' and ix.avg_fragmentation_in_percent > ops.dbo.fnSetting(''Fragmentation'',''Clustered'')
	--OR ix.type_desc=''NONCLUSTERED'' and ix.avg_fragmentation_in_percent > ops.dbo.fnSetting(''Fragmentation'',''NonClustered'') 
	)
Order by 
	ix.[Status] DESC -- Lets get all the Sampled runs completed before retesting 
	, ix.page_count DESC 

'
--if @debug = 1 
--Raiserror(@STMT,0,1) with nowait

DECLARE @RowCount int 

insert into #RebuildList ([idrow],[dbname], [schema], [TableName], [IndexName], [StatsDate], [partition_number], [Status], [type_desc], [avg_fragmentation_in_percent], [page_count], [record_count])
EXEC (@STMT)

  SET @RowCount = isnull(@@ROWCOUNT,0) 
  --SELECT @RowCount

if @RowCount < 1 -- CAST(ops.dbo.fnSetting('Fragmentation','MaxActions') as int) -- Null is false 
BEGIN
 
 if @debug is not null  
	Raiserror('All Primary Keys are under the allowed fragementation',0,1) 

select @stmt='SELECT TOP ' + ops.dbo.fnSetting('Fragmentation','MaxActions')+'
	[idrow]
	, db_name()
	, ix.[schema]
	, ix.TableName
	, ix.IndexName
	, ix.StatsDate
	, ix.partition_number 
	, [Status] 
	, ix.type_desc
	, ix.avg_fragmentation_in_percent
	, ix.page_count
	, ix.record_count
from 
	[ops].[dbo].[idxHealth] ix with (nolock)
where 1=1 
--and ix.Action in (''Detailed'')--,''Rebuild'')
and ix.[Status] in (''Sampled'')
and ix.DatabaseName = db_name() 
and (1=0						
	--OR ix.type_desc=''CLUSTERED'' and ix.avg_fragmentation_in_percent > ops.dbo.fnSetting(''Fragmentation'',''Clustered'')
	OR ix.type_desc=''NONCLUSTERED'' and ix.avg_fragmentation_in_percent > ops.dbo.fnSetting(''Fragmentation'',''NonClustered'') 
	)
Order by 
	ix.[Status] DESC -- Lets get all the Sampled runs completed before retesting 
	, ix.page_count DESC 

'
if @debug > 1 
Raiserror(@STMT,0,1) with nowait
  
insert into #RebuildList ([idrow], [dbname], [schema], [TableName], [IndexName], [StatsDate], [partition_number], [Status], [type_desc], [avg_fragmentation_in_percent], [page_count], [record_count])
EXEC (@STMT)

END
ELSE
BEGIN

insert into #RebuildList ([idrow], [dbname], [schema], [TableName], [IndexName], [StatsDate], [partition_number], [Status], [type_desc], [avg_fragmentation_in_percent], [page_count], [record_count])
SELECT 
	ix.[idrow]
	, db_name()
	, ix.[schema]
	, ix.TableName
	, ix.IndexName
	, ix.StatsDate
	, ix.partition_number 
	, ix.[Status] 
	, ix.type_desc
	, ix.avg_fragmentation_in_percent
	, ix.page_count
	, ix.record_count
from 
	[ops].[dbo].[idxHealth] ix with (nolock)
	inner join #RebuildList RB on RB.dbname = ix.DatabaseName and rb.TableName = ix.TableName 
where 1=1 
 and ix.IndexName not in (select indexname from #RebuildList)
--and ix.Action in ('Detailed')--,'Rebuild')
	--and ix.[Status] in ('Sampled')
	--and ix.DatabaseName = db_name() 
	--and ix.type_desc='NONCLUSTERED'
Order by 
	ix.[Status] DESC -- Lets get all the Sampled runs completed before retesting 
	, ix.page_count DESC 


END 


if @debug > 1 
BEGIN
	select ops.dbo.fnSetting('Fragmentation','Clustered') [Setting]
	select * From #RebuildList order by TableName, type_desc
	Goto Exitscript 
END


/* Number of impacting Executions  Allowed */

DECLARE idxcursor CURSOR READ_ONLY FOR 
select 
	[idrow]
	, [schema]
	, TableName
	, IndexName
	, StatsDate
	, partition_number 
	, 'Rebuild' [ScanType]
	--, Status 
	, type_desc
	--, avg_fragmentation_in_percent
	--, page_count
	--, record_count
FROM #RebuildList 
 order by TableName, type_desc

DECLARE @idRow int, @statsdate datetime, @schema nvarchar(128), @table nvarchar(128), @index  nvarchar(128), @scantype nvarchar(128) , @partition_number int, @typeDESC nvarchar(50)

OPEN idxcursor

FETCH NEXT FROM idxcursor INTO @idrow, @schema, @Table, @index, @statsdate, @partition_number, @scantype, @typeDesc --, @Frag 
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN


		SELECT @STMT = char(10) + 'IDRow (' + cast(@idRow as varchar(100)) + ')' + @servername+'.'+@dbname+'.'+@schema+'.'+@table+'.'+@index + ' '+ @typeDesc +' ['+@scantype+'] /* SPID: '+ CAST(@@SPID as VArchar(10)) +' */' 
	
	if @debug is not null 
		Raiserror(@stmt,0,1) with nowait 

BEGIN TRY
	IF @scantype='REBUILD' 
	BEGIN

			SELECT @stmt = 'ALTER INDEX [' + @index +'] on ['+ @schema +'].['+ @table +'] REBUILD ' 
			+ Case when @partition_number > 1 then 'PARTITION = ' + cast(@partition_number as varchar(10)) else '' end 
			--+ ' WITH ( ONLINE = ON ( WAIT_AT_LOW_PRIORITY (MAX_DURATION = 10 minutes, ABORT_AFTER_WAIT = SELF )))'
			+' WITH (SORT_IN_TEMPDB = ON, MAXDOP = 0)'
			+';'

	END

		if @debug > 0 Raiserror(@stmt,0,1) with nowait 
		
		if isnull(@debug,0) < 2
		BEGIN

		Begin Transaction
				update ops.dbo.idxHealth set [Status] = 'Rebuild', [spid]=@@spid where idRow=@idRow 
		Commit transaction

				Exec(@Stmt) 

		--Begin Transaction
		--		update ops.dbo.idxHealth set [Status] = 'Retest' where [schema]=@schema and [TableName]=@table 
		--			and isnull([partition_number],0) = isnull(@partition_number,0) 
		--			and [status] in ('Sampled','Rebuild')
		--		 -- idRow=@idRow 
		--Commit Transaction 


			select @stmt = 'UPDATE STATISTICS ['+ @schema +'].['+ @table +']' -- [' + @index +'];' 
			
			if @debug > 0 Raiserror(@stmt,0,1) with nowait 
			Exec(@Stmt) 

		Begin Transaction
			update ops.dbo.idxHealth set [spid]=null where idRow=@idRow 
		Commit Transaction 

		END
				

		END TRY

		Begin Catch

		select @ERM = isnull(@stmt,'Null @stmt') + ' Raised Error'+ char(10) + ERROR_MESSAGE(), @ERS = ERROR_SEVERITY() 
		Raiserror(@ERM,@ERS,1)

				update ops.dbo.idxHealth set [Status]='Failed in Rebuild', [Action] = isnull([Action],'') + @ERM, [spid]=null  where idRow=@idRow 

			Goto OnErrorExitCursor

		End Catch

		/* Exit every so often to let trn backups clear the logs */
		select @MaxFragActions = @MaxFragActions - 1 
			  if @MaxFragActions=0 GOTO OnErrorExitCursor

	END
	FETCH NEXT FROM idxcursor INTO @idrow, @schema, @Table, @index, @statsdate,@partition_number, @scantype, @typeDesc
END

OnErrorExitCursor: 

CLOSE idxcursor
DEALLOCATE idxcursor

while @@TRANCOUNT > 0 
Begin 
  Rollback
End 


ExitScript:


if @debug >= 1
SELECT 
  [DatabaseName]
  , [Action] 
  , Status
  , Count(*) [Indexes]
FROM
	ops.dbo.idxHealth ix
where 1=1 
 and DatabaseName=DB_NAME() 
 --and IndexName='PK_SoftDeletedResultSummaryResults'
--and (1=0 
--	or ix.page_count <= Cast(ops.dbo.fnSetting('Fragmentation','MinPageCount') as int)
--	OR ix.type_desc='CLUSTERED' and ix.avg_fragmentation_in_percent < ops.dbo.fnSetting('Fragmentation','Clustered')  
--	OR ix.type_desc='NONCLUSTERED' and ix.avg_fragmentation_in_percent <  ops.dbo.fnSetting('Fragmentation','NonClustered') 
--	)
Group by 
  [DatabaseName]
  , [Action] 
  , Status
order by 
	CHARINDEX([Action],'Discovery, Sampling')
	, CHARINDEX([Status],'Discovery, Complete, Sampled, Detailed, Rebuilt, Retested')


/*REBUILDING*/
