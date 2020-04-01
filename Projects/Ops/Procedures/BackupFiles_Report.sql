USE OPS
GO
SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO
IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'BackupFiles_Report' )
   DROP PROCEDURE dbo.BackupFiles_Report
GO

-- =============================================
-- Author:		Randy
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE dbo.BackupFiles_Report 
	@rootpath varchar(max) = null 
	, @servername varchar(max) = null
	, @databasename varchar(max) = null 
	, @debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
, @overview bit = 0  
if isnull(@servername,'')='' and isnull(@rootpath,'')='' and isnull(@databasename,'')=''
begin
	select @overview=1 
end

SELECT * 
  --into #Report 
FROM (
SELECT 
 [MachineName]
,[ServerName]
,[DatabaseName]
,[BackupTypeDescription]
,[Compressed]
, left(bf.filepath,charindex('\',bf.filepath,charindex('\',bf.filepath,3)+1)) [RootPath]
, (select top 1 RecoveryModel from dbo.BackupFiles ml where ml.DatabaseName = bf.databasename order by BackupStartDate desc) [RecoveryModel]
	  , Count([Fileid]) [NumFiles]
      ,Sum([BackupSize]) TotalSize 
      ,Min([BackupStartDate]) FirstBackupDate 
	  ,max([BackupStartDate]) LastBackupDate 
	  , datediff(HOUR,max([BackupStartDate]),getdate()) [AgeInHours]
     ,Sum([CompressedBackupSize]) [SumCompressedSize]
  FROM 
	[Ops].[dbo].[BackupFiles] bf
where 1=1 
 	and ((isnull(@Servername,'')='') OR (bf.ServerName like '%' + @servername + '%'))
	and (((isnull(@databasename,'')='') and (DatabaseName not in ('master','msdb','Ops','model'))) OR (bf.DatabaseName like (@databasename + '%')))
    and ((isnull(@rootpath,'')='') OR (Charindex(@rootpath,filepath) !=0 ))
group by  
	[ServerName]
      ,[DatabaseName]
	  ,[MachineName]
	  ,[BackupTypeDescription]
      ,[Compressed]
	  , left(bf.filepath,charindex('\',bf.filepath,charindex('\',bf.filepath,3)+1))
) md
order by 
  Rootpath,
  	Databasename, BackupTypeDescription, ServerName

--if @@ROWCOUNT = 0 
--Begin
	
--end 
  

END
GO


IF 1=2
BEGIN

DECLARE @rootpath varchar(max) = null 
	,@servername varchar(max) = null 
	,@databasename varchar(max) = null 
	,@debug int  = null 

SELECT @rootpath = @rootpath --varchar
	,@servername = @servername --'ATLAS-DW-01' --varchar
	,@databasename = @databasename --varchar
	,@debug = @debug --int

EXECUTE [dbo].BackupFiles_Report @rootpath = @rootpath --varchar
	,@servername = @servername --varchar
	,@databasename = @databasename --varchar
	,@debug = 1 --int



END