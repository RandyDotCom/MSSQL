/*SAMPLING*/
SET NOCOUNT ON;
/*
	//msdn.microsoft.com/en-us/library/ms188388(v=sql.110).aspx  
*/
declare @ERM nvarchar(max),@ERN int, @ERS int
,@servername nvarchar(128)  , @dbname nvarchar(128)
, @RC int , @debug int 

Select @Servername = Convert(nvarchar(128),SERVERPROPERTY('servername')), @dbname = convert(nvarchar(128),db_name())
select @ERM = 'Sampling indexes on ' + @servername + '.' + @dbname 
Raiserror(@ERM,0,1) with nowait 

if not exists(select * from ops.dbo.Database_status_v where Databasename=db_name() and state_desc='ONLINE' and is_in_standby=0 and isnull(HAROLE,'PRIMARY') = 'PRIMARY' )
BEGIN
	select @ERM = 'DB is not available for index optimize'
	Raiserror(@ERM,11,1) with nowait 
	GOTO ExitScript
END

Declare @MaxFragClustered int, @MaxFragNonClustered int , @MaxFragActions tinyint 
/* Setting Default Defrag values */

Begin /* Making Sure we have Fragmentation settings */
begin try 

Settings: 
  select @MaxFragClustered = CAST(ops.dbo.fnSetting('Fragmentation','Clustered') as INT) 
  , @MaxFragNonClustered = CAST(ops.dbo.fnSetting('Fragmentation','NonClustered') as INT) 
  , @MaxFragActions = CAST(ops.dbo.fnSetting('Fragmentation','MaxActions') as tinyint) 

if @MaxFragClustered is null 
	exec ops.dbo.Settings_put 'Fragmentation','Clustered','5'
	
if @MaxFragNonClustered is null 
	exec ops.dbo.Settings_put 'Fragmentation','NonClustered','5'

if @MaxFragActions is null 
	exec ops.dbo.Settings_put 'Fragmentation','MaxActions','5'

	
	if @debug>0
	select ops.dbo.fnSetting('Fragmentation','NonClustered') [NonClustered]
	, ops.dbo.fnSetting('Fragmentation','Clustered') [Clustered]
	, ops.dbo.fnSetting('Fragmentation','MaxActions') [MaxActions]


if ((@MaxFragClustered is null) or (@MaxFragNonClustered is null) or (@MaxFragActions is null))
  GOTO Settings 
  
end try 
Begin catch 

	raiserror('Either the fnSetting Function, Settings_put procedure, or settings table is missing?',11,1) 
	Goto ExitScript 

end catch
END 

DECLARE idxcursor CURSOR READ_ONLY FOR 
select -- Top 5 
	[idrow]
	, ix.[schema]
	, ix.TableName
	, ix.IndexName
	, ix.StatsDate
	, [status] as [ScanType]
	, ix.partition_number 
from 
	[ops].[dbo].[idxHealth] ix
where 1=1 
	and ix.[Status] in ('Discovered','Retest') 
	and ix.DatabaseName = db_name() 

DECLARE @idRow int, @stmt varchar(max), @statsdate datetime, @schema nvarchar(128), @table nvarchar(128), @index  nvarchar(128), @scantype nvarchar(128) , @partition_number int 

OPEN idxcursor

FETCH NEXT FROM idxcursor INTO @idrow, @schema, @Table, @index, @statsdate, @Scantype, @partition_number
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
--	  select @MaxFragActions = @MaxFragActions - 1 
--	   if @MaxFragActions=0 GOTO OnErrorExitCursor

	  select @Scantype='SAMPLED' 

		SELECT @STMT = @servername+'.'+@schema+'.'+@dbname+'.'+@table+'.'+@index + ' (' + isnull(CAST(@partition_number as varchar(10)),'NULL') + ') ['+@scantype+']' 
		Raiserror(@stmt,0,1) with nowait 
	
		declare @spid int 
		select @spid = @@spid
			BEGIN TRANSACTION 
				update ops.dbo.idxHealth set [Status] = 'Scanning', [spid]=@spid where idRow=@idRow 
			COMMIT TRANSACTION

		BEGIN TRY
	

--if isnull(@debug,0) < 1
BEGIN

BEGIN TRANSACTION 

INSERT INTO ops.[dbo].[idxHealth]
           ([ServerName]
           ,[DatabaseName]
		   , [schema]
           ,[TableName]
           ,[IndexName]
           ,[StatsDate]
           ,[type_desc]
           ,[partition_number]
           ,[index_depth]
           ,[index_type_desc]
           ,[avg_fragmentation_in_percent]
           ,[fragment_count]
           ,[page_count]
           ,[record_count]
           ,[alloc_unit_type_desc]
           ,[Action]
           ,[Status])
SELECT 
		@servername as servername
		,@dbname as DatabaseName 
		, sc.name as [Schema]
		, ob.name [TableName]
		,b.[name] as [IndexName]
		, STATS_DATE(b.object_id,b.index_id) as [statsdate]
		,b.type_desc 
		, a.[partition_number]
		,a.[index_depth]
		,a.[index_type_desc]
		,a.[avg_fragmentation_in_percent]
		,a.[fragment_count]
		,a.[page_count]
		,a.[record_count]
		,a.alloc_unit_type_desc
		, 'Sampling' as [Action]
		, 'Sampled' as [Status] -- Sampled
		FROM 
			sys.objects ob 
			inner join sys.schemas sc on sc.[schema_id] = ob.[schema_id] 
			INNER JOIN sys.indexes AS b ON ob.[object_id] = b.[object_id] --and b.type_desc in ('CLUSTERED','NONCLUSTERED')
			Cross Apply sys.dm_db_index_physical_stats (DB_ID(), B.[object_id], B.index_id , @partition_number, @scantype) AS a
		WHERE 1=1
		  and ob.type='U'
		  and sc.name=@schema
		  and ob.name = @table
		  and b.name = @index


		  update ops.dbo.idxHealth set [Status] = 'Scan Complete',[spid]=null where idRow=@idRow 

COMMIT TRANSACTION

END 

		End Try

		Begin Catch

		update ops.dbo.idxHealth set [Status] = + ' Failed Sampling', [spid]=null  where idRow=@idRow 

		select @ERM = isnull(@stmt,'Null @stmt') + ' Raised Error'+ char(10) + ERROR_MESSAGE(), @ERS = ERROR_SEVERITY() 
		Raiserror(@ERM,@ERS,1)

			IF @ERS > 11 Goto OnErrorExitCursor

		End Catch

	  waitfor delay '00:00:01' 

	END
	FETCH NEXT FROM idxcursor INTO @idrow, @schema, @Table, @index, @statsdate, @Scantype, @partition_number
END

OnErrorExitCursor: 

CLOSE idxcursor
DEALLOCATE idxcursor

WHILE @@TRANCOUNT > 0 
BEGIN
	Rollback transaction 
END

ExitScript:

if @debug >=1
SELECT 
  [DatabaseName]
  , [Action] 
  , Status
  , Count(*) [Indexes]
FROM
	ops.dbo.idxHealth 
where 1=1 
 and DatabaseName=DB_NAME() 
Group by 
  [DatabaseName]
  , [Action] 
  , Status
order by 
	CHARINDEX([Action],'Discovery, Sampling, Detailed, Rebuilt, Retested')
	, CHARINDEX([Status],'Discovery, Sampling, Detailed, Rebuilt, Retested')


	
/*SAMPLING*/
