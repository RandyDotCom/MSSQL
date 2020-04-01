USE [Ops]
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dba_Instance_Files_get') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[dba_Instance_Files_get]
GO
-- =============================================
-- Author:		Randy
-- Create date: April 2012
-- Description:	Stores the file info on the instance
-- =============================================
CREATE PROCEDURE dbo.dba_Instance_Files_get 
	@rename bit = null ,
	@filter varchar(max) = null, 
	@Debug int = null
AS
BEGIN
SET NOCOUNT ON;
declare @drives table(drive varchar(1), mbfree real) 
insert into @drives(drive,mbfree) 
exec master.sys.xp_fixeddrives

--IF OBJECT_ID('tempdb..#FileStats') is null 
BEGIN

	IF OBJECT_ID('tempdb..#FileStats') is not null 
	 DROP TABLE #FileStats 

SELECT 
	Convert(varchar(max),SERVERPROPERTY('Servername')) [ServerName] 
	, db_name(mf.database_id) Databasename 
	, mf.name [LogicalName]
	, mf.physical_name
	, mf.size
	, mf.type_desc
into #FileStats 
FROM sys.dm_io_virtual_file_stats(Null,null)  fs
  inner join master.sys.master_files mf on mf.database_id = fs.database_id and mf.file_id = fs.file_id 
  inner join @drives dr on dr.drive = left(mf.physical_name,1) 


END


if isnull(@rename,0)=1 
BEGIN
	Declare @stmt varchar(max) 

	IF exists(Select * from #FileInfo where LogicalName not like (dbname + '%') and dbname not in ('master','model','msdb','tempdb'))
	BEGIN
		SELECT @stmt = null 
		SELECT @stmt = coalesce(@stmt+char(10),'') + 'ALTER DATABASE [' + dbname+ '] MODIFY FILE (NAME=N''' + LogicalName + ''', NEWNAME=N''' + dbname  
		+ case groupid when 0 then '_log' else '_data' end  
		+ Case when fileid+Groupid > 2 then '_' + CAST((fileid+Groupid-1) as varchar(10)) else '' end  +''')'
		From #FileInfo f
		inner join master.sys.databases msd on msd.name = f.dbname
		 where msd.database_id > 4
		and msd.is_in_standby = 0
		and msd.state_desc='ONLINE' 
	
	
		Raiserror(@stmt,0,1)
		if isnull(@debug,0) < 1 
			 Exec (@stmt) 

	END

END 


Declare @now datetime 
Select @now = Getdate()

--INSERT INTO [dbo].[dba_Instance_Files_log]
--           ([Snapshot]
--           ,[Server]
--           ,[dbname]
--           ,[Fileid]
--           ,[Groupid]
--           ,[size]
--           ,[LogicalName]
--           ,[Recovery_model]
--           ,[PhysicalName]
--           ,[TotalExtents]
----           ,[UsedExtents])
--Select 
--	@now as [Snapshot]
--  , Convert(varchar(400),serverproperty('servername')) [Server]
--  , fd.dbname
--  , fd.Fileid
--  , fd.Groupid
--  , fd.Size
--  , fd.Logicalname
--  , CASE msd.[recovery_model] when 1 then 'FULL' WHEN 3 then 'Simple' else 'Bulk Logged' end as [recovery_model] 
--  , FD.[Filename] as [PhysicalName]
--  , fs.TotalExtents
--  , fs.UsedExtents
--from 
--  #FileInfo fd
--  inner join master.sys.databases msd on fd.dbname = msd.[name]
--  left outer join #fileStats FS on FS.dbname=fd.dbname and fs.logicalname=fd.logicalname
--Where 1=1
----and fd.Groupid=0 
---- and fd.dbname not in ('master','msdb','model')
--order by 1
---- , fd.Size DESC 
--  , dbname

--SELECT * 
--FROM 
--	dbo.dba_Instance_Files_log 
--Where 1=1 
--	and [Snapshot]=@now 
--ORDER BY
--	dbName 
		
END
GO

--IF 1=2
BEGIN


EXECUTE [Ops].[dbo].[dba_Instance_Files_get] 
	@rename=Null
   , @filter = Null
   , @Debug = 1 


END
GO
