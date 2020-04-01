USE [Ops]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[idxHealth]') AND type in (N'U')) 
	DROP TABLE [dbo].[idxHealth]
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[idxHealth]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[idxHealth](
	[idRow] [int] IDENTITY(1,1) NOT NULL,
	[ServerName] nvarchar(128) NOT NULL,
	[DatabaseName] nvarchar(128) NOT NULL,
	[collected] [datetime] NOT NULL,
	[schema] nvarchar(128) NOT NULL,
	[TableName] nvarchar(128) NOT NULL,
	[IndexName] nvarchar(128) NOT NULL,
	[StatsDate] datetime NULL,
	[type_desc] [varchar](50) NULL,
	[partition_number] [smallint] NULL,
	[index_depth] [tinyint] NULL,
	[index_type_desc] [varchar](20) NULL,
	[avg_fragmentation_in_percent] [float] NULL,
	[fragment_count] [int] NULL,
	[page_count] [int] NULL,
	[record_count] [bigint] NULL,
	[alloc_unit_type_desc] varchar(20) null,
	[Status] [varchar](50) NULL,
	[Action] [varchar](max) NULL,
	[spid] int Null,
 CONSTRAINT [PK_idxHealth] PRIMARY KEY CLUSTERED 
(
	[idRow] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO

SET ANSI_PADDING OFF
GO

IF NOT EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[DF_idxHealth_collected]') AND type = 'D')
BEGIN
	ALTER TABLE [dbo].[idxHealth] ADD  CONSTRAINT [DF_idxHealth_collected]  DEFAULT (getdate()) FOR [collected]
END

GO

--ALTER TABLE [dbo].[idxHealth] ADD [alloc_unit_type_desc] varchar(20)

--select * FROM Dbo.idxHealth