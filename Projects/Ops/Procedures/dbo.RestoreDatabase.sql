USE [Ops]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RestoreDatabase]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[RestoreDatabase]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[RestoreDatabase]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[RestoreDatabase] AS' 
END
GO

-- =============================================
-- Author:		Randy Pitkin
-- Create date: 20140417
-- Description:	RestoresDatabaseFromShare
-- =============================================
ALTER PROCEDURE [dbo].[RestoreDatabase] 
	@DatabaseName varchar(400) = null, 
	@ServerName varchar(300) = null, 
	@fromdb varchar(400) = null, 
	@StopAt DateTime = null,
	@overwrite bit = null,  
	@refresh bit = null, 
	@standby bit = null,
	@recover bit = null,
	@STATS int = null,
	@debug int = null
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @ERM nvarchar(max), @ers int, @ern int, @stmt varchar(max) , @counter int 
	declare @filepath varchar(max) , @fileid int, @recoverymodel varchar(20), @bakStartDate datetime  
	

Raiserror('/*',0,1) -- Script usage for ops and testing 

SELECT @ERM = '
	for more help try
	exec ops.dbo.sp_help_executesproc @procname=''RestoreDatabase'', @schema=''dbo'' 

	use @Debug = 1 to output the script for the restore, (Can be used on the Ops Database)
	, @debug =2 to see what backups were found with the parameters provided
	, @debug = 3 to see where the files for the restore will be.

	@overwrite and @recover parameters Should be considered Mandatory

	Exec ops.dbo.Backupfiles_get @rootpath=''\\PathtoBackups\'' --to log files with the server, Null is the Servers Default backup Directory.

	Exec ops.dbo.BackupFiles_Report for a status of backups known by the server.

	I am leveraging 
	update dbo.BackupFiles set SoftwareVersionMinor=1 where Fileid = @bfid 
	 to mark trns restored for tracking where we are. 


*/
'

Raiserror(@ERM,0,1) with nowait 

select @debug = CASE when @debug >= 1 then @debug when @DatabaseName='Ops' then 1 else 0 end 

	select 
	  @STATS = isnull(@stats,5) 
	, @StopAt = isnull(@StopAt,getdate())
	, @ServerName = isnull(@servername,convert(Varchar(300),serverproperty('servername')))

	declare @strStopat varchar(100) 

	if isnull(@DatabaseName,'')='' 
	BEGIN
		SELECT @ERM = 'A Databasename is required' 
		exec BackupFiles_Report @servername=@servername
		Raiserror(@ERM,11,1)  
		Return 0; 
		--GOTO OnErrorExitProcedure 
	END
	

if @debug = 2 
BEGIN

	SELECT 
		ServerNAme, 
		DatabaseName
		, backuptype
		, BackupName
		, BackupDescription
		, @SERVERNAME [@ServerName]
		, @fromdb as [@Fromdb]
		, @DatabaseName as [@DatabaseName]

	from dbo.backupFiles with (nolock)
	where 1=1 
		--and DatabaseName not in ('master','model','tempdb')
		and ((isnull(@DatabaseName,'')='') OR (DatabaseName = isnull(@Fromdb,@DatabaseName)))
		and ((isnull(@SERVERNAME,'')='') OR ([ServerName]=@SERVERNAME))
	order by 
			ServerName
		, DatabaseName
		, backuptype 

	Return 1; 
END


BEGIN 
	select @ERM = 'checking files for full backup of database '+ isnull(@fromdb,@databasename) +' from Server ' + @ServerName +
	 isnull(' before ' + convert(varchar(100),@stopat),'') 
 Raiserror(@erm,0,1) with nowait 

	if not exists(select * from dbo.backupfiles where 
		DatabaseName = isnull(@fromdb,@databasename) 
		and ServerName = isnull(@servername,servername) 
		and BackupStartDate <= isnull(@StopAt,getdate()))
		 
	BEGIN
		select @ERM = Coalesce(@ERM + char(10),'') + 'There are no backups early enough to back to
		Exec Ops.Dbo.BackupFiles_get @rootpath=''\\Where backups\are\'' ' + isnull(Convert(varchar(100),@stopat,1),'@StopAt is null') +'
		Exec ops.dbo.BackupFiles_Report for a status of backups known by the server.

		use the @servername parameter in your restore statement if your backup was taken from another server.
		Verify that you have a full backup logged by using the query below.' 

		select @ERM = @ERM + char(10) + '
		select * from dbo.backupfiles where 
		DatabaseName = isnull(@fromdb,@databasename) 
		and ServerName = isnull(@servername,servername) 
		and BackupStartDate <= isnull(@StopAt,getdate())'
		Raiserror(@ERM,11,1) with nowait 
		Return 0; 
	END

END

	 if @recover=1 
	 Begin
		update bf set SoftwareVersionMinor=0  from dbo.BackupFiles bf 
		where bf.Fileid in (select top 1 fileid from dbo.BackupFiles where servername=isnull(@servername,servername) 
		and DatabaseName=isnull(@fromdb,@DatabaseName) order by bf.BackupStartDate desc) 
	 end 


if isnull(@refresh,0) = 1 
BEGIN
		 if not exists(select * from master.sys.databases where name=@DatabaseName and ((is_in_standby=1) OR ([state_desc]='RESTORING')))
		 Begin
			select @ERM = 'Database is not in a state (Standby, Restoring) for Refresh'
			raiserror(@ERM,11,1) 
			Return 0;
		 End

	Raiserror('Trying to refresh',0,1) with nowait

	if not exists(select 1 from dbo.BackupFiles where servername=isnull(@servername,servername) 
		and DatabaseName=isnull(@fromdb,@DatabaseName) 
		and isnull(SoftwareVersionMinor,0)=0)
	 Begin
		SELECT @ERM = 'Refresh Not Possible, there are no log files left to restore' 
			raiserror(@ERM,0,1) 
			Return 0;
		 end  
		/* I have record of previous restore */ 
		 select @bakStartDate = max(Backupstartdate) from dbo.BackupFiles where DatabaseName=@DatabaseName and SoftwareVersionMinor = 1 --'Restored before' 
		 select @SERVERNAME = servername from dbo.BackupFiles where BackupStartDate=@bakStartDate
		  Raiserror('Jumping to Log files',0,1)
		   GOTO StartLogRestore
		 /* Jump to Log File Restore */
END
else
  Raiserror('Restoring from last Full',0,1) with nowait

/* TODO Check for Multiple server names
	Only Overwrite steps
 */
 select @stmt = ' Finding First Full Backup 
 Parameters are @DatabaseName = ''' + @DatabaseName + '''
 , @fromdb=''' + @fromdb + '''
, @servername = ''' + @servername + '''
, @StopAt = ''' + Convert(varchar(100),@StopAt) + '''' 

Raiserror(@stmt,0,1) 

  SET @fileid = (Select top 1 fileid from dbo.BackupFiles bf where 1=1 
		and bf.DatabaseName = isnull(@fromdb,@DatabaseName )
		and backuptype=1
		and ((@StopAt is null) OR (BackupStartDate <= @StopAt))
		and [ServerName]= @ServerName
	order by BackupStartDate DESC ) 


SELECT 
  @filepath = Filepath 
, @recoverymodel = [recoverymodel]
, @bakStartDate = [backupStartDate]
 from dbo.backupFiles 
 where fileid = @fileid 
  
if @filepath is null 
Begin

	Select @ERM = coalesce(@ERM + char(10),'')+'A Full Backup to start from could not be found
	Exec BackupFiles_get @rootpath=''\\uncpathto\backups\
	'
	,@ers=11
	  goto OnErrorExitProcedure
END

/* Parameter Validattion */
 select @stmt = '@filepath = ''' + @Filepath + '''
, @recoverymodel = ''' + @recoverymodel + '''
, @bakStartDate = ''' + Convert(varchar(100),@bakStartDate) + '''
  @DatabaseName = ''' + @DatabaseName + '''
, @servername = ''' + @servername + '''
, @bakStartDate = ''' + Convert(varchar(100),@bakStartDate) + '''' + 
isnull(', @strStopat = ' + Convert(varchar(100),@StopAt,109),'') +'

*/'

Raiserror(@stmt,0,1) 

Begin /* File Management */ 

	select @ERM = '-- ' + @filepath
	Raiserror(@ERM,0,1) with nowait 

	declare @dbFiles Table (
		LogicalName varchar(100) , 
		PhysicalName varchar(max) , 
		Type char(1) , 
		FileGroupName varchar(20) ,
		Size NUMERIC(20,0) , 
		MaxSize NUMERIC(20,0),
		FileID int , 
		CreateLSN numeric(25,0) null, 
		DropLSN numeric(25,0) null, 
		UniqueID uniqueidentifier , 
		ReadOnlyLSN numeric(25,0)  ,
		ReadWriteLSN numeric(25,0) , 
		BackupSizeInBytes Bigint ,
		SourceBlockSize int , 
		FileGroupID int ,
		LogGroupGUID uniqueidentifier , 
		DifferentialBaseLSN numeric(25,0) , 
		DifferentialBaseGUID uniqueidentifier , 
		IsReadOnly bit ,
		IsPresent bit ,
		TDEThumbprint varbinary(32),
		SnapshotURL nvarchar(360) 
	)
	--restore filelistonly from disk = N'E:\MSSQL\Backups\FromProd\OurLabReporting\OurLabReporting_20160720-220008167.bak'
select @stmt = 'restore filelistonly from disk = N''' + @filepath + '''' 
Raiserror(@stmt,0,1) with nowait 
	
	begin try 
	insert into @dbFiles([logicalname],[physicalname],[type],[filegroupname],[size],[maxsize],[fileid],[createlsn],[droplsn],[uniqueid],[readonlylsn],[readwritelsn],[backupsizeinbytes],[sourceblocksize],[filegroupid],[loggroupguid],[differentialbaselsn],[differentialbaseguid],[isreadonly],[ispresent],[tdethumbprint],[SnapshotURL]) 
	Exec (@STMT) 
	 GOTO StashLocations
	end try
	Begin catch
		select @ERM = ERROR_MESSAGE()
		Raiserror(@ERM,1,1)
		 Raiserror('Trying 2014 version ',1,1) with nowait 
	
	END CATCH

	BEGIN TRY 
	insert into @dbFiles([logicalname],[physicalname],[type],[filegroupname],[size],[maxsize],[fileid],[createlsn],[droplsn],[uniqueid],[readonlylsn],[readwritelsn],[backupsizeinbytes],[sourceblocksize],[filegroupid],[loggroupguid],[differentialbaselsn],[differentialbaseguid],[isreadonly],[ispresent],[tdethumbprint]) 
	EXEC (@STMT) 
	END TRY
	BEGIN CATCH
		SELECT @ERM = ERROR_MESSAGE()
		RAISERROR(@ERM,11,1)
		RETURN 0 ; 
	END CATCH

StashLocations: 
	update dbf set dbf.PhysicalName = st.Value 
	from @dbFiles dbf 
	inner join OpS.dbo.Settings st on st.Context=@databasename and st.Name= dbf.LogicalName


	if exists(select * from @dbfiles where LogicalName not in (select Name from ops.dbo.settings where Context=@DatabaseName))
	Begin
		select @ERM = '
		/* The File locations for this database have not been set, review and Execute the following make sure you have space for this DB
		Default Locations for Data:' +  ops.dbo.fnSetting('Instance','DefaultData') + '
		and Logs:' + isnull(ops.dbo.fnSetting('Instance','DefaultLog'),'WTF') +'
		*/'
		 
	update @dbFiles set PhysicalName = Replace(
		case when [physicalname] like '%.ldf' 
			then ops.dbo.fnsetting('Instance','DefaultLog') 
			else ops.dbo.fnsetting('Instance','DefaultData') end  
			+   reverse(substring(reverse(PhysicalName),1,CHARINDEX('\',reverse([physicalname]))))
			,'\\','\') -- no unc paths 

	select @ERM = Coalesce(@ERM+char(10),'') + 'exec dbo.settings_put @Context=''' + @DatabaseName + ''', @name=''' + LogicalName + ''' ,@value=''' + Replace([PhysicalName],isnull(@fromdb,@DatabaseName),@DatabaseName) +''' 
	--' + cast([size] as varchar(50)) + ' bytes required' + char(10) 
	from @dbFiles order by [Size] desc 
	
	
	SELECT @ERM = @ERM + char(10) + ' --  Attempting to use defaults'
	if @debug is not null
	  select convert(xml,'<tsql><![CDATA[' + @ERM + ']]></tsql>') as [FileSettings]

	 Raiserror(@ERM,0,1)

	END


if @debug=3
BEGIN
	select @DatabaseName DatabaseName, LogicalName, PhysicalName, 'Breaking on @Debug=3(File Locations)' as [Message]
	 from @dbFiles dbf 
	Raiserror('Breaking on @DEBUG=3',0,1) with nowait 
	Return 1;
end 


if Exists(select * from @dbFiles where PhysicalName is null)
BEGIN

	Select @ERM = 'Unable to find Drives for Restore to from @db'

	select * from @dbFiles 
	raiserror(@ERM,11,1) 
	Return 0;
end


end 


declare @Cname sysname, @dbstate tinyint, @dbstat_desc varchar(100) 
select @cname = name 
	, @dbstate = [state] 
	, @dbstat_desc = md.state_desc
	from master.sys.databases md 
 where name = @DatabaseName 


 SELECT @ERM = '/* Current Database Status for ' + isnull(@Cname,'Does not Exist') +' ('+ isnull(@dbstat_desc,'NULL')  +')' 
	+ 'Execution Level @debug=' + isnull(cast(@debug as varchar(10)),'NULL') + '*/'  
Raiserror(@ERM,0,1) with nowait 


--Raiserror('Breaking for DEV',1,1);  Return 1 ; 



if @Cname is not null 
Begin

	if (@Overwrite != 1) and  (@dbstate=0)
		begin
			select @erm = '@Overwrite [Bit] parameter is required to overwrite an active database' 
			Raiserror(@erm,11,1) with nowait 
			Return 0 ;
		end
	else
		Begin
		  Begin Try
		  select @stmt = 'ALTER DATABASE [' + @DatabaseName + '] SET READ_WRITE WITH ROLLBACK IMMEDIATE;' 
		  raiserror(@stmt,0,1) with nowait 
		  IF isnull(@debug,0) < 1 Exec(@stmt)  

		  select @stmt = 'ALTER DATABASE [' + @DatabaseName + '] SET RESTRICTED_USER WITH ROLLBACK IMMEDIATE;' 
		  raiserror(@stmt,0,1) with nowait 
		  IF isnull(@debug,0) < 1 Exec(@stmt)  

		select @stmt = 'DROP DATABASE [' + @DatabaseName + ']' 
		raiserror(@stmt,0,1) with nowait 
		IF isnull(@debug,0) < 1 Exec(@stmt)  
		 END Try
		 Begin Catch
			/*Don't Care Dropping database */ 
		 End Catch

		end 
End 

 --Return 0; 
	/***************************************************************************************************
	  HERE IS THE RESTORE COMMAND 
	***************************************************************************************************/

select @stmt ='RESTORE DATABASE ['+@DatabaseName+'] FROM  DISK = N''' + @filepath + ''' WITH  FILE = 1' 

select @stmt = coalesce(@stmt+char(10)+char(9)+',','') + 
'MOVE N''' + LogicalName + ''' TO N''' + PhysicalName + ''''
from @dbFiles 

select @stmt = @stmt 
	--+ ',  STANDBY = N''' + @datadir + '\' + @databasename + '_standby.bak''' 
	+ ', NORECOVERY, NOUNLOAD, REPLACE,  STATS = ' + cast(@stats as varchar(3)) 

	if @debug is not null 
		 select convert(xml,'<tsql><![CDATA[' + @STMT + ']]></tsql>') [RestoreDB]

	raiserror(@stmt,0,1) with nowait  

	Begin Try

		
		IF isnull(@debug,0) < 1 
		BEGIN

		  Exec(@stmt) 

		update dbo.BackupFiles set SoftwareVersionMinor=1 --'Complete' 
		 where Filepath=@filepath 
		
		update dbo.BackupFiles set SoftwareVersionMinor=1 --'Before this backup' 
		 where Databasename = isnull(@fromdb,@databasename) and ServerName=isnull(@servername,servername) and BackupStartDate <= @bakStartDate 

		update dbo.BackupFiles set SoftwareVersionMinor = 0  -- Ready for Log restore 
		 where Databasename = isnull(@fromdb,@databasename) and ServerName=isnull(@servername,servername) and BackupStartDate >= @bakStartDate and BackupType=2 
 
		END 
		SELECT @ERM = null 

	End Try 
	Begin Catch 
			Select @stmt = 'There was an Error, Retry the following command to Troubleshoot'+ char(10) + char(10) + @stmt+ char(10)+ '
				to review the files in the backup that need locations use: restore filelistonly from disk = N''\\Full\path\to.File'' 
				to set a new location for a file execute the following to change the setting in this SQLServer instance
				Exec Ops.dbo.Settings_put @context=''databasename'', @Name=''logicalname'', @Value=''FullFilepath\includeing\Ext ''
			'
			Raiserror(@stmt,11,1)
			Return 0; 
	End Catch


  SELECT @strStopat = Convert(varchar(100),@StopAt,109)

    
	/***************************************************************************************************
	  LETS FIND SOME LOGS  
	***************************************************************************************************/
StartLogRestore: 
 --Select @fromdb

select 
[Fileid]
, filepath
, [backupStartDate] 
, [BackupFinishDate]
, backupType
, BackupDescription
, @bakStartDate [LastFullDate]
into #LogFiles 
  from dbo.backupFiles  
	where databasename = isnull(@fromdb,@DatabaseName)
	and SoftwareVersionMinor = 0 -- is null
	and servername=isnull(@servername,servername)
	and backupType=2
	and  [BackupFinishDate] <= isnull(@StopAt,[BackupFinishDate])
order by [backupStartDate] 

IF @debug = 4
BEGIN
 select @stopat,* FROM #LogFiles

Return 1; 

END

select @StopAt = isnull(@stopat,getdate())
select @strStopat = convert(Varchar(100),@stopat,109) 

DECLARE LogCursor CURSOR READ_ONLY FOR 
select filepath, Fileid, [BackupFinishDate] 
  from #LogFiles lf 
order by [backupStartDate] 

DECLARE @name nvarchar(max), @findate datetime , @bfid int 

OPEN LogCursor

FETCH NEXT FROM LogCursor INTO @name, @bfid, @findate
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		--select @ERM = '-- (' + Convert(varchar(100),@findate) + ') '  + @name +'
		--' + @strStopat + '  ' + convert(varchar(100),@StopAt) 
		-- Raiserror(@ERM,0,1) with nowait 

		Begin Try 

			select @stmt = 
'RESTORE LOG ['+ @DatabaseName +'] FROM  DISK = N''' + @name + ''' WITH  FILE = 1' 
+ ', NORECOVERY,  NOUNLOAD,  STATS = ' + cast(@stats as varchar(3)) 
  if @StopAt <= @findate select @stmt = @stmt + ', STOPAT=''' + @strStopat + '''' 


	Select @stmt = isnull(@Stmt,'Is Null') , @ERS = CASE when @Stmt is null then 11 else 0 end
	 
	if @debug > 0 Raiserror(@stmt,@ers,1) With nowait 

			IF isnull(@debug,0) < 1 
			BEGIN

				Raiserror(@stmt,0,1) with nowait 
				Exec(@stmt)  
				
				--update Ops.Dbo.BackupFiles set BackupDescription = 'Complete' where Fileid = @bfid
				update dbo.BackupFiles set SoftwareVersionMinor=1 where Fileid = @bfid  
			END

		if @findate >= @StopAt GOTO OnErrorExitFileCursor
			 
		End Try

		Begin Catch

			select @ERM = isnull(@name,'Null @name') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			, @ERN = ERROR_NUMBER() 

			Raiserror(@ERM,0,1)
			-- update Ops.Dbo.BackupFiles set BackupDescription = 'LogFailed',SoftwareVersionMinor=1 where Fileid = @bfid 

			--IF @ERS > 11 Goto OnErrorExitFileCursor

		End Catch

	END
	FETCH NEXT FROM LogCursor INTO @name, @bfid, @findate
END


OnErrorExitFileCursor: 

CLOSE LogCursor
DEALLOCATE LogCursor

select @NAME = char(10) + '/* Final Step @ERS= '+ isnull(cast(@ERS as varchar(10)),' NULL ') +' */' +  char(10)
Raiserror(@NAME,0,1) 

IF isnull(@ERS,0) = 0 
BEGIN

	Begin Try 

	if isnull(@standby,0) = 1 
	BEGIN
	declare @sf varchar(100)

	if @stmt like 'RESTORE DATABASE%'
	  begin 
	    select @ERM = 'The last restore was not a log file, this is required for Standby, Either find a TRN and Execute with @refresh=1 or Execute 
			Restore Database [' + @DatabaseName + '] -- to recover.'
		Raiserror(@ERM,11,1) with nowait 
	  end 
	else
		if @debug is not null 
		 select convert(xml,'<tsql><![CDATA[' + @STMT + ']]></tsql>') [RestoreDB]

	 Raiserror(@stmt,0,1) with nowait 
	 /* @stmt should still be valid  */

	 select @sf = (select top 1 PhysicalName from @dbfiles where PhysicalName like '%.ldf')
	 if @SF is null -- @Reffreshing
	 select @sf = (select top 1 Physical_Name from master.sys.master_files where database_id=db_id(@DatabaseName) and Physical_Name like '%.ldf') 

		select @sf = replace(@sf,'.ldf','_standby.log')
		select @sf= 'Standby=''' + @sf + ''''

		SELECT @stmt = Replace(@stmt,'NORECOVERY',@sf)
		SELECT @STMT = Replace(@stmt,',',char(10) + ',')

		if @debug is not null 
		 select convert(xml,'<tsql><![CDATA[' + @STMT + ']]></tsql>')

		 raiserror(@stmt,0,1) with nowait  
		IF @Debug < 1 EXEC(@stmt)

		update dbo.BackupFiles set SoftwareVersionMinor=1 where Fileid = @bfid 

	END
ELSE
	BEGIN

		IF isnull(@recover,0) = 1 
		BEGIN
		if @stmt like 'RESTORE DATABASE%'
		BEGIN
			select @stmt = 'Restore Database [' + @DatabaseName + ']'
		END
		ELSE
		BEGIN

			SELECT @stmt = Replace(@stmt,'NORECOVERY','RECOVERY')
			SELECT @STMT = Replace(@stmt,',',char(10) + ',')
		END

		  raiserror(@stmt,0,1) with nowait  
		  IF @Debug < 1 EXEC(@stmt)

		  update dbo.BackupFiles set SoftwareVersionMinor=1 where Fileid = @bfid 

		END 
	END
	END TRY 
	BEGIN CATCH 

		select @ERM = isnull(@name,'Null @name') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
		, @ERS = ERROR_SEVERITY() 
		, @ERN = ERROR_NUMBER() 

		Raiserror(@ERM,@ERS,1)
		
	END CATCH

END

update bf set SoftwareVersionMinor=1
from dbo.BackupFiles bf
where 1=1 
 and bf.ServerName = @ServerName 
 and bf.DatabaseName = isnull(@fromdb,@databasename)  
 and SoftwareVersionMinor != 1
 and bf.BackupStartDate < (
		select max(BackupStartDate)
		from dbo.BackupFiles bf
		where 1=1 
		 and bf.ServerName = @ServerName 
		 and bf.DatabaseName = isnull(@fromdb,@databasename)  
		 and SoftwareVersionMinor=1
		 )

OnErrorExitProcedure: 
	IF isnull(@ERS,0) !=0 
	BEGIN

		Raiserror(@ERM,@ERS,1) 
		if @debug is null
			Exec dbo.sp_help_executesproc 'RestoreDatabase'
		Return 0;
	END

END

GO

if 1=2
Begin
	--exec ops.dbo.sp_help_executesproc @procname='RestoreDatabase', @schema='dbo'
 


DECLARE @DatabaseName varchar(max) = null 
	,@ServerName varchar(max) = null 
	,@fromdb varchar(max) = null 
	,@StopAt datetime  = null 
	,@overwrite bit  = null 
	,@refresh bit  = null 
	,@standby bit  = null 
	,@recover bit  = null 
	,@STATS int  = null 
	,@debug int  = null 

SELECT @DatabaseName = 'OurLabReporting' --varchar
	,@ServerName = 'OSGT3TSQL01' --varchar
	,@fromdb = @fromdb --varchar
	,@StopAt = @StopAt --datetime
	,@overwrite = 1 --bit
	--,@refresh = 1 --bit
	,@standby = 1 --bit
	,@recover = 0 --bit
	,@STATS = 1 --int
	,@debug = @debug --int

EXECUTE [dbo].RestoreDatabase @DatabaseName = @DatabaseName --varchar
	,@ServerName = @ServerName --varchar
	,@fromdb = @fromdb --varchar
	,@StopAt = @StopAt --datetime
	,@overwrite = @overwrite --bit
	,@refresh = @refresh --bit
	,@standby = @standby --bit
	,@recover = @recover --bit
	,@STATS = @STATS --int
	,@debug = @debug --int


end 

