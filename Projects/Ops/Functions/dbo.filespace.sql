SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER OFF
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[filespace]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[filespace]
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[filespace]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'-- =============================================
-- Author:		Randy
-- Create date: 20160921
-- Description:	ruturns a table of data regarding filespace
-- =============================================
CREATE FUNCTION [dbo].[filespace]()
RETURNS 
@Table_Var TABLE 
(   [Servername] [nvarchar](300) NULL,
	[DatabaseName] [nvarchar](128) NULL,
	[TYPE] [nvarchar](60) NULL,
	[FILE_Name] [nvarchar](300) NOT NULL,
	[FILEGROUP_NAME] [nvarchar](300) NOT NULL,
	[File_Location] [nvarchar](max) NOT NULL,
	[FILESIZE_MB] [decimal](10, 2) NULL,
	[USEDSPACE_MB] [decimal](10, 2) NULL,
	[FREESPACE_MB] [decimal](10, 2) NULL,
	[FREESPACE_PERCENT] [decimal](10, 2) NULL
)
AS
BEGIN
insert into @Table_Var(Servername,DatabaseName,[TYPE],[FILEGROUP_NAME],[FILE_Name],[File_Location],FILESIZE_MB,USEDSPACE_MB,[FREESPACE_MB],[FREESPACE_PERCENT])
SELECT 
    convert(nvarchar(300),serverProperty(''ServerName'')) [Servername]
	, convert(nvarchar(300),db_name()) as [DatabaseName]
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

	
	RETURN 
END
' 
END

GO


