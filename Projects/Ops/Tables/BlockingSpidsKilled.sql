USE [OPS]
GO

IF 1=2 and EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BlockingSpidsKilled]') AND type in (N'U'))
	DROP TABLE [dbo].[BlockingSpidsKilled]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[BlockingSpidsKilled]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[BlockingSpidsKilled](
	[kill_date] [datetime] NULL,
	[spid] [smallint] NULL,
	[db_name] [sysname] NULL,
	[login_name] [sysname] NULL,
	[host_name] [sysname] NULL,
	[program_name] [sysname] NULL,
	[sql_text] [nvarchar](max) NULL,
	[direct_blocks] [smallint] NULL,
	[total_blocks] [smallint] NULL,
	[cpu_time] [int] NULL,
	[login_time] [datetime] NULL,
	[last_request_start_time] [datetime] NULL,
	[last_request_end_time] [datetime] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO


Truncate table [OPS].[dbo].[BlockingSpidsKilled] 