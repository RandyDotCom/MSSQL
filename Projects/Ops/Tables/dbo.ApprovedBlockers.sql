USE [Ops]
GO

--IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ApprovedBlockers]') AND type in (N'U'))
--	DROP TABLE [dbo].[ApprovedBlockers]
--GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ApprovedBlockers]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[ApprovedBlockers](
	[LoginPattern] [nvarchar](300) NOT NULL,
 CONSTRAINT [PK_ApprovedBlockers] PRIMARY KEY CLUSTERED 
(
	[LoginPattern] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO


declare @valueTest nvarchar(300) 
SET @valueTest = '%' + convert(nvarchar(300),serverproperty('machinename'))+'$'
if not exists(select 1 from [dbo].[ApprovedBlockers] where [LoginPattern] =  @valueTest)
Begin 
	insert into dbo.ApprovedBlockers(LoginPattern) values (@valueTest )
end 

SET @valueTest = 'NT AUTHORITY\SYSTEM'
if not exists(select 1 from [dbo].[ApprovedBlockers] where [LoginPattern] =  @valueTest)
Begin 
	insert into dbo.ApprovedBlockers(LoginPattern) values (@valueTest )
end 

SET @valueTest = ''
if not exists(select 1 from [dbo].[ApprovedBlockers] where [LoginPattern] =  @valueTest)
Begin 
	insert into dbo.ApprovedBlockers(LoginPattern) values (@valueTest )
end 

SET @valueTest = 'sa'
if not exists(select 1 from [dbo].[ApprovedBlockers] where [LoginPattern] =  @valueTest)
Begin 
	insert into dbo.ApprovedBlockers(LoginPattern) values (@valueTest )
end 

--declare @verbose varchar(100) = '$(verbose)' 

--if @verbose = 'true'
--select * from ops.dbo.ApprovedBlockers