USE [Ops]
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON
GO


IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BackupFiles_Retention]') AND type in (N'U'))
BEGIN
	if not exists (select * from sys.columns where [object_id]=object_id('BackupFiles_Retention') and name='RetentionPath')
	BEGIN
	select * 
	into #Temp1 
	from [BackupFiles_Retention]

	DROP TABLE [dbo].[BackupFiles_Retention]
	END
END
GO



IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BackupFiles_Retention]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[BackupFiles_Retention](
	[DRID] [int] IDENTITY(1,1) NOT NULL,
	[ServerName] [nvarchar](300) NOT NULL,
	[DatabaseName] [nvarchar](300) NOT NULL,
	[RetentionType] [varchar](50) NULL,
	[RetentionDays] [int] NULL,
	[RetentionPath] [varchar](max) NULL,
 CONSTRAINT [PK_BackupFiles_Retention] PRIMARY KEY CLUSTERED 
(
	[DRID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO

SET ANSI_PADDING OFF
GO

if object_id('tempdb..#temp1') is not null 
BEGIN

	INSERT INTO [dbo].[BackupFiles_Retention]
			   ([ServerName]
			   ,[DatabaseName]
			   ,[RetentionType]
			   ,[RetentionDays])
	SELECT [ServerName]
			   ,[DatabaseName]
			   ,[RetentionType]
			   ,[RetentionDays]
	FROM #Temp1
END
GO

if 1=2 
select * from [BackupFiles_Retention]

