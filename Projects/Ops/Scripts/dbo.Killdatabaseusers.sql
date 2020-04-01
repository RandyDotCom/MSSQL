USE [master]
GO

SET ANSI_NULLS ON;SET QUOTED_IDENTIFIER ON
GO


IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[KillDatabaseUsers]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[KillDatabaseUsers]
GO

CREATE PROCEDURE [dbo].[KillDatabaseUsers]
	@dbname nvarchar(255) = null,
	@LoginName nvarchar(255) = null,
	@hostName nvarchar(255) = null, 
	@useSingle bit = null, 
	@debug int = null 
as
BEGIN

  if @dbname is null and @LoginName is null and @hostName is null 
  BEGIN
	Raiserror('One of either @dbname, @loginName or @hostName is required',11,1)
	Return 0; 
  END

Declare 
		@dbid int,
		@spid int,
		@user nvarchar(255),
		@host nvarchar(255),
		@str nvarchar(max)

  
if isnull(@useSingle,0) <> 0
BEGIN

	if exists(select * from master.sys.databases where name=@dbname and is_in_standby=0 and state_desc='ONLINE')	
	BEGIN

		SELECT @str = 'ALTER DATABASE [' + @dbname + '] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE'
			Raiserror(@str,0,1) with nowait
		EXEC (@str)
	
		SELECT @str = 'ALTER DATABASE [' + @dbname + '] SET  MULTI_USER WITH ROLLBACK IMMEDIATE '
			Raiserror(@str,0,1) with nowait
			EXEC (@str)
		Return 1; 
	END
END

		
select @dbid = dbid from master..sysdatabases
  where name = @dbname
  
    SET @spid = @@SPID 
    
DECLARE spidcurs cursor for
   select spid, rtrim(Loginame), rtrim(hostname) from 
   master..sysprocesses 
   where 1=1
     and SPID != @spid
	 and isnull(loginame,'sa') != 'sa' 
     and ((@dbname is null) OR (dbid = @dbid)) 
	 and ((isnull(@LoginName,'') = '') OR ([loginame] like '%' + @LoginName + '%'))
	 and ((isnull(@hostName,'') = '') OR ([hostname] = @hostname))
 
    
open spidcurs
fetch next from spidcurs into @spid, @user, @host 
While @@fetch_status = 0
  Begin
  
	   Select @str = 'Kill '+convert(nvarchar(30),@spid) + '  -- ' + @user + ' from ' + @host + ' on '
		Raiserror(@str,0,1) with nowait  
		if isnull(@debug,0) <= 1
		exec(@str)
    
    fetch next from spidcurs into @spid, @user, @host
End
Deallocate spidcurs

END
GO


IF 1=2
BEGIN

DECLARE @dbname sysname  = null 
	,@LoginName sysname  = null 
	,@useSingle bit  = null 
	,@debug int  = null 

SELECT @dbname = @dbname --sysname
	,@LoginName = @LoginName --sysname
	,@useSingle = @useSingle --bit
	,@debug = @debug --int

EXECUTE [dbo].KillDatabaseUsers @dbname = @dbname --sysname
	,@LoginName = 'v-ranpi' --sysname
	,@useSingle = @useSingle --bit
	,@debug = @debug --int

END