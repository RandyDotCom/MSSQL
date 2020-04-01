USE OPS 
Go
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'BackupFiles_Mover' )
   DROP PROCEDURE dbo.BackupFiles_Mover
GO

--/* =============================================
---- Author:		Randy
---- Create date: 20141014
---- Description:	Robocopys Files to file shares
-- Leverages the BackupFiles_Retention Table 
--	Retention Type PUSH / PULL
--	RetentonDays int 
--	RetentionPath
--	  Along with the Containment bit on BackupFiles to show movement 
-- ============================================= */
--CREATE PROCEDURE dbo.BackupFiles_Mover 
--	@RootPath varchar(max) = null  ,
--	@RetentionType varchar(50) = null, 
--	@DatabaseName varchar(300) = null, 
--	@serverName varchar(300) = null,
--	@debug int = null 
--AS
--BEGIN
--SET NOCOUNT ON; 
--DECLARE @ERM nvarchar(max), @ERS int, @ERN int, @msg nvarchar(max) 
--DECLARE @fileid int, @command varchar(4000) , @RC int 

--Create Table #cmdout(Line varchar(max)) 

--select @msg = '
--  @Debug 0 is required to execute 
-- , @Debug 1 Shows by does not execute Robocopy
-- , @debug 2 shows Recordset to be moved 
-- , @debug 3 shows Recordset regardless of filters
 
-- '
--if @debug is not null
--	Raiserror(@msg,0,1) with nowait 


--if @RootPath is not null 
--BEGIN
--	select  @serverName = isnull(@servername,convert(Varchar(300),serverproperty('servername')))
--	  if not exists(select * from dbo.BackupFiles where ServerName=@serverName 
--		and ((isnull(@DatabaseName,'')='') OR (DatabaseName=@DatabaseName))) 
--	  begin 
--		if @debug <= 1 
--			Exec BackupFiles_Get @rootpath=@RootPath, @debug=@debug
--	  end 
	  
--	  if not exists(select * from dbo.BackupFiles where ServerName=@serverName 
--		and ((isnull(@DatabaseName,'')='') OR (DatabaseName=@DatabaseName)))
--	  begin 
--		select @erm = 'There are no backup files for [' + @serverName + '].[' + isnull(@DatabaseName,'NULL')+'] found at ' + @RootPath
--		raiserror(@ERM,11,1) 
--		Return 0; 
--	  end 

--SELECT @RetentionType = isnull(@RetentionType,'Push')

--  if @RetentionType not in ('Push','Pull')
--  Begin
--	Raiserror('only @RetentionType Push and Pull are currently supported',11,1) 
--	Return 0; 
--  END 

--IF @serverName != convert(Varchar(300),serverproperty('servername')) and @RetentionType='Push'
--Begin
--	select @erm = 'Only Pull can be executed against Files from another server at this time. Set @RetentionType=''Pull'' Explicitly'
--	Raiserror(@ERM,11,1) 
--	REturn 0
--END

--update [dbo].[BackupFiles_Retention] Set RetentionType = @RetentionType
--	, RetentionPath=@RootPath+'\'+[serverName]+'\'+ [DatabaseName]
-- where ServerName = @serverName 
-- and ((isnull(@DatabaseName,'')='') OR (DatabaseName=@DatabaseName))
-- --and DatabaseName not in ('model','msdb','tempdb')

 
--END


--select  
--	bf.Fileid
--	, Filepath
--	, bf.ServerName
--	, bf.DatabaseName
--	, br.RetentionType
--	, br.RetentionPath
--	, bf.containment 
--	, bf.BackupTypeDescription [Type]
--	, CASE WHEN dateadd(Day,br.retentionDays,bf.BackupStartDate) > Getdate() then 0 else 1 end [IsToOld]
-- into #toDoList
--from 
--	dbo.BackupFiles bf
--	inner join [dbo].[BackupFiles_Retention] br on br.ServerName=bf.ServerName and br.DatabaseName=bf.DatabaseName 
-- where 1=1 
--  and bf.containment = 0 --Not Moved Yet 
--  and br.RetentionType in ('Push','Pull')
--  and dateadd(Day,br.retentionDays,bf.BackupStartDate) > Getdate()
--  and ((isnull(@ServerName,'')='') OR (br.[ServerName]=@ServerName))
--  and ((isnull(@DatabaseName,'')='') OR (br.[DatabaseName]=@DatabaseName))
--  and ((isnull(@RetentionType,'')='') OR ([RetentionType]=@RetentionType))
--	OR @debug=3 
--order by 
--	BackupStartDate


--if not exists(select * from #toDoList)
--begin
--  select @ERM = '[BackupFiles_Retention] does not have any paths set'
--  Raiserror(@ERM,0,1) with nowait 

-- Select @msg = coalesce(@msg+char(10),'') +
--  --+ [RetentionType] + ' ' + DatabaseName + ' Files to:' + RetentionPath
--  'EXECUTE [dbo].BackupFiles_Mover 
--	 @RootPath = ''' + isnull(RetentionPath,'\\osgtfs01\????\???') + ''' -- Servername and Databasename are always added to the end of the path  
--	,@RetentionType = '''+ isnull(RetentionType,'Push') +'''  -- Push, Pull, Skip 
--	,@DatabaseName = '''+ [Databasename] + ''' 
--	,@serverName = '''+ [serverName] + '''' + char(10) 
-- FROM [dbo].[BackupFiles_Retention]

-- --if @debug is not null  
--    Raiserror(@msg,0,1) with nowait 

--  Return 1; 
--end 
--IF @debug=3 
--BEGIN
--	SELECT * FROM #toDoList 
--	Return 1; 
--END


--DECLARE FileCursor CURSOR READ_ONLY FOR 
--select -- top 10 
--	Fileid from #toDoList 

--OPEN FileCursor

--FETCH NEXT FROM FileCursor INTO @fileid 
--WHILE (@@fetch_status <> -1)
--BEGIN
--	IF (@@fetch_status <> -2)
--	BEGIN

--	declare @dst varchar(max)
--	, @src varchar(max) 
--	, @fle varchar(max) 

--	select @dst = RetentionPath 
--	, @fle = Reverse(left(reverse(Filepath),charindex('\',reverse(Filepath))-1))
--	, @src = Filepath
--	from #toDoList where fileid = @fileid  

--	select @src = replace(@src,@fle,'')

--	SELECT @command='Robocopy '+ @src +' ' + @dst + ' ' + @fle +' /J /NP /IPG:10'
--	from #toDoList where fileid = @fileid 

--	Raiserror(@command,0,1) with nowait

--if isnull(@debug,0) < 1 
--BEGIN

--BEGIN TRY 
	

--	insert into #cmdout (Line) 
--	exec @RC = xp_cmdshell @command 

	
--	SELECT @ERM = 'Return Code:' + isnull(cast(@RC as varchar(20)),'NULL')
--	SELECT @ERM = COALESCE(@ERM+char(10),'') + isnull(Line,'') from #cmdout 
--	delete #cmdout
	
--	if @RC > 1
--	Begin	
--		if @RC = 16 SET @ERS= 16 
--	SELECT @ERS = isnull(@ERS,11) 
	 
--		raiserror('An Error has occured',@ERS,1) with nowait 
--	END

--	update dbo.BackupFiles set containment=1 where Fileid=@fileid

--END TRY 
--BEGIN CATCH 

--	SELECT @ERM = COALESCE(@ERM+char(10),'') + ERROR_MESSAGE() 
--		, @ERS = ERROR_SEVERITY()
--		, @ERN = ERROR_NUMBER() 

--	SELECT @ERM = COALESCE(@ERM+char(10),'') + 'Error Number:' + isnull(cast(@ERN as varchar(20)),'NULL') 
--	Raiserror(@ERM,@ERS,1) with nowait 
--	 if @ERS > 11 
--	   goto OnErrorExitCursor

--END CATCH
--	--goto OnErrorExitCursor
--END 

--	END
--	FETCH NEXT FROM FileCursor INTO @fileid
--END

--OnErrorExitCursor: 

----Raiserror(@ERM,@ERS,1) with nowait 

--CLOSE FileCursor
--DEALLOCATE FileCursor




--END
--GO


--IF 1=2
--BEGIN
--  SET NOCOUNT ON; 
--	--exec Ops..sp_help_executesproc @procname='BackupFiles_Mover', @schema='dbo'

--	-- Truncate table dbo.[BackupFiles_Retention]
---- exec BackupFiles_Retention_SetDefaults

 

--DECLARE @RootPath varchar(max) = null 
--	,@RetentionType varchar(50) = null 
--	,@DatabaseName varchar(max) = null 
--	,@serverName varchar(max) = null 
--	,@debug int  = null 

----SELECT @RootPath = '\\osgtfs01\SQLBackups1\VSO' 
----	--,@RetentionType = 'Push' --varchar
----	--,@DatabaseName = 'OpsHealth' --varchar
----	,@serverName = @serverName --varchar
----	,@debug = 0 --int

--EXECUTE [dbo].BackupFiles_Mover @RootPath = @RootPath --varchar
--	,@RetentionType = @RetentionType --varchar
--	,@DatabaseName = @DatabaseName --varchar
--	,@serverName = @serverName --varchar
--	,@debug = @debug --int


--EXECUTE [dbo].BackupFiles_Mover @debug=1
--	 , @RootPath = '\\osgtfs01\SQLBackups1\VSO'
--	,@RetentionType = 'Push'  -- Push, Pull, Skip 
--	,@DatabaseName = 'Tfs_IntegrationPlatform' 
--	--,@serverName = 'VSOTIPSQL02'
	

--END


----USE [Ops]
----GO

----SELECT [DRID]
----      ,[ServerName]
----      ,[DatabaseName]
----      ,[RetentionType]
----      ,[RetentionDays]
----      ,[RetentionPath]
----  FROM [dbo].[BackupFiles_Retention]
----GO

------ EXEC [dbo].[BackupFiles_Retention_SetDefaults]