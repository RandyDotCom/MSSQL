USE OPS
GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'idxRepairManager' )
   DROP PROCEDURE dbo.idxRepairManager
GO
/*
-- =============================================
-- Author:		Randy
-- Create date: 20150206
-- Description:	Schedules Jobs for Index Defragmentation
Refrences 
https://msdn.microsoft.com/en-us/library/ms188388(v=sql.110).aspx  
-- =============================================
--*/
--CREATE PROCEDURE dbo.idxRepairManager 
--	@DatabaseName varchar(128) = null
--	, @objname varchar(128) = null
--	, @idxType varchar(100) = null 
--	, @Frag tinyint = null
--	, @ActionType varchar(10) = null 
--	, @RowLimit tinyint = null 
--	, @debug int = null 
--AS
--BEGIN
--SET NOCOUNT ON; 
--DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
--, @stmt varchar(max) = null 
--/*
--	This procedure is intended to be used recursively 
--	Defaults
--*/
----SELECT 
----	@idxType = isnull(@idxType,'CLUSTERED INDEX') 
----, @RowLimit = isnull(@RowLimit,10)
----, @Frag = isnull(@Frag,35) 

--SET ROWCOUNT 0;

--select @stmt = 'SET ROWCOUNT ' + CAST(@Rowlimit as varchar(10)) 
----raiserror(@stmt,0,1)
----Exec (@STMT) 

--select
--  idrow
--  , DatabaseName
--  , TableName
--  , IndexName
--  , type_desc
--  , partition_number
--  , avg_fragmentation_in_percent
--  , record_count
--  , page_count
--into #ToDoList 
--from 
--  ops.dbo.idxFragmentation ix
--WHERE 1=1 
-- and ((isnull(@DatabaseName,'')='') OR (ix.DatabaseName=@DatabaseName))
-- and ((isnull(@idxType,'')='') OR (index_type_desc = @idxType))
-- and ((isnull(@Frag,0)=0) OR (avg_fragmentation_in_percent >= @Frag))
-- and [Action] is null
-- and alloc_unit_type_desc='IN_ROW_DATA'
-- and [Status] in ('Sampled','Detailed')
--order by 
--  avg_fragmentation_in_percent desc


--if @debug=2 
--Begin
--	select * FROM #ToDoList
--	Return 1; 
--END
  
--  declare @job_id uniqueidentifier = newid() 
--  , @command nvarchar(max) 
--  , @Step_Name nvarchar(400)
--  , @command_type varchar(50) = 'TSQL' 
--  , @workername varchar(max) 
--  , @idRow int 

--	SELECT @workername = CONVERT(varchar(100),getdate(),21)
--	SELECT @workername = 'IDXM_' + REPLACE(REPLACE(REPLACE(REPLACE(@workername,'-',''),'.',''),':',''),' ','-')

--DECLARE FixMeC CURSOR READ_ONLY FOR 
--SELECT DatabaseName, IndexName, TableName, partition_number, idRow 
--from #ToDoList

--DECLARE @dbname sysname, @idxName sysname, @TableName sysname, @partition int   
--OPEN FixMeC

--FETCH NEXT FROM FixMeC INTO @dbname,@idxName,@TableName,@partition, @idRow
--WHILE (@@fetch_status <> -1)
--BEGIN
--	IF (@@fetch_status <> -2)
--	BEGIN

--		Begin Try 

--SELECT @Step_Name = @idxname 
--, @command_type='TSQL'
--, @command = 'USE ' + @dbname +'
-- go 
-- ALTER INDEX [' + @idxName + '] ON [' + @TableName + '] ' + CASE WHEN @partition > 1  then 'REBUILD PARTITION =' + cast(@partition as varchar(10)) else '' end 

--raiserror(@command,0,1) with nowait 
  
--	--INSERT INTO Ops.[dbo].[Tasks]([job_id],[step_name],[commandtype],[command],[workername])
--	--	 VALUES (@job_id,@Step_Name,@command_type,@command,@TableName)
		
--	--	update ix 
--	--	 SET ACTION=@command , Status='Requested'
--	--	 FROM  ops.dbo.idxFragmentation ix 
--	--	 where idRow=@idRow

		  
--		End Try

--		Begin Catch

--			select @ERM = isnull(@command,'Null @name') + char(10) + ' Raised Error:'+ ERROR_MESSAGE()
--			, @ERS = ERROR_SEVERITY() , @ERN = ERROR_NUMBER()
			

--			Raiserror(@ERM,@ERS,1)

--			IF @ERS >= 16 Goto OnErrorExitCursor

--		End Catch

--	END
--	FETCH NEXT FROM FixMeC INTO @dbname,@idxName,@TableName,@partition,@idRow
--END

--OnErrorExitCursor: 


--CLOSE FixMeC
--DEALLOCATE FixMeC


--select * from #ToDoList 

--END
--GO


----IF 1=2
--BEGIN

--	--exec ops.dbo.sp_help_executesproc @procname='idxRepairManager'

--DECLARE @DatabaseName varchar(128) = null 
--	,@objname varchar(128) = null 
--	,@idxType varchar(100) = null 
--	,@Frag tinyint  = null 
--	,@ActionType varchar(10) = null 
--	,@RowLimit tinyint  = null 
--	,@debug int  = null 

--SELECT @debug = @debug --int
--	, @DatabaseName = 'RDThreshold' --varchar
--	,@objname = @objname --varchar
--	--,@idxType = 'CLUSTERED INDEX' --varchar
--	,@Frag = 50 --tinyint
--	,@ActionType = @ActionType --varchar
--	,@RowLimit = 0 --tinyint
	

--EXECUTE [dbo].idxRepairManager @DatabaseName = @DatabaseName --varchar
--	,@objname = @objname --varchar
--	,@idxType = @idxType --varchar
--	,@Frag = @Frag --tinyint
--	,@ActionType = @ActionType --varchar
--	,@RowLimit = @RowLimit --tinyint
--	,@debug = @debug --int




--select
--  idrow
--  , DatabaseName
--  , TableName
--  , IndexName
--  , type_desc
--  , partition_number
--  , avg_fragmentation_in_percent
--  , record_count
--  , page_count
----into #ToDoList 
--from 
--  ops.dbo.idxFragmentation ix
--WHERE 1=1 
-- and ((isnull(@DatabaseName,'')='') OR (ix.DatabaseName=@DatabaseName))
-- and ((isnull(@idxType,'')='') OR (index_type_desc = @idxType))
-- and ((isnull(@Frag,0)=0) OR (avg_fragmentation_in_percent >= @Frag))
-- and [Action] is null
-- and alloc_unit_type_desc='IN_ROW_DATA'
-- and [Status] in ('Sampled','Detailed')
--order by 
--  avg_fragmentation_in_percent desc 
--	--avg_fragmentation_in_percent desc 



--END
--/*
--exec idxRepairManager

--select TOP 1 * from ops.dbo.idxFragmentation for xml raw, elements 
--<row>
--  <idRow>1</idRow>
--  <ServerName>PC-PSQL3</ServerName>
--  <DatabaseName>PerfGate</DatabaseName>
--  <collected>2015-02-05T16:32:12.473</collected>
--  <TableName>ContextValues</TableName>
--  <IndexName>PK_PropertyValues</IndexName>
--  <type_desc>CLUSTERED</type_desc>
--  <partition_number>1</partition_number>
--  <object_id>91199425</object_id>
--  <index_id>1</index_id>
--  <index_depth>2</index_depth>
--  <index_type_desc>CLUSTERED INDEX</index_type_desc>
--  <avg_fragmentation_in_percent>4.800000000000000e+001</avg_fragmentation_in_percent>
--  <fragment_count>13</fragment_count>
--  <page_count>25</page_count>
--  <record_count>2037</record_count>
--  <alloc_unit_type_desc>IN_ROW_DATA</alloc_unit_type_desc>
--  <Status>SAMPLED</Status>
--</row>
--*/


----Select * from 
---- -- Truncate table 
---- ops.dbo.Tasks 