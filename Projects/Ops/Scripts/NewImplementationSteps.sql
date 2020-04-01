USE OPS
GO 
SET NOCOUNT ON; 

DECLARE @ERM nvarchar(max) 


Select @ERM= null 

Begin Try 
	exec Ops.Dbo.InstanceReport 

End Try 
Begin Catch
	select @ERM = Coalesce(@ERM+char(10),'') + ERROR_MESSAGE()
end Catch



SELECT @ERM = Coalesce(@ERM+char(10),'') + Name + ' is omited from backups and is in Full Recovery'
from master.sys.databases where 1=1 
 and recovery_model_desc='FULL'
 and Name in (select [value] from ops.dbo.settings where Context='Instance' and [Name]='DoNotBackup')


if @ERM is not null 
	Begin 
		select @ERM = Coalesce(@ERM+char(10),'') + 'Implementation Steps may be Required' 
		SELECT @ERM as [Message]
		--Raiserror(@ERM,11,1) with nowait 
	end 

select 'Instance Setting ' + Name + ':' + Value from Ops.dbo.Settings where context='Instance' 


if 1=2 
BEGIN

	EXECUTE Ops.[dbo].InstanceReport @debug = 1 --int
	select * from Ops.dbo.Settings 

END

IF 1=2
BEGIN
	/* Instance Configuiration Tweaks */

	/* Determines how many days to keep backups */
		select * From Ops.dbo.BackupFiles_Retention
		/* Shorten or Lengthen the Period to one day for the local server */
	update Ops.dbo.BackupFiles_Retention Set RetentionDays=2
	 where ServerName != convert(varchar(max),serverproperty('Servername'))

	 /* Disable backups on this server for this Database */
	exec Ops.dbo.Settings_put 'Instance', 'PerfGate', 'DoNotBackup'

	 /* Disable backups on this server for All Database(s), unless they are in Full Recovery */

	insert into Settings(Context,Name,Value)
	select 'Instance',name,'DoNotBackup' from master.sys.databases 
	 where database_id > 4 and name !='Ops' And recovery_model_desc != 'Full' 


END

/* Preserving Registry entrys in a common table */ 
EXECUTE [dbo].SettingsRegRead  
Go

USE [master]
GO
--EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', REG_SZ, N'D:\MSSQL12.MSSQLSERVER\MSSQL\Backup2'
--GO

declare @reg table (Data nvarchar(max),value nvarchar(max))
declare @ERM nvarchar(max), @ERN int, @ERS int, @stmt nvarchar(max)  

insert into @reg(Data,Value)
exec xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory'


insert into @reg(Data,Value)
exec xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData'

if not exists(select * from @reg where Data='DefaultData')
Begin
	Raiserror('Default Data Location not found',0,1) 
	select @ERM = Filename from sysfiles where filename like '%.mdf' 
	select @ERM = left(@ERM,len(@ERM)-charindex('\',reverse(@ERM)))+'\'
	
	Select @stmt = 'xp_instance_regwrite N''HKEY_LOCAL_MACHINE'', N''Software\Microsoft\MSSQLServer\MSSQLServer'', N''DefaultData'', REG_SZ, N''' + @ERM + ''''
	Raiserror(@STMT,0,1) with nowait 
	exec(@stmt)
--	EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultData', REG_SZ, @ERM

end 

insert into @reg(Data,Value)
exec xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'DefaultLog'


if not exists(select * from @reg where Data='DefaultLog')
Begin
	Raiserror('Default Log Location not found',0,1) 
	select @ERM = Filename from sysfiles where filename like '%.ldf' 
	select @ERM = left(@ERM,len(@ERM)-charindex('\',reverse(@ERM)))+'\'
	
	Select @stmt = 'xp_instance_regwrite N''HKEY_LOCAL_MACHINE'', N''Software\Microsoft\MSSQLServer\MSSQLServer'', N''DefaultLog'', REG_SZ, N''' + @ERM + ''''
	Raiserror(@STMT,0,1) with nowait 
	exec(@stmt)


end 

select @ERM = null 
SELECT @ERM = COALESCE(@ERM + char(10),'') + Physical_name from master.sys.master_files where physical_name like 'C%'

 if len(isnull(@ERM,'')) > 1 
  Begin
	select @ERM = 'There are DB Files on C$' + char(10) + @ERM 
	Raiserror(@ERM,0,1) with nowait 
  end 

select @ERM = null 
-- DECLARE @ERM nvarchar(max)
SELECT 
	--@ERM = Coalesce(@ERM+char(10),'') + convert(nvarchar(50),NAme) + ':' + convert(nvarchar(50),Value) 
	*
 from sys.configurations 
where 1=1 
 and name = 'max worker threads' and convert(varchar(50),[value]) != '8'
 and name = 'show advanced options' and convert(varchar(50),[value]) = '1'

 /* select * from Sys.configurations */
 if len(isnull(@ERM,'')) > 1 
  Begin
	select @ERM = 'There are Configuiration Issues ' + char(10) + @ERM 
	Raiserror(@ERM,0,1) with nowait 
  end 


select @ERM = 'Important Instance Settings are;' + char(10)  
SELECT @ERM = COalesce(@ERM+char(10),'') +  'Exec Ops.dbo.Settings_put @Context=''' + Context +''', @Name=''' +Name + ''', @Value=''' + Value + '''' 
from ops.dbo.Settings where Context ='Instance' 
Raiserror(@ERM,0,1) with nowait 

