USE [Ops]
GO
--declare @verbose varchar(50)='$(verbose)' 

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CancelledQueries]') AND type in (N'U'))
BEGIN
	if not exists (select 1 from sys.columns where name='HostName' and [OBJECT_ID] = object_id('CancelledQueries'))
	Begin
		--if @verbose = 'true' 
		Raiserror('Adding Column [hostname] to [CancelledQueries]',0,1) with nowait 

		alter table [CancelledQueries] add [hostname] sysname 
	end 
END
/****** Object:  Table [dbo].[CancelledQueries]    Script Date: 5/25/2016 9:07:17 AM ******/
SET ANSI_NULLS ON ; SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CancelledQueries]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[CancelledQueries](
	[CancelledTime] [datetime] NOT NULL,
	[SessionId] [smallint] NOT NULL,
	[DatabaseName] [sysname] NOT NULL,
	[LoginName] [sysname] NOT NULL,
	[HostName] [Sysname] null, 
	[SqlText] [nvarchar](max) NULL,
	[CpuTime] [int] NULL,
	[QueryElapsedTimeInMs] [int] NOT NULL,
 CONSTRAINT [PK_CancelledQueries] PRIMARY KEY CLUSTERED 
(
	[CancelledTime] ASC,
	[LoginName] ASC,
	[SessionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END
GO


