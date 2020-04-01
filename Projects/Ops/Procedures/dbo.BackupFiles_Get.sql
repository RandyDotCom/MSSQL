USE OPS 
GO 
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON; 
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BackupFiles_Get]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[BackupFiles_Get]
GO
-- =============================================
-- Author:		Randy
-- Create date: 20140730
-- Description:	Populates the BackupFilesTable
-- =============================================
CREATE PROCEDURE dbo.BackupFiles_Get 
	@Rootpath varchar(max) = null, 
	@FilePAth varchar(max) = null , 
	@Debug int = null
AS
BEGIN
SET NOCOUNT ON;
/*
	Troubleshooting Tips, Versions have changed the schema of RESTORE HEADERONLY 
	Review the output from this statement and alter the columns in backupfiles_temp to match. 
*/
DECLARE @ERM nvarchar(max), @ERS int, @ERN int , @rc int 
DECLARE @command nvarchar(4000), @stmt varchar(max) 
create table #cmdout (lineout varchar(max))   
declare @RetentionType nvarchar(50) 

  if OBJECT_ID('tempdb..#FilesFound') is not null 
  Drop Table #FilesFound

create table #filesFound (fdate datetime, Filename varchar(max), FullPath varchar(max))

if @FilePAth is not null 
begin /*Single file support */
  insert into #filesFound(Fullpath) values(@FilePAth)
  GOTO SingleFileGet
end 

create table #PathsToCheck (Folder nvarchar(max))


IF @Rootpath is not null 
Begin
 insert into #PathsToCheck(Folder) values(@Rootpath) 
  select @RetentionType = RetentionType from dbo.BackupFiles_Retention
END
ELSE 
BEGIN

	select @RootPath = dbo.[fnSetting]('Instance','BackupDirectory')
	insert into #PathsToCheck(Folder) values(@Rootpath)  

	insert into #PathsToCheck(Folder)
	select distinct [RetentionPath] from [dbo].[BackupFiles_Retention] 
	where [RetentionType]='Backups' and [RetentionPath] not like (@RootPath+'%') -- Process is recursive 

END

if @Debug > 0 
  select * from #PathsToCheck

DECLARE PathCursor CURSOR READ_ONLY FOR 
select folder from #PathsToCheck

DECLARE @Folder nvarchar(max)
OPEN PathCursor

FETCH NEXT FROM PathCursor INTO @Folder
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

    Raiserror(@Folder,0,1) 

	Begin Try 

  Select @command='dir /s "' + rtrim(ltrim(@Folder)) + '"'
  if @debug > 0 Raiserror(@command,0,1) with nowait 

    delete from #cmdout 
	insert into #cmdout
	exec xp_cmdshell @command 

	if @debug = 3 select * from #cmdout for xml raw 

	insert into #filesFound(fdate,filename,FullPath)
	select 
	  cast(left(lineout,20) as datetime) [fdate] 
	  , substring(lineout,40,len(Lineout)-39) Filename
	  , Cast(null as varchar(max)) [FullPath]
	from 
	 #cmdout
	where 1=1 
	 and right(lineout,4) in ('.bak','.trn') 
	 and isdate(left(lineout,20))=1

		  Select @command='dir /B /S "' + rtrim(ltrim(@RootPath)) + '"'
		 if @Debug > 0 Raiserror(@command,0,1)

	delete from #cmdout 
	insert into #cmdout
	exec xp_cmdshell @command 

	if @debug = 3 select * from #cmdout for xml raw 

	update fd set FullPath = fp.lineout
		FROM #cmdout fp
		inner join #FilesFound fd on fd.Filename = right(fp.lineout,len(fd.filename))
	where 
	  fd.fdate > '1/1/2010'

		begin 

		/*REMOVES Records of Files missing from @Rootpath */
		delete from dbo.BackupFiles 
		  where 1=1 
		  and Filepath like (@rootpath+'%')
		  and Filepath not in (select Fullpath from #FilesFound c)

		select @erm = 'deleted ' + cast(@@rowcount as varchar(10)) + ' Missing Files' 
			if @debug is not null raiserror(@ERM,0,1) with nowait 
  
		END 

	   delete from #FilesFound where FullPath is null 
	--select * from #FilesFound where FullPath is not null 

		End Try

		Begin Catch
			select @ERM = isnull(@Folder,'Null @Folder') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			, @ERN = ERROR_NUMBER() 
			
			Raiserror(@ERM,@ERS,1)

		End Catch

	END
	FETCH NEXT FROM PathCursor INTO @Folder
END

OnErrorExitFilesCursor: 


CLOSE PathCursor
DEALLOCATE PathCursor

select @ERM = @command 
if exists(select * from #cmdout where lineout like '%Denied%')
Begin
	Select @erm = Coalesce(@ERM+char(13)+char(10),'') + isnull(Lineout,'') from #cmdout
	Raiserror(@ERM,11,1) with nowait 
	Return 0;
END


if @debug=4 
BEGIN

  select ff.*,bf.Fileid from #filesFound ff 
	left outer join dbo.BackupFiles bf on bf.Filepath = ff.FullPath

  select @Rootpath, bf.Filepath  
   from dbo.BackupFiles bf 
  where 1=1 
   and Filepath like (@rootpath+'%')
   and Filepath not in (select Fullpath from #FilesFound c)
    
  Return 1; 

END


SingleFileGet:

IF @Debug=2 
BEGIN
	
	SELECT c.FullPAth,c.fdate 
	 , b.Fileid, b.ServerName, b.DatabaseName, b.DatabaseCreationDate 
	FROM 
		#FilesFound c
		left outer join dbo.BackupFiles b on b.Filepath = c.FullPAth
	 where 1=1 
	 and FullPAth is not null
	 and b.Fileid is null
	 
	Return 1;
END

/* 
	They keep messing with the schema of the return for restore headersonly 
	The Instance Defines the return of restore headersonly in the table @temp

*/ 

--DECLARE @temp TABLE (
Create Table #BFTemp (
	[BackupName] [nvarchar](128) NULL,
	[BackupDescription] [nvarchar](255) NULL,
	[BackupType] [smallint] NULL,
	[ExpirationDate] [datetime] NULL,
	[Compressed] [bit] NULL,
	[Position] [smallint] NULL,
	[DeviceType] [tinyint] NULL,
	[UserName] [nvarchar](128) NULL,
	[ServerName] [nvarchar](128) NULL,
	[DatabaseName] [nvarchar](128) NULL,
	[DatabaseVersion] [int] NULL,
	[DatabaseCreationDate] [datetime] NULL,
	[BackupSize] [numeric](20, 0) NULL,
	[FirstLSN] [numeric](25, 0) NULL,
	[LastLSN] [numeric](25, 0) NULL,
	[CheckpointLSN] [numeric](25, 0) NULL,
	[DatabaseBackupLSN] [numeric](25, 0) NULL,
	[BackupStartDate] [datetime] NULL,
	[BackupFinishDate] [datetime] NULL,
	[SortOrder] [smallint] NULL,
	[CodePage] [smallint] NULL,
	[UnicodeLocaleId] [int] NULL,
	[UnicodeComparisonStyle] [int] NULL,
	[CompatibilityLevel] [tinyint] NULL,
	[SoftwareVendorId] [int] NULL,
	[SoftwareVersionMajor] [int] NULL,
	[SoftwareVersionMinor] [int] NULL,
	[SoftwareVersionBuild] [int] NULL,
	[MachineName] [nvarchar](128) NULL,
	[Flags ] [int] NULL,
	[BindingID] [uniqueidentifier] NULL,
	[RecoveryForkID] [uniqueidentifier] NULL,
	[Collation] [nvarchar](128) NULL,
	[FamilyGUID] [uniqueidentifier] NULL,
	[HasBulkLoggedData] [bit] NULL,
	[IsSnapshot] [bit] NULL,
	[IsReadOnly] [bit] NULL,
	[IsSingleUser] [bit] NULL,
	[HasBackupChecksums] [bit] NULL,
	[IsDamaged] [bit] NULL,
	[BeginsLogChain] [bit] NULL,
	[HasIncompleteMetaData] [bit] NULL,
	[IsForceOffline] [bit] NULL,
	[IsCopyOnly] [bit] NULL,
	[FirstRecoveryForkID] [uniqueidentifier] NULL,
	[ForkPointLSN] [numeric](25, 0) NULL,
	[RecoveryModel] [nvarchar](60) NULL,
	[DifferentialBaseLSN] [numeric](25, 0) NULL,
	[DifferentialBaseGUID] [uniqueidentifier] NULL,
	[BackupTypeDescription] [nvarchar](60) NULL,
	[BackupSetGUID] [uniqueidentifier] NULL,
	[CompressedBackupSize] [bigint] NULL,
	[containment] [tinyint] NULL,
	[KeyAlgorithm] [nvarchar](50) NULL,
	[EncryptorThumbprint] [varbinary](20) NULL,
	[EncryptorType] [nvarchar](32) NULL
)


DECLARE @fdate datetime, @stmt2 varchar(max) 
declare @Tempid int , @fileid int 

DECLARE FileCursor CURSOR READ_ONLY FOR 
	SELECT C.FullPAth,c.fdate --, b.Fileid, b.ServerName, b.DatabaseName 
	FROM 
		#FilesFound c
		left outer join dbo.BackupFiles b on b.Filepath = c.FullPAth
	 where 1=1 
	 and FullPAth is not null
	 and b.Fileid is null


OPEN FileCursor

FETCH NEXT FROM FileCursor INTO @filepath,@fdate
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		/* Columns are determined by the SQL Backup Source Version */
		  select @stmt = 'RESTORE HEADERONLY FROM DISK = N''' + @filepath + '''' 
		  if @debug > 0 Raiserror(@stmt,0,1) with nowait 

 ResetRetentionType: 

		  BEGIN TRY -- TOP TRy to get data 

		  	Begin Try -- 2014
			if isnull(@RetentionType,'2014')='2014'	
			BEGIN
				  
			/* Columns are determined by the SQL Instance Version */
			insert into #BFTemp ([BackupName],[BackupDescription],[BackupType],[ExpirationDate],[Compressed],[Position],[DeviceType],[UserName],[ServerName],[DatabaseName],[DatabaseVersion],[DatabaseCreationDate],[BackupSize],[FirstLSN],[LastLSN],[CheckpointLSN],[DatabaseBackupLSN],[BackupStartDate],[BackupFinishDate],[SortOrder],[CodePage],[UnicodeLocaleId],[UnicodeComparisonStyle],[CompatibilityLevel],[SoftwareVendorId],[SoftwareVersionMajor],[SoftwareVersionMinor],[SoftwareVersionBuild],[MachineName],[Flags ],[BindingID],[RecoveryForkID],[Collation],[FamilyGUID],[HasBulkLoggedData],[IsSnapshot],[IsReadOnly],[IsSingleUser],[HasBackupChecksums],[IsDamaged],[BeginsLogChain],[HasIncompleteMetaData],[IsForceOffline],[IsCopyOnly],[FirstRecoveryForkID],[ForkPointLSN],[RecoveryModel],[DifferentialBaseLSN],[DifferentialBaseGUID],[BackupTypeDescription],[BackupSetGUID],[CompressedBackupSize],[containment],[KeyAlgorithm],[EncryptorThumbprint],[EncryptorType])
			Exec (@stmt) 
				if @RetentionType is null 
				   select @RetentionType='2014'

				goto SuccessRead
			end 
			end Try 
			begin catch
				Raiserror('Trying 2012',0,1)
			end Catch

			Begin Try -- 2012
			if isnull(@RetentionType,'2012')='2012'	
			BEGIN
					  
			insert #BFTemp ([BackupName],[BackupDescription],[BackupType],[ExpirationDate],[Compressed],[Position],[DeviceType],[UserName],[ServerName],[DatabaseName],[DatabaseVersion],[DatabaseCreationDate],[BackupSize],[FirstLSN],[LastLSN],[CheckpointLSN],[DatabaseBackupLSN],[BackupStartDate],[BackupFinishDate],[SortOrder],[CodePage],[UnicodeLocaleId],[UnicodeComparisonStyle],[CompatibilityLevel],[SoftwareVendorId],[SoftwareVersionMajor],[SoftwareVersionMinor],[SoftwareVersionBuild],[MachineName],[Flags ],[BindingID],[RecoveryForkID],[Collation],[FamilyGUID],[HasBulkLoggedData],[IsSnapshot],[IsReadOnly],[IsSingleUser],[HasBackupChecksums],[IsDamaged],[BeginsLogChain],[HasIncompleteMetaData],[IsForceOffline],[IsCopyOnly],[FirstRecoveryForkID],[ForkPointLSN],[RecoveryModel],[DifferentialBaseLSN],[DifferentialBaseGUID],[BackupTypeDescription],[BackupSetGUID],[CompressedBackupSize],[containment])
			Exec (@stmt) 

					If @RetentionType is null 
				   select @RetentionType='2012'

			  goto SuccessRead
			end 
			end Try 
			begin catch
				Raiserror('Trying Schema for 2008',0,1)
			end Catch

			Begin Try -- 2008
			if isnull(@RetentionType,'2008')='2008'	
			BEGIN
			insert into #BFTemp ([BackupName],[BackupDescription],[BackupType],[ExpirationDate],[Compressed],[Position],[DeviceType],[UserName],[ServerName],[DatabaseName],[DatabaseVersion],[DatabaseCreationDate],[BackupSize],[FirstLSN],[LastLSN],[CheckpointLSN],[DatabaseBackupLSN],[BackupStartDate],[BackupFinishDate],[SortOrder],[CodePage],[UnicodeLocaleId],[UnicodeComparisonStyle],[CompatibilityLevel],[SoftwareVendorId],[SoftwareVersionMajor],[SoftwareVersionMinor],[SoftwareVersionBuild],[MachineName],[Flags ],[BindingID],[RecoveryForkID],[Collation],[FamilyGUID],[HasBulkLoggedData],[IsSnapshot],[IsReadOnly],[IsSingleUser],[HasBackupChecksums],[IsDamaged],[BeginsLogChain],[HasIncompleteMetaData],[IsForceOffline],[IsCopyOnly],[FirstRecoveryForkID],[ForkPointLSN],[RecoveryModel],[DifferentialBaseLSN],[DifferentialBaseGUID],[BackupTypeDescription],[BackupSetGUID],[CompressedBackupSize])
			Exec (@stmt) 
					If @RetentionType is null 
				   select @RetentionType='2008'
			  goto SuccessRead
			end 
			end Try 
			begin catch
				Raiserror('Trying Schema for 2005',0,1)
			end Catch

			Begin Try -- 2005
		  	if isnull(@RetentionType,'2005')='2005'	
			BEGIN
			/* Columns are determined by the SQL Instance Version */
			insert into #BFTemp (BackupName,BackupDescription,BackupType,ExpirationDate,Compressed,Position,DeviceType,UserName,ServerName,DatabaseName,DatabaseVersion,DatabaseCreationDate,BackupSize,FirstLSN,LastLSN,CheckpointLSN,DatabaseBackupLSN,BackupStartDate,BackupFinishDate,SortOrder,[CodePage],UnicodeLocaleId,UnicodeComparisonStyle,CompatibilityLevel,SoftwareVendorId,SoftwareVersionMajor,SoftwareVersionMinor,SoftwareVersionBuild,MachineName,Flags,BindingID,RecoveryForkID,Collation,FamilyGUID,HasBulkLoggedData,IsSnapshot,IsReadOnly,IsSingleUser,HasBackupChecksums,IsDamaged,BeginsLogChain,HasIncompleteMetaData,IsForceOffline,IsCopyOnly,FirstRecoveryForkID,ForkPointLSN,RecoveryModel,DifferentialBaseLSN,DifferentialBaseGUID,BackupTypeDescription,BackupSetGUID,CompressedBackupSize)
			Exec (@stmt) 
					If @RetentionType is null 
				   select @RetentionType='2005'
				goto SuccessRead
			end 
			end Try 
			begin catch
				Raiserror('Schema not found',0,1)
			end Catch


		  if @Debug> 0 raiserror(@ERM,0,1)  
		  if @Debug> 0 raiserror(@stmt,0,1)  

		  if not exists (select * from #BFTemp) and @RetentionType is not null 
		  Begin
				Select @RetentionType = null 
				GOTO ResetRetentionType
		  end

		  if not exists (select * from #BFTemp) and @RetentionType is null 
		  Begin
			select @ERM = 'A valid [RESTORE HEADLER ONLY] Schema Not found for file ' + isnull(@filepath,'WTF NULL') + ' the backup file is suspect and will require manual intervention to be removed.'
			  exec ops.dbo.RaiseAlert @message=@erm, @type='Warning', @Errorid=3333, @debug=@debug 
			  Raiserror(@ERM,1,1)
		  end

		  SuccessRead:
		  /* Here I am only using the columns I need */
		  if @debug > 0 
		    Raiserror('Adding to BackupFiles',0,1) with nowait 

		  END TRY 
		  BEGIN CATCH

			select @ERM = 'ERROR_NUMBER: ' + cast(ERROR_NUMBER() as varchar(50)) 
			+  ' ERROR_SEVERITY: ' + cast(ERROR_NUMBER() as varchar(50)) 
			+ char(10) + 'ERROR_MESSAGE: ' + ERROR_MESSAGE()
			, @ERN = ERROR_NUMBER(), @ERS = ERROR_SEVERITY()
			
			Raiserror(@ERM,@ERS,1) with nowait 
			goto onErrorExitCursor 

		  END CATCH 


		  insert into ops.dbo.BackupFiles([Filepath] ,[BackupName] ,[BackupDescription] ,[BackupType] ,[ExpirationDate] ,[Compressed] ,[Position] ,[DeviceType] ,[UserName] ,[ServerName] ,[DatabaseName] ,[DatabaseVersion] ,[DatabaseCreationDate] ,[BackupSize] ,[FirstLSN] ,[LastLSN] ,[CheckpointLSN] ,[DatabaseBackupLSN] ,[BackupStartDate] ,[BackupFinishDate] ,[SortOrder] ,[CodePage] ,[UnicodeLocaleId] ,[UnicodeComparisonStyle] ,[CompatibilityLevel] ,[SoftwareVendorId] ,[SoftwareVersionMajor] ,[SoftwareVersionMinor] ,[SoftwareVersionBuild] ,[MachineName] ,[Flags] ,[BindingID] ,[RecoveryForkID] ,[Collation] ,[FamilyGUID] ,[HasBulkLoggedData] ,[IsSnapshot] ,[IsReadOnly] ,[IsSingleUser] ,[HasBackupChecksums] ,[IsDamaged] ,[BeginsLogChain] ,[HasIncompleteMetaData] ,[IsForceOffline] ,[IsCopyOnly] ,[FirstRecoveryForkID] ,[ForkPointLSN] ,[RecoveryModel] ,[DifferentialBaseLSN] ,[DifferentialBaseGUID] ,[BackupTypeDescription] ,[BackupSetGUID] ,[CompressedBackupSize])
		  select @Filepath ,[BackupName] ,[BackupDescription] ,[BackupType] ,[ExpirationDate] ,[Compressed] ,[Position] ,[DeviceType] ,[UserName] ,[ServerName] ,[DatabaseName] ,[DatabaseVersion] ,[DatabaseCreationDate] ,[BackupSize] ,[FirstLSN] ,[LastLSN] ,[CheckpointLSN] ,[DatabaseBackupLSN] ,[BackupStartDate] ,[BackupFinishDate] ,[SortOrder] ,[CodePage] ,[UnicodeLocaleId] ,[UnicodeComparisonStyle] ,[CompatibilityLevel] ,[SoftwareVendorId] ,[SoftwareVersionMajor] ,[SoftwareVersionMinor] ,[SoftwareVersionBuild] ,[MachineName] ,[Flags] ,[BindingID] ,[RecoveryForkID] ,[Collation] ,[FamilyGUID] ,[HasBulkLoggedData] ,[IsSnapshot] ,[IsReadOnly] ,[IsSingleUser] ,[HasBackupChecksums] ,[IsDamaged] ,[BeginsLogChain] ,[HasIncompleteMetaData] ,[IsForceOffline] ,[IsCopyOnly] ,[FirstRecoveryForkID] ,[ForkPointLSN] ,[RecoveryModel] ,[DifferentialBaseLSN] ,[DifferentialBaseGUID] ,[BackupTypeDescription] ,[BackupSetGUID] ,[CompressedBackupSize] 
		  from #BFTemp 

		  Delete #BFTemp 


	END
	FETCH NEXT FROM FileCursor INTO @filepath,@fdate
END

OnErrorExitCursor: 

CLOSE FileCursor
DEALLOCATE FileCursor

END
GO


if 2=1 
BEGIN
	select 
	  bf.servername
	  , bf.databasename
	  , br.RetentionPath 
	  , bf.Filepath
	  -- delete bf
	from 
	 ops.dbo.BackupFiles bf
	  left outer join ops.dbo.BackupFiles_Retention br on br.DatabaseName=bf.DatabaseName and br.ServerName = bf.ServerName
	where 1=1
	 and filepath like '\\%' 
	 and (1=0
	 or CHARINDEX(bf.servername,filepath)=0 
	 or CHARINDEX(bf.databasename,filepath)=0 
	 )
	 order by 
	  br.ServerName
	  , br.DatabaseName 

	 -- truncate table ops.dbo.backupfiles 


END