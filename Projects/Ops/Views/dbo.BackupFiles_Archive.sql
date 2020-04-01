USE [Ops]
GO

IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'[dbo].[BackupFiles_Archive]'))
	DROP VIEW [dbo].[BackupFiles_Archive]
GO

SET ANSI_NULLS ON ;SET QUOTED_IDENTIFIER ON
GO

Create View [dbo].[BackupFiles_Archive] 
as 
Select top 100 percent 
  ServerName 
  , DatabaseName
  , bf.BackupTypeDescription
  , max(bf.BackupStartDate) [LastBackupDate]
  , datediff(minute, max(bf.BackupStartDate),getdate()) [LastFileAgeInMinutes]
  , isnull(left( bf.Filepath,charindex(databasename, bf.Filepath)-1)+databasename,'FilePath Error') [SharePath]
  , count(*) FileCount
  , sum(convert(DECIMAL(20,0),bf.CompressedBackupSize)) [sumCompressedBackupSize] 
from  
  dbo.BackupFiles bf 
Where 1=1 
 --and isnull(left(Filepath,2),'\\')='\\'
 --and charindex(databasename, bf.Filepath)-1 > 10 
 --and databasename not in ('master','model','msdb','Ops','tempdb'))
 --and databasename not in ('CaritImport','model','msdb','Ops','tempdb')
Group by 
  ServerName 
  , DatabaseName
  , bf.BackupTypeDescription
  , isnull(left( bf.Filepath,charindex(databasename, bf.Filepath)-1)+databasename,'FilePath Error')
having 1=1
	 --or ServerName = 'WTTATLASSQL21' 
	 --or Databasename='ESCPlaceholder'
	 --or datediff(minute, max(bf.BackupStartDate),getdate())  > 4000
Order by 
 ServerName 
 , DatabaseName 
 , [SharePath]
GO 
