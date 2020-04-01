USE Ops 
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[dba_LogicalName_put]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[dba_LogicalName_put]
GO

CREATE PROCEDURE dbo.dba_LogicalName_put 
		@dbname nvarchar(255) = null
	,	@shrinkLog int = null 
	,	@u varchar(20) = null 
	,	@p varchar(50) = null 
	,	@debug int = null
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @stmt nvarchar(max)
	Declare @cmds table (line varchar(max)) 
	
	SELECT @dbname = isnull(@dbname,'AdminTools')
	
	IF NOT EXISTS(select * from master.sys.databases where database_id > 4 and [state]=0 and is_in_standby=0 and name=@dbname)
 	Begin 
		SELECT @stmt = 'The database ('+ISNULL(@dbname,'NULL') +') was not found'
		Raiserror(@stmt,11,1) 
		Return 0;
	end 		
	
	
	SELECT @u = ISNULL(@u,'sa'), @p = ISNULL(@p,'Pitkin!@') 
	
	
	
	create table #RenameFileInfo (LName varchar(100),Fileid int, groupid int)
	
	SELECT @stmt= 'Insert into #RenameFileInfo (LName, Fileid, Groupid)
	Select [name] , Fileid, groupid from [' + @dbname + ']..sysfiles'
	
		
	if @debug > 0 Raiserror(@stmt,0,1) with nowait
	
	insert @cmds (line) 
	EXEC (@stmt)
	
DECLARE Filec CURSOR READ_ONLY FOR 
SELECT LName, Fileid, groupid FROM #RenameFileInfo 

DECLARE @LName varchar(100), @Fileid int, @groupid int
OPEN Filec

FETCH NEXT FROM Filec INTO @LName, @Fileid, @groupid
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		Declare @command nvarchar(4000) 
		Declare @cmdout table (line nvarchar(400)) 
		
		IF @shrinkLog > 99
		Begin
		
		
		SELECT @command = 'DBCC SHRINKFILE (N'''+@LName+''' , ' + CAST(@shrinkLog as varchar(10)) + ')''' 
		SELECT @command = 'SQLCMD -S ' + CONVERT(varchar(400),serverproperty('servername')) + ' -d ' + @dbname + ' -Q "' + @command + ' -T'
		if @debug > 0 Raiserror(@command,0,1) with nowait 
			
		
		END

		--IF 1=2
		BEGIN
		
			SELECT @stmt = 'USE MASTER;
			ALTER DATABASE [' + @dbname + '] MODIFY FILE (Name=N''' + @LName + ''', NewName=N''' + @dbname + '_' + CASE WHEN @groupid=0 then 'log' else 'data' end +
			CAST(@FileID as varchar(10)) + ''')'

			IF @debug is not null 
				Raiserror(@Stmt,0,1) with nowait  
			
			EXEC (@stmt)  
		
		END
				


	END
	FETCH NEXT FROM Filec INTO @LName, @Fileid, @groupid
END

OnErrorExit:

CLOSE Filec
DEALLOCATE Filec

	
END
GO

IF 1=2
BEGIN

	EXEC Ops.dbo.dba_LogicalName_put @debug=1 
	, @shrinkLog=200
	, @dbname='OpsHealth'
	
	
END