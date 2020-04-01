USE OPS
GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'BackupFiles_updateclusters' )
   DROP PROCEDURE dbo.BackupFiles_updateclusters
GO
-- =============================================
-- Author:		Randy
-- Create date: 20150224
-- Description:	updates Backupfiles with the listener name
-- =============================================
CREATE PROCEDURE dbo.BackupFiles_updateclusters 
	@servername nvarchar(128) = null, 
	@idserver int = null  ,
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
/*
	SEE [dbo].[BackupFiles_Retention_SetDefaults] For Creating Cluster XML Records 

*/
	update bf set bf.ServerName = cv.Listener_Name
	  -- select * 
	from 
		dbo.HADRClusterData_v cv
		inner join dbo.BackupFiles bf on cv.server_name = bf.servername and cv.database_name = bf.databasename 

		select @ERM = 'Updated '  +  cast(@@ROWCOUNT as varchar(10)) + ' Rows from view dbo.HADRClusterData_v' 
		if @debug > 0 
			Raiserror(@ERM,0,1) with nowait
	   
	if @debug > 1 
	  select * from dbo.HADRClusterData_v 
	
END
GO
if object_id('master.sys.dm_hadr_database_replica_cluster_states') is null 
BEGIN

EXEC dbo.sp_executesql @statement = N'-- =============================================
-- Author:		Randy
-- Create date: 20150224
-- Description:	updates Backupfiles with the listener name
-- =============================================
ALTER PROCEDURE [dbo].[BackupFiles_updateclusters] 
	@servername nvarchar(128) = null, 
	@idserver int = null  ,
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
	Return 1; -- This Server is not HADR capable
	
END
' 
END
GO



IF 1=2
BEGIN

	-- update ops.dbo.BackupFiles set ServerName = 'ATLASSQLHDR12' where ServerName !='ATLASSQLHDR12'

	--exec sp_help_executesproc @procname='BackupFiles_updateclusters'

DECLARE @servername nvarchar(256) = null 
	,@idserver int  = null 
	,@debug int  = null 

--SELECT @servername = @servername --nvarchar
--	,@idserver = @idserver --int
--	,@debug = @debug --int

EXECUTE [dbo].BackupFiles_updateclusters @servername = @servername --nvarchar
	,@idserver = @idserver --int
	,@debug = @debug --int

END


if 1=2 
BEGIN

 
/* Example Creates and Stashs the XML required for the View > Procedure BackupFiles_updateclusters */
  DECLARE @xdata xml 
select @xdata = (
  SELECT	
		'PC-PSQL-L' clustername
		, 'PC-PSQL-L' listener
		, servername
		, databasename 
from 
  ops.dbo.BackupFiles [resource]
  where 1=1 
   and servername in ('PC-PSQL4','PC-PSQL5','PC-PSQL-L')
   and databasename in ('PerfGate','PerfGateWiki')
Group by 
	ServerName
		, databasename 
FOR XML AUTO, ROOT('HADRCluster')
) 

  exec ops.dbo.xmlReports_put @xdid=null, @property='PC-PSQL-L', @Context='HADRCluster',@xdata=@xdata 
  exec ops.dbo.BackupFiles_Report @servername='PC-PSQL-L'
  select * from ops.dbo.HADRClusterData_v
 
END 