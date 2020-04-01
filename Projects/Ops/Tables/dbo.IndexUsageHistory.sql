USE [OPS]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[UNUSEDIndexHistory]') AND type in (N'U'))
DROP TABLE [dbo].[UNUSEDIndexHistory]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexUsageHistory]') AND type in (N'U'))
DROP TABLE [dbo].[IndexUsageHistory]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexUsageHistory]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[IndexUsageHistory](
	[rid] [int] IDENTITY(1,1) NOT NULL,
	[CollectionDate] [datetime] NULL,
	[database_name] [varchar](255) NULL,
	[tablename] [sysname] NULL,
	[indexname] [sysname] NULL,
	[user_seeks] [int] NULL,
	[user_scans] [int] NULL,
	[User_lookups] [int] NULL,
	[IndexSizeKB] [int] NULL,
	[IndexSizeMB] [int] NULL,
	[IndexSizeGB] [int] NULL,
 CONSTRAINT [PK_IndexUsageHistory] PRIMARY KEY CLUSTERED 
(
	[rid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO


