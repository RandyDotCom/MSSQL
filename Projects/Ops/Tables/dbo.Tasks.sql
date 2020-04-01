USE [Ops]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_Tasks_TaskState]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Tasks] DROP CONSTRAINT [DF_Tasks_TaskState]
END

GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_Tasks_RequestDate]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Tasks] DROP CONSTRAINT [DF_Tasks_RequestDate]
END

GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_Tasks_LoginName]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Tasks] DROP CONSTRAINT [DF_Tasks_LoginName]
END

GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_Tasks_job_id]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Tasks] DROP CONSTRAINT [DF_Tasks_job_id]
END

GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tasks]') AND type in (N'U'))
	DROP TABLE [dbo].[Tasks]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON;SET ANSI_PADDING ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tasks]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[Tasks](
	[idTask] [int] IDENTITY(1,1) NOT NULL,
	[job_id] [uniqueidentifier] NULL,
	[WorkerName] [varchar](max) NULL,
	[step_name] [varchar](50) NULL,
	[commandtype] [varchar](50) NULL,
	[command] [nvarchar](max) NULL,
	[result] [nvarchar](max) NULL,
	[LoginName] [varchar](50) NULL,
	[RequestDate] [datetime] NULL,
	[TaskState] [varchar](50) NULL,
	[spid] [int] NULL,
	[KeyName] [nvarchar](300) NULL,
	[starttime] [datetime] NULL,
	[EndTime] [datetime] NULL,
 CONSTRAINT [PK_Tasks] PRIMARY KEY CLUSTERED 
(
	[idTask] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO

SET ANSI_PADDING OFF
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_Tasks_job_id]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Tasks] ADD  CONSTRAINT [DF_Tasks_job_id]  DEFAULT (newid()) FOR [job_id]
END

GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_Tasks_LoginName]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Tasks] ADD  CONSTRAINT [DF_Tasks_LoginName]  DEFAULT (suser_sname()) FOR [LoginName]
END

GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_Tasks_RequestDate]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Tasks] ADD  CONSTRAINT [DF_Tasks_RequestDate]  DEFAULT (getdate()) FOR [RequestDate]
END

GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_Tasks_TaskState]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[Tasks] ADD  CONSTRAINT [DF_Tasks_TaskState]  DEFAULT ('New') FOR [TaskState]
END

GO


