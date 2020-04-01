USE Ops
go

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'FileManager' )
   DROP PROCEDURE dbo.FileManager
GO
-- =============================================
-- Author:		Randy
-- Create date: 20160919
-- Description:	Reports the status and allows for space modification of Files
-- =============================================
CREATE PROCEDURE dbo.FileManager 
	@DatabaseName nvarchar(300) = null, 
	@SpaceRequiredMB decimal(20,2) = null,
	@Action varchar(40) = null  ,
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 

Declare @blob nvarchar(max) 

SET @blob = N'
DECLARE @XDATA XML, @dbname nvarchar(300); 
SELECT @dbname=DB_NAME(), @XDATA = (
SELECT * FROM (
SELECT 
    serverProperty(''ServerName'') [Servername]
	, db_name() as [DatabaseName]
   , [TYPE] = A.TYPE_DESC
    ,[FILE_Name] = A.name
    ,[FILEGROUP_NAME] = isnull(fg.name,''TRNLOG'')
    ,[File_Location] = A.PHYSICAL_NAME
    ,[FILESIZE_MB] = CONVERT(DECIMAL(10,2),A.SIZE/128.0)
    ,[USEDSPACE_MB] = CONVERT(DECIMAL(10,2),A.SIZE/128.0 - ((SIZE/128.0) - CAST(FILEPROPERTY(A.NAME, ''SPACEUSED'') AS INT)/128.0))
    ,[FREESPACE_MB] = CONVERT(DECIMAL(10,2),A.SIZE/128.0 - CAST(FILEPROPERTY(A.NAME, ''SPACEUSED'') AS INT)/128.0)
    ,[FREESPACE_PERCENT] = CONVERT(DECIMAL(10,2),((A.SIZE/128.0 - CAST(FILEPROPERTY(A.NAME, ''SPACEUSED'') AS INT)/128.0)/(A.SIZE/128.0))*100)
FROM sys.database_files A 
  LEFT JOIN sys.filegroups fg ON A.data_space_id = fg.data_space_id
) FileData 
for xml AUTO, root(''MSSQL'')  
); 
Exec ops.dbo.xmlReports_put @Property=@dbname, @context=''FileSpace'', @xdata=@XDATA;
' 
Print @Blob 

select @blob = Replace(Replace(replace(@Blob,char(13),''),char(10),' '),char(9),' ') 
While charindex('  ',@blob) != 0
Begin 
	SELECT @blob = replace(@Blob,'  ',' ')
end 
select @blob = Replace(replace(@blob,' ,',','),', ',',') 
select @blob = Replace(replace(@blob,' )',')'),'( ','(')
 
--exec sp_msdroptemptable '#cmdout'
--Create Table #cmdout (line nvarchar(max)) 

DECLARE FileSpaceDBCursor CURSOR READ_ONLY FOR 
select name from master.sys.databases where database_id > 4 
and ((isnull(@databaseName,'') = '') OR  (name=@databasename)) 

DECLARE @name nvarchar(300) 
OPEN FileSpaceDBCursor

FETCH NEXT FROM FileSpaceDBCursor INTO @name
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		Begin Try 

			DECLARE @stmt nvarchar(4000) 
			select @stmt = 'SQLCMD -S localhost -d ' + @name + ' -Q "'+@blob+'" -E'
			raiserror(@stmt,0,1) with nowait 

			exec xp_cmdshell @stmt , no_output 
		
		End Try

		Begin Catch

			select @ERM = isnull(@name,'Null @name') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			Raiserror(@ERM,@ERS,1)

		End Catch

	END
	FETCH NEXT FROM FileSpaceDBCursor INTO @name
END

OnErrorExitCursor: 


CLOSE FileSpaceDBCursor
DEALLOCATE FileSpaceDBCursor

select * from (
select xr.Property
, s.n.value('@FREESPACE_MB','DECIMAL(20,2)')  [mbFree]
, s.n.value('@FREESPACE_PERCENT','DECIMAL(20,2)')  [PerCentFree]
, s.n.value('@FILEGROUP_NAME','nvarchar(300)')  [FILEGROUP_NAME]
from ops.dbo.xmlReports xr
  Cross Apply xr.xdata.nodes('/MSSQL/FileData') s(n) 
  where context='FileSpace'
) md 
 where 1=1 
  --and [FILEGROUP_NAME]= 'TRNLOG'
  and [Property]= @Databasename  
order by CASE WHEN [FILEGROUP_NAME]='TRNLOG' then 0 else 1 end 

END
GO


if 1=2
Begin
	exec sp_help_Executesproc 'FileMAnager'

DECLARE @DatabaseName nvarchar(max) = null 
	,@SpaceRequiredMB bigint  = null 
	,@Action varchar(40) = null 
	,@debug int  = null 

SELECT @DatabaseName = 'PerfGate' --nvarchar
	,@SpaceRequiredMB = @SpaceRequiredMB --bigint
	,@Action = @Action --varchar
	,@debug = @debug --int

EXECUTE [dbo].FileManager @DatabaseName = @DatabaseName --nvarchar
	,@SpaceRequiredMB = @SpaceRequiredMB --bigint
	,@Action = @Action --varchar
	,@debug = @debug --int

END 
if 1=2
Begin

select * from (
select xr.Property
, s.n.value('@FREESPACE_MB','DECIMAL(20,2)')  [mbFree]
, s.n.value('@FREESPACE_PERCENT','DECIMAL(20,2)')  [PerCentFree]
, s.n.value('@FILEGROUP_NAME','nvarchar(300)')  [FILEGROUP_NAME]
from ops.dbo.xmlReports xr
  Cross Apply xr.xdata.nodes('/MSSQL/FileData') s(n) 
  where context='FileSpace'
) md 
 where 1=1 
  and [FILEGROUP_NAME]= 'TRNLOG'
  and [Property]= @Databasename  
 END 

GO
