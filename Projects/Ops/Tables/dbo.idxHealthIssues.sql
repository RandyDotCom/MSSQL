USE [OPS]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[idxHealthIssues]') AND type in (N'U'))
  if not exists (select 1 from [dbo].[idxHealthIssues])
		DROP TABLE [dbo].[idxHealthIssues]
GO

SET ANSI_NULLS ON ; SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[idxHealthIssues]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[idxHealthIssues](
	[idrow] [int] IDENTITY(1,1) NOT NULL,
	[databasename] [nvarchar](300) NULL,
	[localschema] [nvarchar](10) NULL,
	[tablename] [nvarchar](300) NULL,
	[indexname] [nvarchar](300) NULL,
	[idxhealthstatus] [varchar](50) NULL,
 CONSTRAINT [PK_idxHealthIssues] PRIMARY KEY CLUSTERED 
(
	[idrow] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY]
END
GO

SET ANSI_PADDING OFF
GO


