USE [Ops]
GO
IF  1=2 and EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexDefragObjectsToExclude]') AND type in (N'U'))
	DROP TABLE [dbo].[IndexDefragObjectsToExclude]
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[IndexDefragObjectsToExclude]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[IndexDefragObjectsToExclude](
	[Object_Id] [int] NOT NULL,
	[ObjectName] [varchar](100) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Object_Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO

SET ANSI_PADDING OFF
GO


