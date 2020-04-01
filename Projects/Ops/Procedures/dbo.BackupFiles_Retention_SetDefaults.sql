USE [Ops]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BackupFiles_Retention_SetDefaults]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[BackupFiles_Retention_SetDefaults]
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BackupFiles_Retention_SetDefaults]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[BackupFiles_Retention_SetDefaults] AS' 
END
GO

ALTER proc [dbo].[BackupFiles_Retention_SetDefaults]
	@RootPath varchar(max) = null
	, @servername varchar(max) = null
	, @databasename varchar(max) = null
	, @Retention int = null 
	, @DefaultRetention int = null 
    , @DefaultPath nvarchar(max) = null 
	, @debug int = null 
as
BEGIN
SET NOCOUNT ON;
DECLARE @ERM nvarchar(max), @ERS int , @ERN int 
, @includeall bit 
/* Assure Defualt Data Rentention Values exist 
	select ops.dbo.fnSetting('BackupFiles','DefaultRetention')
	BackupFiles_updateclusters Depends on a View created from XML in XML reports 
	This will update the ServerValue on Records in dbo.BackupFiles to the Listener Name. 
	This will allow point in time recovery across a cluster even within the failover window.  
*/

EXECUTE [dbo].BackupFiles_updateclusters @debug=@debug 

if @DefaultPath > 'C:\' or @DefaultPath > '\\' 
Begin 
   if @DefaultPath != ops.dbo.fnSetting('Instance','BackupDirectory')
   Begin     
        EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', REG_SZ, @DefaultPath
        exec ops.dbo.Settings_put @Context='Instance',@Name='BackupDirectory',@Value=@defaultpath   
    End 
    
end 
  else 
SET @defaultpath = ops.dbo.fnSetting('Instance','BackupDirectory')


if @DefaultRetention is null 
BEGIN
  select @DefaultRetention = isnull(ops.dbo.fnSetting('BackupFiles','DefaultRetention'),3)  
END

exec ops.dbo.Settings_put @context='BackupFiles', @Name='DefaultRetention', @value=@DefaultRetention 
  
insert into ops.dbo.BackupFiles_Retention (ServerName, DatabaseName, RetentionDays, RetentionPath)
select @@SERVERNAME, name , @DefaultRetention, @DefaultPath+'\'+name 
from 
    master.sys.databases 
where 1=1
  and name not in ('model','tempdb')
  and Name not in (select databasename from ops.dbo.BackupFiles_Retention where ServerName=@@SERVERNAME)

if isnull(@Retention,0) > 0 -- Minimum of 1 
Begin

if @RootPath is null and @servername is null and @databasename=null 
 Set @includeall = 1 

	select @ERM = '@ServerName:' + isnull(@servername,'') + '
    @DatabaseName:'+isnull(@databasename,'')+'
    @Rootpath:' + isnull(@RootPath,'')
	  if @Debug > 0 Raiserror(@ERM,0,1) with nowait 

	update br set br.RetentionDays=@Retention
	from dbo.BackupFiles_Retention br 
	where 1=1 
	 and ((isnull(@servername,'')='') OR ([servername]=@servername))
	 and ((isnull(@databasename,'')='') OR ([DatabaseName]=@databasename))
	 and ((isnull(@RootPath,'')='') OR (br.RetentionPath like @RootPath+'%'))
     or @includeall=1 

	select @ERM = 'Updated ' + cast(@@rowcount as varchar(50)) + ' Existing Records' 
		IF @debug > 0 Raiserror(@ERM,0,1) with nowait

End 

  


 
if @debug > 0 
select 
	md.ServerName
	, md.DatabaseName
	, sum(md.CompressedBackupSize) [Size]
	, Count(md.Fileid) [NumFulls]
	, md.RetentionDays
    , min(md.BackupStartDate) Oldest 
	, max(md.BackupStartDate) Newest
    , md.RetentionPath
from (
select 
	bf.Fileid
	,bf.ServerName
	,bf.DatabaseName
	,bf.BackupStartDate
	,bf.BackupTypeDescription
	,bf.CompressedBackupSize
	, dr.[RetentionDays] 
    , dr.RetentionPath
from 
	dbo.BackupFiles bf
	left outer join  [dbo].[BackupFiles_Retention] dr on dr.servername = bf.servername and dr.databasename=bf.databasename 
 WHERE 1=1
	and bf.BackupType=1 
	and ((isnull(@Servername,'')='') OR (bf.ServerName=@servername))
	and ((isnull(@databasename,'')='') OR (bf.DatabaseName=@databasename))
	and ((isnull(@rootpath,'?')='?') OR (bf.Filepath like @RootPath+'%'))
) md
group by 
    md.ServerName
    , md.DatabaseName 
    , md.RetentionDays
    , md.RetentionPath


END 

GO

if 1=2 
Begin
SET  NOCOUNT ON; 

-- exec sp_help_executesproc @procname='BackupFiles_Retention_SetDefaults'
--Truncate table ops.dbo.BackupFiles_Retention

DECLARE @RootPath varchar(max) = null 
	,@servername varchar(max) = null 
	,@databasename varchar(max) = null 
	,@Retention int  = null 
	,@DefaultRetention int  = null 
	,@debug int  = null 

--SELECT @RootPath = @RootPath --varchar
--	,@servername = @servername --varchar
--	,@databasename = 'master' --varchar
--	,@Retention = 1 --int
--	,@DefaultRetention = @DefaultRetention --int
--	,@debug = 1 --int

EXECUTE [dbo].BackupFiles_Retention_SetDefaults @RootPath = @RootPath --varchar
	,@servername = @servername --varchar
	,@databasename = @databasename --varchar
	,@Retention = @Retention --int
	,@DefaultRetention = @DefaultRetention --int
	,@debug = 1 --int

    -- select * from ops.dbo.BackupFiles_Retention

end 
GO



