USE [OPS]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexUsageHistoryStage]') AND type in (N'U'))
	DROP TABLE [dbo].[IndexUsageHistoryStage]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexUsageHistoryStage]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[IndexUsageHistoryStage](
	[CollectionDate] [datetime] NULL,
	[database_name] [varchar](255) NULL,
	[object_id] [int] NULL,
	[tablename] nvarchar(300) NULL,
	[indexname] nvarchar(300) NULL,
	[user_seeks] [int] NULL,
	[user_scans] [int] NULL,
	[User_lookups] [int] NULL
) ON [PRIMARY]
END
GO

SET ANSI_PADDING OFF
GO


