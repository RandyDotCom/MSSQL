USE [OPS] 
GO

IF  NOT EXISTS (SELECT * FROM sys.types st JOIN sys.schemas ss ON st.schema_id = ss.schema_id WHERE st.name = N'hashvalues' AND ss.name = N'dbo')
BEGIN
EXECUTE ('
CREATE TYPE [dbo].[hashvalues] AS TABLE(
	[vint] [int] NULL,
	[vstr] [nvarchar](max) NULL,
	[vguid] [uniqueidentifier] NULL,
	[vxml] [xml] NULL
)
')

END
GO

IF  NOT EXISTS (SELECT * FROM sys.types st JOIN sys.schemas ss ON st.schema_id = ss.schema_id WHERE st.name = N'FileList' AND ss.name = N'dbo')
BEGIN
EXECUTE ('
CREATE TYPE [dbo].[FileList] AS TABLE(
	[FileDate] [datetime] NULL,
	[FileName] [nvarchar](max) NULL,
	[FullPath] [nvarchar](max) NULL)
')

END
GO

