USE [Ops]
GO

IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[BackupInventory_v]'))
	DROP VIEW [dbo].[BackupInventory_v]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

Create View [dbo].[BackupInventory_v] as
select top 100 Percent 
  br.ServerName 
  , br.databasename 
  , br.BackupTypeDescription
    , CASE WHEN charindex(br.servername+'\'+br.databasename,filepath) > 2 then left(filepath,charindex(br.servername+'\'+br.databasename,filepath)-1) + br.servername+'\'+br.databasename else 
    left(filepath,len(filepath)-charindex('\',reverse(filepath)) ) 
     end as [ShareName]
  , Max(BackupStartDate) [BackupStartDate] 
  , Count(*) [FileCount] 
  , datediff(Day,Max(BackupStartDate),getdate()) [ageinDays]
  , sum(br.CompressedBackupSize) [SumOfSize]
  , count(distinct bfr.DRID) [RetentionRules]
  , min(bfr.RetentionDays) [MinRetention]
from 
  ops.dbo.BackupFiles br with (nolock)
    left outer join ops.dbo.BackupFiles_Retention bfr with (nolock) on bfr.ServerName=br.ServerName and bfr.DatabaseName=br.DatabaseName 
where 1=1 
 --and Filepath like '\\%' 
Group by 
  br.ServerName 
  , br.databasename 
  , br.BackupTypeDescription
, CASE WHEN charindex(br.servername+'\'+br.databasename,filepath) > 2 then left(filepath,charindex(br.servername+'\'+br.databasename,filepath)-1) + br.servername+'\'+br.databasename else 
    left(filepath,len(filepath)-charindex('\',reverse(filepath)) ) 
     end --as [ShareName]
order by 
  br.ServerName 
  , br.databasename
  , br.BackupTypeDescription

GO


if 1=2
 select * from [BackupInventory_v]