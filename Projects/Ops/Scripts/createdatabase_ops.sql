USE [master]
GO
ALTER DATABASE [model] SET RECOVERY SIMPLE WITH NO_WAIT
GO

if not exists(select * from master.sys.databases where name='Ops')
Begin
 Declare @stmt varchar(max), @erm nvarchar(max) , @ers int, @ern int  

 BEGIN TRY

	select @stmt = 'Create Database [Ops]'
	exec(@stmt)

	SELECT @stmt = 'ALTER DATABASE [Ops] SET RECOVERY SIMPLE WITH NO_WAIT' 
	exec(@stmt)

	SELECT @stmt = 'ALTER DATABASE [MODEL] SET RECOVERY SIMPLE WITH NO_WAIT' 
	exec(@stmt)

 END TRY
 BEGIN CATCH
 

   select @ERM = 'Error Number:' + cast(isnull(@ERN,0) as varchar(20)) + char(10) + ERROR_MESSAGE() 
   , @ERS = ERROR_SEVERITY() 

   Raiserror(@ERM,@ERS,1) with nowait

 END CATCH

END
else
begin
	select 'Ops Database Already Exists' as [Ops DB Status]
end

--if 1=2
BEGIN

BEGIN TRY 
  EXEC sp_configure 'show advanced options', 1 
  reconfigure with override 
END TRY
BEGIN CATCH
	Raiserror('show advanced options Failed?',11,1)
	/* Comment out the failing 2 Steps above */
END CATCH
BEGIN TRY

  EXEC sp_configure 'xp_cmdshell', 1 
  reconfigure with override 
END TRY
BEGIN CATCH
	Raiserror('xp_cmdshell Failed?',11,1)
	/* Comment out the failing 2 Steps above */
END CATCH

BEGIN TRY
  EXEC sp_configure 'backup compression default', 1 
  reconfigure with override 
END TRY
BEGIN CATCH
	Raiserror('backup compression default Failed?',11,1)
	/* Comment out the failing 2 Steps above */
END CATCH

Begin TRY 
EXEC sp_configure 'Ad Hoc Distributed Queries', 1;
reconfigure with override ; 
END TRY 
BEGIN CATCH 
	Raiserror('configuire for Ad Hoc Distributed Queries Failed?',11,1)
END CATCH 

END
GO

USE [master]
GO
EXEC xp_instance_regwrite N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'LoginMode', REG_DWORD, 2
GO
ALTER LOGIN [sa] WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF
GO
GRANT CONNECT SQL TO [sa]
GO
ALTER LOGIN [sa] ENABLE
GO

DECLARE @ERM nvarchar(max)
if exists(select * from ops.sys.objects where name='fnSetting')
BEGIN
 begin Try  
	select @ERM = 'OPS Database Build Date:' + ops.dbo.fnSetting('Instance','Ops Build Date') 
	+ char(10) + 'Current Version:' + ops.dbo.fnSetting('Instance','Ops Build Version')
	Raiserror(@ERM,0,1) with nowait 
 End Try
 begin catch
	Select @ERM = 'Server does not even have Settings'
 End Catch
END
ELSE
Begin
	select 'Ops version is Pre Randy, or brand new' as [VersionTestFailed]
END

GO 



/*
	TODO 
	 Configuire Database
	 Document Database Configuire
	 .\Scripts\NewImplementationSteps.sql 

*/

