USE [Ops]
GO
SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON
GO
/****** Object:  Table [dbo].[dba_instance_files_log]    Script Date: 9/28/2014 9:24:37 AM ******/
--IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[dba_instance_files_log]') AND type in (N'U'))
--DROP TABLE [dbo].[dba_instance_files_log]
--GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[dba_instance_files_log]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[dba_instance_files_log](
	[idRow] [int] IDENTITY(1,1) NOT NULL,
	[Snapshot] [datetime] NULL,
	[Server] [varchar](400) NULL,
	[dbname] [sysname] NOT NULL,
	[Fileid] [int] NULL,
	[Groupid] [int] NULL,
	[Size] [bigint] NULL,
	[Logicalname] [sysname] NOT NULL,
	[recovery_model] [varchar](30) NOT NULL,
	[PhysicalName] [varchar](max) NULL,
	[TotalExtents] [bigint] NULL,
	[UsedExtents] [bigint] NULL,
 CONSTRAINT [PK_dba_instance_files_log] PRIMARY KEY CLUSTERED 
(
	[idRow] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO



