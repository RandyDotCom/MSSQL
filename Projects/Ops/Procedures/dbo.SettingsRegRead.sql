USE Ops
go

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'SettingsRegRead' )
   DROP PROCEDURE dbo.SettingsRegRead
GO

-- =============================================
-- Author:		Randy
-- Create date: 20150521
-- Description:	updates the Settings table from the Registry, The Registry is King
-- =============================================
CREATE PROCEDURE dbo.SettingsRegRead 
	@Context nvarchar(255) = null, 
	@Name nvarchar(255) = null  ,
	@value nvarchar(255) = null,
	@putdata bit = null, -- Future use 
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
declare @regread table ([Value] sysname, [Data] sysname) 

		insert into @regread
			EXEC  master.dbo.xp_instance_regread  N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory' 

		insert into @regread
			EXEC  master.dbo.xp_instance_regread  N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData' 

		insert into @regread
			EXEC  master.dbo.xp_instance_regread  N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog' 

delete from ops.dbo.Settings where Context='Instance' and Name in ('BackupDirectory','DefaultData','DefaultLog')		

insert into ops.dbo.Settings(Context,name,value)
select 'Instance',Value,Data from @regread 

END
GO


IF 1=2
BEGIN
	exec sp_help_executesproc @procname='SettingsRegRead', @schema='dbo'

DECLARE @Context nvarchar(max) = null 
	,@Name nvarchar(max) = null 
	,@value nvarchar(max) = null 
	,@putdata bit  = null 
	,@debug int  = null 

SELECT @Context = @Context --nvarchar
	,@Name = @Name --nvarchar
	,@value = @value --nvarchar
	,@putdata = @putdata --bit
	,@debug = @debug --int

EXECUTE [dbo].SettingsRegRead @Context = @Context --nvarchar
	,@Name = @Name --nvarchar
	,@value = @value --nvarchar
	,@putdata = @putdata --bit
	,@debug = @debug --int


END