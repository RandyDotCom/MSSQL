USE [Ops]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BackupsCleaner]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[BackupsCleaner]
GO

Create Procedure dbo.BackupsCleaner 
	@RootPath varchar(max) = null
	, @servername varchar(max) = null
	, @databasename varchar(max) = null
	, @Retention int = null 
	, @purge bit = null
	, @debug int = null 
AS
BEGIN
SET NOCOUNT ON; 


declare @ERM nvarchar(max), @ERS int, @ERN int 
DECLARE @command varchar(4000), @fileid int, @rc int, @Filepath varchar(max) 
declare @cmdout table (line varchar(max)) 

IF @Debug > 0 
Begin
	Raiserror('To Set Retention Days, use parameters  @ServerName OR @DatabaseName and number of max days',0,1) with nowait 
END 


BEGIN TRY

EXECUTE [dbo].BackupFiles_Retention_SetDefaults @RootPath = @RootPath --varchar
	,@servername = @servername --varchar
	,@databasename = @databasename --varchar
	,@Retention = @Retention --int
	,@debug = @debug --int

END TRY
BEGIN CATCH
	Raiserror('HERE',0,1)
		SELECT @ERM = ERROR_MESSAGE(), @ERN = ERROR_NUMBER() , @ERS=ERROR_SEVERITY()
		SELECT @ERM = 'ErrorNumber:' + CAST(@ERN as varchar(10))+' ErrorSeverity:'+Cast(@ERS as varchar(10)) + char(10) + @ERM 
		Raiserror(@ERM,@ERS,1)
		RETURN 0;

END CATCH


if @RootPath is null 
 select @RootPath = dbo.fnSetting('Instance', 'BackupDirectory')

if @RootPath is null 
BEGIN
	SELECT @ERM = 'Ops Settings table has a null value for Instance / Backup directory'
	Raiserror(@ERM,11,1)
	REturn 0;
END

SELECT @ERM = 'Cleaning ' + @RootPath 
Raiserror(@ERM,0,1) with nowait 

If @Purge=1
Begin
  if not exists(select 1 from dbo.BackupFiles where ServerName=@servername)
   Begin
    Select @ERM = 'A Valid Servername is required for the @purge Process'
	Raiserror(@ERM,11,1) with nowait 
	Return 0;
   end 

end 



if not exists(select * from dbo.BackupFiles where 1=1 
 and ((filepath like (@RootPath+'%')) OR (@purge=1))
 and ((isnull(@databasename,'')='') OR ([databasename]=@databasename))
 and ((isnull(@servername,'')='') OR ([servername]=@servername))
 )
Begin
	Select @ERM = 'There are no logged backup files in '+ @RootPath + '
	Execute dbo.BackupFiles_get @rootpath='''+ @RootPath + ''''  
	Raiserror(@ERM,0,1) 
	Return 1;
END

update BackupFiles set ExpirationDate = null, BackupDescription = null 
where 1=1 
 and ((filepath like (@RootPath+'%')) OR (@purge=1))
 and ((isnull(@databasename,'')='') OR ([databasename]=@databasename))
 and ((isnull(@servername,'')='') OR ([servername]=@servername))


/* Always Keep the Last Full */

update bf set bf.ExpirationDate = BackupStartDate, BackupDescription=isnull(BackupDescription,'LastFulls')
  -- select bf.BackupStartDate
from 
 dbo.BackupFiles bf
 inner join (
  select Databasename, Servername, BackupType, max(BackupStartdate) [FileDate]
  from dbo.BackupFiles with (readcommitted)
  Where 1=1 
   and BackupType=1
    and ((filepath like (@RootPath+'%')) OR (@purge=1))
	and ((isnull(@databasename,'')='') OR ([databasename]=@databasename))
	and ((isnull(@servername,'')='') OR ([servername]=@servername))
  Group by 
    Databasename, ServerName, BackupType
	) LF on lf.DatabaseName = bf.DatabaseName and lf.ServerName = bf.ServerName and lf.FileDate = bf.BackupStartDate 


--SELECT @Retention 

/* Keep Allbackups newer than retention Days*/
update bf set bf.ExpirationDate = bf.BackupStartDate, BackupDescription=isnull(BackupDescription,'RetainedFulls') 
  -- select bf.BackupStartDate
from 
 dbo.BackupFiles bf
 inner join [BackupFiles_Retention] dr on dr.ServerName = bf.ServerName and dr.DatabaseName = bf.DatabaseName
WHERE 1=1 
    and ((filepath like (@RootPath+'%')) OR (@purge=1))
	and ((isnull(@databasename,'')='') OR (bf.[databasename]=@databasename))
	and ((isnull(@servername,'')='') OR (bf.[servername]=@servername))
 and bf.backuptype=1
 and BackupStartDate >= Dateadd(DAY,(dr.RetentionDays * -1),Convert(Date,getdate()))


 update bf Set ExpirationDate = Keepers.KeepDate, BackupDescription=isnull(BackupDescription,'PointInTime') 
  from dbo.BackupFiles bf 
   inner join (SELECT Min(ExpirationDate) KeepDate, ServerName, DatabaseName 
   from dbo.BackupFiles 
   where 1=1 
    and ((filepath like (@RootPath+'%')) OR (@purge=1))
	and ((isnull(@databasename,'')='') OR ([databasename]=@databasename))
	and ((isnull(@servername,'')='') OR ([servername]=@servername))
	and backuptype=1
   Group by ServerName, Databasename
   ) Keepers 
	on Keepers.ServerName = bf.ServerName and Keepers.DatabaseName = bf.DatabaseName 
where  1=1 
 and bf.BackupType != 1 
 and bf.BackupStartDate >= Keepers.KeepDate 
 and bf.BackupStartDate >= Dateadd(DAY,-3,Convert(Date,getdate()))
 -- and bf.ExpirationDate is null  

/*
	TODO 
	  Do not delete trns when there is not Full backup logged 

*/

update t set ExpirationDate = Getdate(), BackupDescription='Missing Full'
from 
  ops.dbo.BackupFiles t
  left join dbo.BackupFiles f on f.ServerName = t.ServerName and f.DatabaseName = t.DatabaseName and f.BackupType=1
where 1=1
 and t.BackupType != 1 
 and f.Fileid is null 

if @debug > 1 
begin

	select 
	case when ExpirationDate is null then 'DELETE' else 'Keeping' end as [Action]
	, datediff(day,bf.BackupStartDate,convert(date,getdate())) [Agedays]
	, datediff(hour,bf.BackupStartDate,getdate()) [AgeHours]
	--, Dateadd(DAY,(dr.RetentionDays * -1),Convert(Date,getdate())) [RetentionDate]
	, dr.RetentionType [retention]
	, dr.RetentionDays
	, bf.BackupDescription
	, bf.ServerName
		, bf.DatabaseName
		, bf.RecoveryModel
		, bf.BackupStartDate
		--, bf.BackupType
		, bf.BackupTypeDescription
		, bf.ExpirationDate
		, bf.filepath 
	from dbo.BackupFiles bf
	 left outer join dbo.BackupFiles_Retention dr on dr.ServerName = bf.servername and dr.DatabaseName=bf.databasename 
	where 1=1 
    and ((filepath like (@RootPath+'%')) OR (@purge=1))
	and ((isnull(@databasename,'')='') OR (bf.[databasename]=@databasename))
	and ((isnull(@servername,'')='') OR (bf.[servername]=@servername))
	--and ExpirationDate is null 
	--and backuptype=1 
	order by 
	  ServerName, databasename, BackupType, [BackupStartDate] DESC 

	return 1; 
end 


if isnull(@debug,0) = 1 
select Filepath,fileid 
  from BackupFiles bf
where 1=1 
	and ExpirationDate is null 
	and ((filepath like (@RootPath+'%')) OR (@purge=1))
	and ((isnull(@databasename,'')='') OR (bf.[databasename]=@databasename))
	and ((isnull(@servername,'')='') OR (bf.[servername]=@servername))
for xml raw, elements, root('tobedeleted')

FileKillCursor: 

if isnull(@debug,0) <= 1 
BEGIN

DECLARE filecursor CURSOR READ_ONLY FOR 
select Filepath,fileid 
  from BackupFiles bf
where 1=1 
	and ExpirationDate is null 
	and ((filepath like (@RootPath+'%')) OR (@purge=1))
	and ((isnull(@databasename,'')='') OR (bf.[databasename]=@databasename))
	and ((isnull(@servername,'')='') OR (bf.[servername]=@servername))

OPEN filecursor

FETCH NEXT FROM filecursor INTO @Filepath, @fileid 
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		Begin Try 

		SELECT @command = 'del "' + @Filepath+ '"'
		if @debug is not null
		  raiserror(@command,0,1) with nowait 

		insert into @cmdout(line) 
		exec @rc = xp_cmdshell @command 

		  select @erm = @command + char(10) + 'Returned Code:' + cast(@rc as varchar(10)) 
		  SELECT @erm = Coalesce(@ERM + char(10),'') + isnull(line,'-- NULL --') from @cmdout 
		  select @ERS = case WHEN @rc < 2 then 0 else 11 end 

		  if @debug > 0
		  Raiserror(@ERM,@ERS,1) with nowait 

		delete from dbo.BackupFiles where fileid = @fileid

		End Try

		Begin Catch

			select @ERM = Coalesce(@ERM,' @ERM NULL') + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			
			Raiserror(@ERM,@ERS,1)

			IF @ERS >= 11 Goto OnErrorExitCursor

		End Catch

		delete @cmdout 

	END
	FETCH NEXT FROM filecursor INTO @Filepath,@fileid
END

OnErrorExitCursor: 


CLOSE filecursor
DEALLOCATE filecursor


END

END 

GO

if 1=2 
BEGIN
 -- exec sp_help_executesproc @procname='settings_put'
 
exec ops.dbo.BackupsCleaner @rootpath='E:\MSSQL12.MSSQLSERVER\MSSQL\Backup\PulledFromProd' 
, @debug=1

END 

