USE [OPS]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[InstanceReport]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[InstanceReport]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[InstanceReport]') AND type in (N'P', N'PC'))
	EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[InstanceReport] AS' 
GO

ALTER proc [dbo].[InstanceReport]  
   @output varchar(max) = null output
 , @debug int = null 
AS 
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERN int , @ERS int 

if @debug is not null 
  print '@Debug=2 : for Full Configuiration '

if not exists(select * from dbo.Settings where name='backup compression default' and Value='1')
BEGIN
	EXEC sp_configure 'backup compression default', 1 
	reconfigure with override 
END

if not exists(select * from dbo.Settings where name='show advanced options' and Value='1')
BEGIN
	EXEC sp_configure 'show advanced options', 1 
	reconfigure with override 
END

if not exists(select * from dbo.Settings where name='xp_cmdshell' and Value='1')
BEGIN
	EXEC sp_configure 'xp_cmdshell', 1 
	reconfigure with override 
END

/*Allways reset the default BackupDirectory or Warn */ 
Begin
declare @regread table ([Value] sysname, [Data] sysname) 
Declare @RegKeys Table (KeyName nvarchar(max)) 
declare @RootPath nvarchar(max),@KeyPath Nvarchar(400)  
 select @KeyPath = ops.dbo.fnSetting('Instance','RegRoot') 

IF @KeyPath is not null 
 insert into @RegKeys(KeyName)
 Values (@KeyPath) 

 /*Keys I have found */

 insert into @RegKeys(KeyName)
 Values (N'Software\Microsoft\MSSQLServer\MSSQLServer') 

 insert into @RegKeys(KeyName)
 Values (N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQLServer') 
 
KeyTest: 

DECLARE RegKeyCursor CURSOR READ_ONLY FOR 
Select KEyName from @regKeys

DECLARE @name nvarchar(max) 
OPEN RegKeyCursor

FETCH NEXT FROM RegKeyCursor INTO @KeyPath
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		Begin Try 

		if @debug > 0 raiserror(@KEyPath,0,1) with nowait 

			insert into @regread
			EXEC  master.dbo.xp_instance_regread  
			 N'HKEY_LOCAL_MACHINE', @KeyPath,N'BackupDirectory' 
		
			select @Rootpath = [Data] from @regread 

		if @RootPath is not null 
		BEGIN
			if @debug > 0 raiserror(@Rootpath,0,1) with nowait 
			exec Ops.dbo.Settings_put @context='Instance', @Name='BackupDirectory', @value=@Rootpath
			exec Ops.dbo.Settings_put @context='Instance', @Name='RegRoot', @value=@KeyPath
			goto ExitCursor 
		END 
		
		End Try

		Begin Catch

			select @ERM = isnull(@KeyPath,'Null @name') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			

			Raiserror(@ERM,@ERS,1)

			IF @ERS > 11 Goto OnErrorExitCursor

		End Catch

	END
	FETCH NEXT FROM RegKeyCursor INTO @KeyPath
END

OnErrorExitCursor: 

	if @RootPath is null 
	Begin
		select @erm = 'dbo.InstanceReport was not able to locate the regKey for the backup directory.' + char(10) +
		'Last Key checked was ' + @KeyPath  
		Raiserror(@ERM,11,1) with nowait   
	end
ExitCursor:

CLOSE RegKeyCursor
DEALLOCATE RegKeyCursor

 		 
END

Declare @report xml, @node xml  

select @report = ( 
select * from (
select SERVERPROPERTY('MachineName') [MachineName]
	,@@version [Version] ) meta 
for xml auto, root('Report')
) 


declare @drives table (drive varchar(2), mbfree int) 
insert into @drives 
exec master.sys.xp_fixeddrives


select @node = (select * from @drives [drives] for xml auto, root('disk')) 
set @report.modify('insert sql:variable("@node") as last into (/Report)[1]') 

declare @databases table (DatabaseName varchar(255), [compat] tinyint, state_desc varchar(20), model varchar(20), harole varchar(20), Filepath varchar(max), Filesize int)

insert into @databases 
select 
 md.[DatabaseName] as [DatabaseName]
 , md.compatibility_level 
 , md.state_desc 
 , md.recovery_model_desc 
 , md.HARole
 , mdf.physical_name
 , mdf.size
FROM
	ops.dbo.Database_status_v md
   inner join master.sys.master_files mdf on mdf.database_id = md.database_id
WHERE 1=1 
   and [DatabaseName] not in ('tempdb','model')


select @node = (select [Setting].context , Keyname.name, KeyValue.value
 from (Select distinct context from dbo.[Settings]) [Setting]
   left outer join (select context, name from dbo.settings group by context, name) Keyname on Keyname.Context = [Setting].Context 
   left outer join (select context, name, value from dbo.Settings) KeyValue on KeyValue.Context= [Setting].Context and KeyValue.Name = Keyname.Name 
for xml auto, root('Ops') )

set @report.modify('insert sql:variable("@node") as last into (/Report)[1]') 

select @node = (select * from @databases [databasefiles] for xml auto, root('Databases'))
set @report.modify('insert sql:variable("@node") as last into (/Report)[1]') 
--select @report 


if object_id('tempdb..#Configuiration') is not null 
  drop table #Configuiration

  create Table #Configuiration (name varchar(max),minimum bigint, maximum bigint, config_value bigint, run_value bigint)

  insert into #Configuiration([name],[minimum],[maximum],[config_value],[run_value]) 
  Exec sp_configure 

if @debug= 2 
  select * from #Configuiration

  delete from dbo.Settings where Context='sp_configure' or Context='sp_configuire' --My Bad

INSERT INTO [dbo].[Settings]
           ([Context]
           ,[Name]
           ,[Value])
SELECT 'sp_configure', name, cast(run_value as varchar(100)) 
FROM #Configuiration
  where name in ('xp_cmdshell','max server memory (MB)','Database Mail XPs','backup compression default','show advanced options')

select @node = (
select * from #Configuiration Config 
for xml auto, root('sp_configuire')
) 

set @report.modify('insert sql:variable("@node") as last into (/Report)[1]') 


if exists (select 1 from #Configuiration where [name]='Database Mail XPs' and (config_value=1 or run_value=1))
BEGIN

/* Database Mail Audit */
declare @MyMailers Table ([account_id] [int],[name] [nvarchar](max),[description] [nvarchar](max),[email_address] [nvarchar](max),[display_name] [nvarchar](max),[replyto_address] [nvarchar](max),[servertype] [nvarchar](max),[servername] [nvarchar](max),[port] [int],[username] [nvarchar](max),[use_default_credentials] [bit],[enable_ssl] [bit])

insert into @MyMailers ([account_id],[name],[description],[email_address],[display_name],[replyto_address],[servertype],[servername],[port],[username],[use_default_credentials],[enable_ssl])
exec msdb.dbo.sysmail_help_account_sp

select @node = (
select * from @MyMailers [profile] for xml auto, root('databasemail')) 

set @report.modify('insert sql:variable("@node") as last into (/Report)[1]') 

select @node = (
SELECT top 10 
 event_type
 , log_date 
 , Convert(xml,description) [Desc]
 FROM MSDB..sysmail_event_log [Maillog]
WHERE event_type != 'iNFORMATION'
and log_date > dateadd(day,-7,getdate())
for xml  auto, root('dbmailerrors')

)
if @node is not null 
Begin 
	set @report.modify('insert sql:variable("@node") as last into (/Report)[1]') 
end 

END 

/* POST REPORT */

if @report is not null 
BEGIN
	exec dbo.xmlReports_put @property='Instance', @context='Report', @xdata=@report 
END 

	SELECT @output = Convert(varchar(max),@report ) 
	--Select @output 




if @debug is not null 
BEGIN 
if exists(select * from #Configuiration where name='max server memory (MB)' and config_value=maximum) 
  raiserror('Server Memory is not configured',11,1) with nowait

  if exists(select * from @databases where DatabaseName in ('master','model','msdb','tempdb','ops') and model != 'Simple') 
  raiserror('System databases are missconfigured',0,1) with nowait

if exists(select * from #Configuiration where name='Database Mail XPs' and config_value=0) 
  raiserror('Database mail is not enabled',0,1) with nowait

END 

END 
GO


if 1=2 
BEGIN
DECLARE @output varchar(max) = null 
	,@debug int  = null 

SELECT @output = 'XML'  --varchar
	,@debug = @debug --int

EXECUTE [dbo].InstanceReport @output = @output OUTPUT  --varchar
	,@debug = @debug --int

select * from ops.dbo.xmlReports where context = 'Report'
--select @output as [output variable] 
END


-- exec ops.dbo.sp_help_executesproc 'InstanceReport'