USE [Ops]
GO


IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[Database_status_v]'))
	DROP VIEW [dbo].[Database_status_v]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

declare @stmt varchar(max) 
if object_id('master.sys.availability_databases_cluster') is not null 
BEGIN

select @stmt = '
 Create View dbo.Database_status_v as 
select 
 md.database_id, 
 md.name as [DatabaseName]
 , md.compatibility_level 
 , CASE when is_read_only !=0 then ''READONLY'' else md.state_desc end state_desc
 , md.recovery_model_desc 
 , md.is_in_standby
 , isnull(ops.dbo.fnSetting(''Instance'',md.name), ars.role_desc) [HARole]
FROM
	master.sys.databases mD 
	left outer join master.sys.availability_databases_cluster dc on dc.database_name = mD.Name 
	left outer join master.sys.dm_hadr_availability_replica_states ars on ars.group_id = dc.group_id and ars.is_local=1
'


 
END
ELSE
BEGIN 

select @stmt = '
 Create View dbo.Database_status_v as 
SELECT 
 md.database_id,
  md.name as [DatabaseName]
 , md.compatibility_level 
 , CASE when is_read_only !=0 then ''READONLY'' else md.state_desc end state_desc
 , md.recovery_model_desc 
 , md.is_in_standby
 , cast(null as varchar(20)) as [HARole]
from 
 master.sys.databases md'

END

--raiserror(@stmt,0,1) 
exec (@stmt ) 
GO 

if 1=2 
select * from ops.dbo.Database_status_v

 --Exec ops.dbo.BackupDatabase @databasename = 'Ops', @backupType='Logs'