use ops
go

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'HADRSyncKit' )
   DROP PROCEDURE dbo.HADRSyncKit
GO

-- =============================================
-- Author:		Randy Pitkin
-- Create date: 2016 08 16 
-- Description:	Raises alerts when Jobs and Permissions are not in Sync with members of a HADR Cluster 
-- =============================================
CREATE PROCEDURE dbo.HADRSyncKit 
	@JobName nvarchar(max) = null, 
	@JobState nvarchar(50) = null,
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
SET XACT_ABORT ON
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
DECLARE @RC int 
	
DECLARE @stmt varchar(max)

if @debug is not null 
BEGIN 
	select @STMT = 'This can only be executed effectively from the Primary Node. @Debug Levels can be informative;
	@debug=1 All dynamic SQL is written to the output 
	@debug = 2 Reveals the nodes discovered in temp table #MyHadr 
	@Debug > 2 Will return Missing Objects as REcordsets 
	@Debug must be Null for Windows Events to be created and Alert Monitoring to be tested

	TO Add an Exception to Logins Tested.
	Exec OPS.dbo.Settings_put @context=''HADRSYNCKIT'',@name=''REdmond\v-ranpi'', @value=''Exception''
		
	'

END 
CREATE TABLE #MyHADR (connected_state_desc sysname, replica_server_name sysname, database_name sysname, role_desc sysname,synchronization_health_desc sysname) 
Begin Try 

 SELECT @STMT = '
select 
	ars.connected_state_desc
	, ar.replica_server_name
	, database_name
	, ars.role_desc
	--, rs.last_commit_time
	--, synchronization_state_desc
	, rs.synchronization_health_desc
	--, log_send_queue_size
	--, log_send_rate
	--, redo_queue_size
	--, redo_rate
	--, availability_mode_desc
	--, failover_mode_desc
	--, is_suspended
	--, suspend_reason_desc
	--, is_failover_ready 
	--, is_pending_secondary_suspend
	--, secondary_role_allow_connections_desc
  --into #MyHadr 
from master.sys.dm_hadr_database_replica_states rs
inner join master.sys.availability_replicas ar on rs.replica_id = ar.replica_id
inner join sys.dm_hadr_database_replica_cluster_states dcs on dcs.group_database_id = rs.group_database_id and rs.replica_id = dcs.replica_id
inner join sys.dm_hadr_availability_replica_states ars on ars.replica_id=rs.replica_id
' 
insert into #MyHADR
Exec (@STMT) 


END Try 
Begin Catch 
	SELECT @ERM = ERROR_MESSAGE() , @ERS=ERROR_SEVERITY(), @ERN = ERROR_NUMBER() 
	  Select @ERM = 'Error number: ' + Cast(@ERN as varchar(10)) + char(10) + @ERM 
	  Raiserror(@ERM,11,1) with nowait 
	  Return 0; 
End Catch 

if @debug = 9
BEGIN
  Select * from #MyHadr 
END 




IF NOT EXISTS(select * from #MyHadr)
BEGIN
	if @debug is not null 
		Raiserror('I am not a HADR Implemention, or deployment is not complete',0,1) with nowait 
	
	RETURN 1; 
END

if @debug is not null 
 raiserror('I am a HADR instance',0,1) with nowait 


SELECT @ERM = COALESCE(@ERM + ' ','') + r.database_name + ' ON AG Replica ' + r.replica_server_name + ' is ' + synchronization_health_desc
from 
 #MyHADR r
where r.synchronization_health_desc != 'HEALTHY'

if @ERM is not null 
BEGIN 
  Exec ops.dbo.RaiseAlert @Message=@ERM, @type='Error', @Errorid=6201 
END

  
/* dbaHADRJobManager Job Missing */
if not exists(select * from msdb.dbo.sysjobs where name='dbaHADRJobManager')
	Begin 
		
		select @ERM = 'SQL Agent Job dbaHADRJobManager is missing from this HADR Implementation:' + convert(varchar(max),serverProperty('servername')) 

		EXECUTE [dbo].RaiseAlert @Message = @ERM,@Type = 'ERROR', @ErrorID = 6000,@debug = @debug --int

		Raiserror(@ERM,0,1) 

	END
else 
begin 
	if @debug is not null 
	  raiserror('dbaHADRJobManager is installed',0,1) with nowait 
end

/* Linked Server test */
DECLARE @ServerName nvarchar(300) 

AddLinkedSErver: 
IF Exists (select * from #MyHadr where replica_server_name NOT in (select Name from master.sys.servers ))
BEGIN

	
	select @ERM = null 
	  SELECT @ERM = COALESCE(@ERM+char(10),'') + replica_server_name + ' is missing as a linked server on ' + convert(nvarchar(300),serverproperty('servername')) 
	  from #MyHadr where replica_server_name NOT in (select Name from master.sys.servers )
	  EXECUTE [dbo].RaiseAlert @Message = @ERM,@Type = 'ERROR', @ErrorID = 6001,@debug = @debug --int
	  Raiserror(@ERM,0,1) 

--if 1=2 
BEGIN

	SELECT top 1 @ServerName = replica_server_name from #MyHadr where replica_server_name NOT in (select Name from master.sys.servers )
	  SELECT @ERM = 'Adding '+@ServerName + ' As a linked Server' 
	  if @debug is not null 
			Raiserror(@ERM,0,1) with nowait 

	declare @sapw nvarchar(max) 
	select @sapw = isnull(dbo.fnsetting('Instance','SAPW'),N'1911ForEver')
	/* TODO: Varchar value of the password should be converted to Varbinary or some Encrypted value
		Exec ops.dbo.Settings_put 'INSTANCE','SAPW','1911ForEver' -- To Set the Password 

	 */

	EXEC master.dbo.sp_addlinkedserver @server = @ServerName, @srvproduct=N'SQL Server'

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'collation compatible', @optvalue=N'false'

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'data access', @optvalue=N'true'

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'dist', @optvalue=N'false'

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'pub', @optvalue=N'false'

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'rpc', @optvalue=N'true'

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'rpc out', @optvalue=N'true'

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'sub', @optvalue=N'false'

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'connect timeout', @optvalue=N'0'

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'collation name', @optvalue=null

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'lazy schema validation', @optvalue=N'false'

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'query timeout', @optvalue=N'0'

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'use remote collation', @optvalue=N'true'

	EXEC master.dbo.sp_serveroption @server=@ServerName, @optname=N'remote proc transaction promotion', @optvalue=N'true'

	EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname = @ServerName, @locallogin = NULL , @useself = N'False', @rmtuser = N'sa', @rmtpassword = @sapw

END
	GOTO AddLinkedSErver -- Just in case you added 3 in the last 10 seconds 
	
END -- end of linked partner test 



/* TESTING LOGINS */
BEGIN

Create Table #MissingLogins (MissingFrom nvarchar(300),LoginName nvarchar(300),[FoundOn] nvarchar(max)) 
Create Table #MissingJobs (Servername nvarchar(300),JobName nvarchar(max)) 

DECLARE PartnerCursor CURSOR READ_ONLY FOR 
select distinct convert(varchar(300),replica_server_name) from #MyHadr mh 
 inner join master.sys.servers ss on ss.name = mh.replica_server_name -- cant test if it's not listed 
where convert(varchar(300),replica_server_name) != convert(varchar(300),@@Servername)

DECLARE @replica_server_name nvarchar(max)
OPEN PartnerCursor

FETCH NEXT FROM PartnerCursor INTO @replica_server_name
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		Begin Try 
		  if @debug is not null 
		    Raiserror(@replica_server_name,0,1) with nowait 

		SELECT @stmt = 'select ''' + @replica_server_name + ''', spa.Name,''' + Convert(nvarchar(300),@@ServerNAme) + ''' from [' + @replica_server_name + '].master.sys.server_principals spa where is_disabled=0 and spa.name not in (select name from master.sys.server_principals where is_disabled=0)'
		if @debug=1 Raiserror(@stmt,0,1) with nowait 
		insert into #MissingLogins ([FoundOn], LoginName,MissingFrom)
		Exec (@stmt) 
		
		SELECT @stmt = 'select ''' + Convert(nvarchar(300),@@ServerNAme) + ''', spa.Name,''' + @replica_server_name + '''  from master.sys.server_principals spa where is_disabled=0 and spa.name not in (select name from [' + @replica_server_name + '].master.sys.server_principals where is_disabled=0)'
		if @debug=1 Raiserror(@stmt,0,1) with nowait 	
		insert into #MissingLogins (MissingFrom, LoginName,[FoundOn])
		Exec (@stmt) 


		SELECT @stmt = '
select ''' + @replica_server_name + ''' [ServerName], aj.name + '' IS Missing from '' + @@servername JobName 
from [' + @replica_server_name + '].msdb.dbo.sysjobs aj
   inner join  [' + @replica_server_name + '].msdb.dbo.sysjobsteps ajs on ajs.job_id = aj.job_id
where ajs.database_name in (select database_name from #MyHadr)
  and aj.name not in (select name from msdb.dbo.sysjobs) 
Group by  aj.name' 

		if @debug=1 Raiserror(@stmt,0,1) with nowait 

	insert into #MissingJobs(Servername, JobName)
	EXEC (@STMT) 

			SELECT @stmt = '
select Convert(nvarchar(300),@@Servername) [ServerName] , aj.name + '' :: FOUND ON [' + @replica_server_name + '] is missing'' 
from msdb.dbo.sysjobs aj inner join  msdb.dbo.sysjobsteps ajs on ajs.job_id = aj.job_id
where 1=1 
  and ajs.database_name in (select database_name from #MyHadr)
  and aj.name not in (select name from [' + @replica_server_name + '].msdb.dbo.sysjobs) 
Group by aj.name ' 

		if @debug=1 Raiserror(@stmt,0,1) with nowait 

	insert into #MissingJobs(Servername, JobName)
	EXEC (@STMT) 

				SELECT @stmt = '
select Convert(nvarchar(300),@@Servername) [ServerName] , aj.name + '' :: FOUND ENABLED ON [' + @replica_server_name + ']'' 
from msdb.dbo.sysjobs aj inner join  msdb.dbo.sysjobsteps ajs on ajs.job_id = aj.job_id
where 1=1 
  and ajs.database_name in (select database_name from #MyHadr)
  and aj.name in (select name from [' + @replica_server_name + '].msdb.dbo.sysjobs where enabled=1) 
  and aj.Enabled=0 
Group by aj.name ' 

		if @debug=1 Raiserror(@stmt,0,1) with nowait 

	insert into #MissingJobs(Servername, JobName)
	EXEC (@STMT) 

				SELECT @stmt = '
select Convert(nvarchar(300),@@Servername) [ServerName] , aj.name + '' :: FOUND ENABLED ON [' + @replica_server_name + ']'' 
from msdb.dbo.sysjobs aj inner join  msdb.dbo.sysjobsteps ajs on ajs.job_id = aj.job_id
where 1=1 
  and ajs.database_name in (select database_name from #MyHadr)
  and aj.name in (select name from [' + @replica_server_name + '].msdb.dbo.sysjobs where enabled=0) 
  and aj.Enabled=1 
Group by aj.name ' 

		if @debug=1 Raiserror(@stmt,0,1) with nowait 

	insert into #MissingJobs(Servername, JobName)
	EXEC (@STMT) 

		End Try

		Begin Catch

			select @ERM = isnull(@replica_server_name,'Null @replica_server_name') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			

			Raiserror(@ERM,@ERS,1)

			IF @ERS > 11 Goto OnErrorExitCursor

		End Catch

	END
	FETCH NEXT FROM PartnerCursor INTO @replica_server_name
END

OnErrorExitCursor: 

CLOSE PartnerCursor
DEALLOCATE PartnerCursor

END 

/* REPORTING  */
SELECT @ERM = null 

if 1=2 
 Exec OPS.dbo.Settings_put @context='HADRSYNCKIT',@name='REdmond\v-ranpi', @value='Exception'

delete from #MissingLogins where LoginName in (select Name from ops.dbo.settings where Context='HADRSYNCKIT' and Value='Exception')

IF Exists (Select * from #MissingLogins)
Begin

  Raiserror('Logins are missing',0,1) 

  if @debug =1 
  begin
		SELECT @stmt = char(10) + '/********'

		Select * from #MissingLogins


DECLARE LoginCursor CURSOR READ_ONLY FOR 
Select FoundOn, MissingFrom, LoginName from #MissingLogins order by MissingFrom, LoginName

DECLARE @FoundOn nvarchar(300), @MissingFrom nvarchar(300), @LoginName nvarchar(300) 

OPEN LoginCursor

FETCH NEXT FROM LoginCursor INTO @FoundOn, @MissingFrom, @LoginName 
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

	Declare @current nvarchar(300) 
	IF @current <> @MissingFrom 
	  Begin 
	    select @STMT = 'Missing FROM ' + @MissingFrom 
		Raiserror(@STMT,0,1) 
		SELECT @current = @MissingFrom
	  end 


		SELECT @stmt = 'IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N''@LoginName'')
CREATE LOGIN [@LoginName] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]
GO'
		SELECT @STMT = REPLACE(@STMT,'@LoginName',@LoginName) 

		Raiserror(@STMT,0,1) with nowait 

		


	END
	FETCH NEXT FROM LoginCursor INTO @FoundOn, @MissingFrom, @LoginName 
END

CLOSE LoginCursor
DEALLOCATE LoginCursor



  end 
  else
  Begin 

  
      SELECT @ERM = COALESCE(@ERM+char(10),'') + 'Login ' + isnull(ml.LoginName,'NUll Login Name') + ' is missing from HADR Partner:' + isnull(ml.MissingFrom ,'ml.servername') 
  from #MissingLogins ml
   
  select @ERM = isnull(@ERM,'A Null value was found is SQL Logins through ops..HADRSyncKit') 
  if @Debug is not null 
     Raiserror(@ERM,0,1) 
  else 
    EXECUTE [dbo].RaiseAlert @Message = @ERM,@Type = 'ERROR', @ErrorID = 6002, @debug = @debug --int

  end 


END 

--  Exec OPS.dbo.Settings_put @context='HADRSYNCKIT',@name='dbaIndexOptimize', @value='Exception', @Purge=1 
 delete from #MissingJobs where JobName in (select Name from ops.dbo.settings where Context='HADRSYNCKIT' and Value='Exception')

IF Exists (Select * from #MissingJobs)
Begin
  Raiserror('Jobs are missing',0,1) 

  if @debug = 1
  begin
		Select * from #MissingJobs
  end 
  else
  Begin 

  SELECT @ERM = 'SQLAgent Jobs are Out of Sync'

    SELECT @ERM = COALESCE(@ERM+char(10),'') + isnull(ml.JobName,'NULL ml.JobName')  
  from #MissingJobs ml
   
  
  select @ERM = isnull(@ERM,'A Null value was found in #MissingJobs through ops..HADRSyncKit') 
  
  if @Debug is not null 
     Raiserror(@ERM,1,1) 
  else 
    EXECUTE [dbo].RaiseAlert @Message = @ERM,@Type = 'ERROR', @ErrorID = 6002, @debug = @debug --int

  END 
END 



END
GO


IF 1=2
BEGIN
--	exec sp_help_executesproc @procname='HADRSyncKit'

DECLARE @debug int  = null 

--SELECT @debug = 2 --int

EXECUTE ops.[dbo].HADRSyncKit @debug = @debug --int

END