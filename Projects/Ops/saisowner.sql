-- =============================================
-- Declare and using a READ_ONLY cursor
-- =============================================
DECLARE JC CURSOR READ_ONLY FOR  
select 
 j.name [Job] 
from 
  msdb.dbo.sysjobs j
  left outer join master.sys.server_principals p on J.owner_sid = p.principal_id 
where isnull(p.name,'Not SA ') != 'sa'

DECLARE @name nvarchar(400)
OPEN JC

FETCH NEXT FROM JC INTO @name
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
--		PRINT 'add user defined code here'
--		eg.
		DECLARE @message nvarchar(max)
		SELECT @message = 'Assigning SA as owner of Job:' + @name
		Raiserror(@Message,0,1) with nowait 
		EXEC msdb.dbo.sp_update_job @job_name=@name, @owner_login_name=N'sa'

	END
	FETCH NEXT FROM JC INTO @name
END

if @message is null 
Raiserror('All Jobs were found with sa as owner',0,1) with nowait 
CLOSE JC
DEALLOCATE JC
GO

-- =============================================
-- Declare and using a READ_ONLY cursor
-- =============================================
DECLARE JC CURSOR READ_ONLY FOR  
select 
 j.name [Database] 
from 
  master.sys.databases j
  left outer join master.sys.server_principals p on J.owner_sid = p.principal_id 
where isnull(p.name,'Not SA ') != 'sa'

DECLARE @name nvarchar(400)
OPEN JC

FETCH NEXT FROM JC INTO @name
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
--		PRINT 'add user defined code here'
--		eg.
		DECLARE @message nvarchar(max)
		SELECT @message = 'Assigning SA as owner of Database:' + @name
		Raiserror(@Message,0,1) with nowait 
		
		SELECT @Message ='EXEC [' + @Name+ '].dbo.sp_changedbowner @loginame = N''sa'', @map = true'
		Raiserror(@Message,0,1) with nowait 
		EXEC (@Message) 

	END
	FETCH NEXT FROM JC INTO @name
END

if @message is null 
Raiserror('All Databases were found with sa as owner',0,1) with nowait 
CLOSE JC
DEALLOCATE JC
GO

/*
	HADR and Mirror Endpoints also should be tested for Ownership
*/