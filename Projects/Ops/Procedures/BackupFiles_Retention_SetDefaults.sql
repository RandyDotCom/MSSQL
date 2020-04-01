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
	, @debug int = null 
as
BEGIN
SET NOCOUNT ON;
DECLARE @ERM nvarchar(max), @ERS int , @ERN int 
/* Assure Defualt Data Rentention Values exist */

EXECUTE [dbo].BackupFiles_updateclusters @debug=@debug 


 select @RootPath = isnull(@RootPath,ops.dbo.fnSetting('Instance','BackupDirectory'))
 
 if @debug > 0 
   raiserror(@rootpath,0,1) with nowait 

if @DefaultRetention is null 
BEGIN
  select @DefaultRetention = isnull(ops.dbo.fnSetting('BackupFiles','DefaultRetention'),3)  
END
exec ops.dbo.Settings_put @context='BackupFiles', @Name='DefaultRetention', @value=@DefaultRetention 

  
if isnull(@Retention,0) > 0 -- Minimum of 1 
Begin

	select @ERM = isnull(@servername,'')+isnull(@databasename,'')+isnull(@RootPath,'')
	  if @Debug > 0 Raiserror(@ERM,0,1) with nowait 

	update br set br.RetentionDays=@Retention
	from dbo.BackupFiles_Retention br 
	where 1=1 
	 and ((isnull(@servername,'')='') OR ([servername]=@servername))
	 and ((isnull(@databasename,'')='') OR ([DatabaseName]=@databasename))
	 and ((isnull(@RootPath,'')='') OR (br.RetentionPath like @RootPath+'%'))

	select @ERM = 'Updated ' + cast(@@rowcount as varchar(50)) + ' Existing Records' 
		IF @debug > 0 Raiserror(@ERM,0,1) with nowait

End 
else 
  select @Retention = isnull(convert(int,ops.dbo.fnSetting('BackupFiles','DefaultRetention')),3)



/*	select ops.dbo.fnSetting('BackupFiles','DefaultRetention')
	BackupFiles_updateclusters Depends on a View created from XML in XML reports 
	This will update the ServerValue on Records in dbo.BackupFiles to the Listener Name. 
	This will allow point in time recovery across a cluster even within the failover window.  

 */



select 
	md.ServerName
	, md.DatabaseName
	, isnull(md.RootPath,ops.dbo.fnSetting('Instance','BackupDirectory')) [RootPath]
	, sum(md.CompressedBackupSize) [Size]
	, Count(md.Fileid) [NumFulls]
	, min(md.BackupStartDate) Oldest 
	, max(md.BackupStartDate) Newest
	, md.DRID
	, md.RetentionDays
into #report 
from (
select 
	bf.Fileid
	,bf.ServerName
	,bf.DatabaseName
	,bf.BackupStartDate
	,bf.BackupTypeDescription
	,bf.CompressedBackupSize
	,dr.DRID
	, @retention as [RetentionDays]
    , CASE WHEN bf.Filepath not like '\\%' then left(filepath,charindex('\',filepath,5))+bf.DatabaseName 
		else left(bf.Filepath,charindex('\',bf.filepath,charindex('\',bf.filepath,4)+1)) End as RootPath
from 
	dbo.BackupFiles bf
	left outer join  [dbo].[BackupFiles_Retention] dr on dr.servername = bf.servername and dr.databasename=bf.databasename 
 WHERE 1=1
	and bf.BackupType=1 
	and ((isnull(@Servername,'')='') OR (bf.ServerName=@servername))
	and ((isnull(@databasename,'')='') OR (bf.DatabaseName=@databasename))
	and ((isnull(@rootpath,'')='') OR (bf.Filepath like @RootPath+'%'))
) md
group by 
 md.ServerName
 , md.DatabaseName 
 , md.RootPath
 	, md.DRID
	, md.RetentionDays

IF isnull(@debug,0) < 2 
Begin

	INSERT INTO [dbo].[BackupFiles_Retention]
			   ([ServerName]
			   ,[DatabaseName]
			   ,[RetentionDays]
			   ,[RetentionPath])
	SELECT ServerName, DatabaseName, RetentionDays, RootPath
	From #Report
	where DRID is null 

	select @ERM = 'Added ' + cast(@@rowcount as varchar(50)) + ' Defaults' 
	IF @debug > 0 Raiserror(@ERM,0,1) with nowait


END

END 

IF @debug > 0 
  Select dr.* 
  , rp.Newest
  , rp.Oldest
  from dbo.BackupFiles_Retention dr
  inner join #report rp on rp.DRID=dr.DRID 
   order by dr.ServerName, rp.rootpath, dr.DatabaseName

GO

if 1=2 
Begin
SET  NOCOUNT ON; 

--exec sp_help_executesproc @procname='BackupFiles_Retention_SetDefaults'


DECLARE @RootPath varchar(max) = null 
	,@servername varchar(max) = null 
	,@databasename varchar(max) = null 
	,@Retention int  = null 
	,@DefaultRetention int  = null 
	,@debug int  = null 


Exec ops.dbo.BackupFiles_Retention_SetDefaults
	@debug=1
	 , @servername='OSGT3TSQL03'
	--, @rootpath='E:\MSSQL12.MSSQLSERVER\MSSQL\Backup\DeviceHealthThreshold'
	, @retention=1



	select * 
	from 
		-- Truncate Table 
		ops.dbo.BackupFiles_Retention 

end 
GO


--IF 1=2 
--BEGIN
--  /* Build Cluster XML*/ 

--   DECLARE @ERM nvarchar(MAX) , @DEBUG int 
--IF @debug = 1 
--BEGIN
--	select @ERM = ' 
--	Example creating a Cluster entry
--declare @xdata xml =''<HADRCluster>
--  <resource clustername="PC-PSQL-L" listener="PC-PSQL-L" servername="PC-PSQL4" databasename="PerfGate" />
--  <resource clustername="PC-PSQL-L" listener="PC-PSQL-L" servername="PC-PSQL5" databasename="PerfGate" />
--  <resource clustername="PC-PSQL-L" listener="PC-PSQL-L" servername="PC-PSQL4" databasename="PerfGateWiki" />
--  <resource clustername="PC-PSQL-L" listener="PC-PSQL-L" servername="PC-PSQL5" databasename="PerfGateWiki" />
--</HADRCluster>''
--exec ops.dbo.xmlReports_put @xdid=null, @property=''PC-PSQL-L'', @Context=''HADRCluster'',@xdata=@xdata 
--	 '
--	Raiserror(@ERM,0,1) with nowait 

--END

--  DECLARE @xdata xml 
--select @xdata = (
--  SELECT	
--		'OSGTFSCMSQL' clustername
--		, 'OSGTFSCMSQL' listener
--		, servername
--		, databasename 
--from 
--  ops.dbo.BackupFiles [resource]
--  where 1=1 
--   and servername in ('TFSCMSQL1','TFSCMSQL2')
--   and databasename in ('ReportServer','ReportServerTempDB','Tfs_Configuration','Tfs_DefaultCollection','Tfs_Warehouse')
--Group by 
--	ServerName
--		, databasename 
--FOR XML AUTO, ROOT('HADRCluster')
--) 
--  exec ops.dbo.xmlReports_put @xdid=null, @property='OSGTFSCMSQL', @Context='HADRCluster',@xdata=@xdata 


--END
