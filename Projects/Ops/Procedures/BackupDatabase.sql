USE [OPS]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BackupDatabase]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[BackupDatabase]
GO
	SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BackupDatabase]') AND type in (N'P', N'PC'))
	EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[BackupDatabase] AS' 
GO
-- =============================================
-- Author:		Randy
-- Create date: 20140801
-- Description:	Backups update databases to default share with naming
-- =============================================
ALTER PROCEDURE [dbo].[BackupDatabase] 
	@databasename sysname = null, 
	@BackupType varchar(20) = 'Full', 
	@BackupLocation	varchar(max) = null,
	@compression bit = null, 
	@stats varchar(3) = null,
	@Debug int = null 
AS
BEGIN
	SET NOCOUNT ON;
declare @erm nvarchar(max), @ers int, @ern int, @command nvarchar(4000), @stmt varchar(max) , @tsql varchar(max)
declare @tmstamp varchar(max) , @dbname sysname, @age int, @rc int 
Declare @state varchar(100), @standby bit, @model varchar(20), @HARole varchar(20) 
DECLARE @filename varchar(max) 

select @stats = isnull(@stats,'5') 
select @stats = CASE when ISNUMERIC(@stats)=0 then '5' else @stats end 
select @stats = CASE when Convert(tinyint,@stats) between 1 and 100 then @stats else '5' end 
 

select @compression = isnull(@compression,isnull(Cast(dbo.fnSetting('Instance','BackupCompression') as bit),1)) 
--Exec ops.dbo.Settings_put 'Instance','BackupCompression','0' 

DECLARE @cmdout table (lineout varchar(max))  

select @BackupType = CASE WHEN isnull(@BackupType,'Null') not in ('Full','Log','Diff') then 'Full' else @BackupType end  



if @BackupLocation is null 
BEGIN
  EXECUTE [dbo].SettingsRegRead 
  select @BackupLocation = dbo.[fnSetting]('Instance','BackupDirectory')
END

	SELECT @tmstamp = CONVERT(varchar(100),getdate(),21)
	SELECT @tmstamp = REPLACE(REPLACE(REPLACE(REPLACE(@tmstamp,'-',''),'.',''),':',''),' ','-')

	  --if @debug > 0 raiserror(@backuplocation,0,1) with nowait 

	  --  Exec ops.dbo.settings_put 'DoNotBackup','PerfGate','1'  -- Sets the Skip Value for Database 

select 
  md.[DatabaseName] as [DatabaseName]
, md.state_desc 
, md.is_in_standby
, md.recovery_model_desc 
, Isnull(md.HARole,'Alone') [HARole]
, (select Datediff(hour,max(backupstartdate),getdate()) from dbo.BackupFiles 
      where databasename=md.[DatabaseName] and BackupType=1) Age
, (select Top 1 recovery_model_desc from dbo.BackupFiles where databasename=md.[DatabaseName]) LastStatus
, isnull(cast(dbo.fnSetting('DoNotBackup',md.[DatabaseName]) as Bit),0) [SkipME]
, @BackupType [BackupType]
into #Dblist 
FROM
	ops.dbo.Database_status_v md 
WHERE 1=1 
   and md.[DatabaseName] not in ('tempdb','model')
   and ((isnull(@databasename,'')='') OR (md.[DatabaseName] = @databasename)) 

/*
	WHAT TO BACK UP LOGIC 
	  Backup everything unless Skipme is set 
	  
*/


update #Dblist set [SkipME]=1, LastStatus='N/A' where BackupType != 'Full' and recovery_model_desc != 'FULL' 

update #Dblist set [SkipME]=1, LastStatus='Standby' where is_in_standby=1

update #Dblist set [SkipME]=1, LastStatus='HARole:' + [HARole] where [HARole] not in ('Primary','Alone')
 
-- update #Dblist set BackupType='Full', LastStatus='No Fresh Backup' where isnull(Age,1000) > 48 and [HARole] != 'Backup'
update #Dblist set [SkipME]=1, LastStatus=state_desc where state_desc != 'ONLINE' and isnull([Skipme],0) != 1

/* Redundant optional Settings Construct */
update #Dblist set [SkipME]=1, LastStatus='Settings' where [DatabaseName] in 
  (select Name from ops.dbo.Settings where Context='Instance' and [value] ='DoNotBackup')
/*No Full backup local for 2 days */

update #Dblist Set BackupType='Full' 
where isnull([Skipme],0) != 1 AND BackupType != 'Full'
	and DatabaseName not in (select distinct databasename from dbo.BackupFiles where BackupTypeDescription='Database' 
		and BackupStartDate > Dateadd(day,-2,getdate()))
	

if @debug=2
BEGIN
	SELECT * from #Dblist 
	Return 1;
END

if not exists(select DatabaseName, BackupType, [harole] from #Dblist where [SkipME] !=1 )
Begin 
	Raiserror('Nothing to do',0,1) with nowait  
end

DECLARE DBC CURSOR READ_ONLY FOR 
select DatabaseName, BackupType, [harole] from #Dblist where [SkipME] !=1 
 

OPEN DBC

delete from @cmdout 
declare @defBackupLocation varchar(max) = @BackupLocation

FETCH NEXT FROM DBC INTO @dbname, @backupType, @harole
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		Begin Try 


		if @debug = 1 Raiserror(@dbname,0,1) with nowait 

		if exists(select * from sys.sysprocesses where cmd='BACKUP DATABASE' and db_name(dbid) = @dbname)
		BEGIN
				SELECT @ERM = 'A Backup of ' + @dbname + ' was discovered in Progress, Try again later'
				Raiserror(@ERM,0,1) with nowait 
				goto SkipDB 
		END

		select @BackupLocation = [RetentionPath] from [dbo].[BackupFiles_Retention] where [RetentionType]='Backups' and [DatabaseName]=@dbname and [ServerName]= Convert(varchar(max),SERVERPROPERTY('ServerName'))  
		select @BackupLocation = isnull(@BackupLocation,@defBackupLocation)

		select @filename = @BackupLocation +'\' + @dbname +'\' --+@tmstamp+'.bak' 
		select @command = 'mkdir "' + @filename + '"' 
		--raiserror(@command,0,1) with nowait 
		select @ERM = @command
		insert into @cmdout
		exec @rc = xp_cmdshell @command 

				select @ERM = @ERM + char(10) + 'Return code:' + CAST(@RC as varchar(10))
				SELECT @ERM = coalesce(@ERM+char(10),'')+ isnull(lineout,'') from @cmdout
				Raiserror(@ERM,0,1) with nowait 

				delete from @cmdout
		
		end Try 
		Begin catch 
			Raiserror(@ERM,11,1) with nowait 
			goto OnErrorExitCursor
		end catch 

		if @debug = 1 raiserror(@backuptype,0,1) with nowait 

		if @BackupType='Full'
		BEGIN
			select @filename = @filename + @dbname + '_' + @tmstamp +'.bak'
			 

			SELECT @stmt = '
 BACKUP DATABASE [' + @dbname + '] 
	TO  DISK = N''' + @filename + ''' 
WITH ' + CASE WHEN @harole NOT IN ('Primary','Alone') then '
	COPY_ONLY,' else '' end + '
	NOFORMAT, 
	' + CASE isnull(@compression,1) when 0 then '' else 'COMPRESSION,' end + '
	NOINIT,  
	NAME = N''' + @dbname + ' Full Backup on ' +  convert(varchar(100),getdate()) +''', 
	SKIP,
	Stats='+@stats+';
 '

	
		END
		
		if @BackupType='Log'
		BEGIN
			select @filename = @filename + @dbname + '_' + @tmstamp +'.trn'

			SELECT @stmt = '
 BACKUP LOG [' + @dbname + '] 
	TO  DISK = N''' + @filename + ''' 
WITH 
	NOFORMAT, 
	' + CASE isnull(@compression,1) when 0 then '' else 'COMPRESSION,' end + '
	NOINIT,  
	NAME = N''' + @dbname + ' Log Backup on ' +  convert(varchar(100),getdate()) +''', 
	SKIP;
 '

		END


		if @BackupType='Diff'
		BEGIN
			select @filename = @filename + @dbname + '_' + @tmstamp +'.diff'

			SELECT @stmt = '
 BACKUP LOG [' + @dbname + '] 
	TO  DISK = N''' + @filename + ''' 
WITH 
	NOFORMAT, 
	' + CASE isnull(@compression,1) when 0 then '' else 'COMPRESSION,' end + ',
	NOINIT,  
	NAME = N''' + @dbname + ' Differential Backup on ' +  convert(varchar(100),getdate()) +''', 
	SKIP;
 '
			
		END

		BEGIN TRY 
		IF @stmt is null 
		  Raiserror('Stmt was null',11,1) with nowait 

			Raiserror(@stmt,0,1) with nowait 

			IF ISNULL(@DEBUG,0) < 2 
			BEGIN
			   EXECUTE(@STMT) 
			END

		 exec Dbo.BackupFiles_Get @Filepath=@Filename, @debug=@debug 
		
		End Try

		Begin Catch

			select @ERM = isnull(@dbname,'Null @dbname') + ' Raised Error (' + CAST(ERROR_NUMBER() as varchar(10)) + ')'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			, @ERN =  ERROR_NUMBER()
	
			if @ERN=3013 
			  Begin 
				SELECT @ERM = 'A Backup of ' + @dbname + ' is already in Progress, Try again later'
				Raiserror(@ERM,0,1) with nowait 
				goto SkipDB 
			  End
			SELECT @ERM = COALESCE(@ERM,'') + ' review output or Job log for details' 
			Raiserror(@ERM,@ERS,1)

			IF @ERS > 11 Goto OnErrorExitCursor

		End Catch
SkipDB:

	END
	FETCH NEXT FROM DBC INTO @dbname, @backupType, @harole
END

OnErrorExitCursor: 


CLOSE DBC
DEALLOCATE DBC


END

GO

if 1=2 
BEGIN

--exec sp_help_executesproc 'BackupDatabase'

DECLARE @databasename sysname  = null 
	,@BackupType varchar(20) = null 
	,@BackupLocation varchar(max) = null 
	,@compression bit  = null 
	,@stats varchar(3) = null 
	,@Debug int  = null 

SELECT 
	@BackupType = 'Log' --varchar
	--,@databasename = 'Ops' --sysname
	,@BackupLocation = @BackupLocation --varchar
	,@compression = @compression --bit
	,@stats = @stats --varchar
	,@Debug = 2 --int

EXECUTE [dbo].BackupDatabase @databasename = @databasename --sysname
	,@BackupType = @BackupType --varchar
	,@BackupLocation = @BackupLocation --varchar
	,@compression = @compression --bit
	,@stats = @stats --varchar
	,@Debug = @Debug --int

END



