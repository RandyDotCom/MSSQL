USE [master]
GO
SET NOCOUNT on; 

if exists(select * from master.sys.databases where charindex('[',name) != 0)
BEGIN
 raiserror('Invalid Character in Databasename',0,1) 
 GOTO ExitScript 
end 

Exec sp_MSdroptemptable '#MyResults' 

Create Table #MyResults (dbname sysname,RoleName sysname ,isBrokerEnabled bit)  

DECLARE @stmt varchar(max)

DECLARE wttdbc CURSOR READ_ONLY FOR 
select name, is_broker_enabled, recovery_model_desc from master.sys.databases 
	where name not in ('Ops','SSISDB') and database_id > 4  
	and state_desc='ONLINE'
	and name not in (select DatabaseName from ops.[dbo].[Database_status_v] where isnull(HARole,'PRIMARY') != 'PRIMARY')

DECLARE @dbname  nvarchar(max), @ERM nvarchar(max) , @ERS int
, @isBrokerEnabled bit, @RecoveryModel  nvarchar(300) 

OPEN wttdbc

FETCH NEXT FROM wttdbc INTO @dbname, @isBrokerEnabled, @RecoveryModel  
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		Begin Try 

		Raiserror(@dbname,0,1) with nowait 

		

		  SELECT @stmt = 'SELECT Name,''[' + @dbname + ']'',' + Cast(@isBrokerEnabled as varchar(100)) + ' FROM [' + @dbname + '].sys.database_principals WHERE name like N''wtt_%'' AND type = ''R'''

		  select @stmt = isnull(@stmt,'NULL')
		  
		  print @stmt  

		  if @stmt is null 
		    begin 
				select @ERM = '@dbname created a null condition'
				raiserror(@ERM,11,1) with nowait 
			end 

		  Raiserror(@STMT,0,1) with nowait 
		  
		  insert into #MyResults(RoleName,dbname,isBrokerEnabled)
		  EXEC (@stmt) 
		  

		End Try

		Begin Catch
			select @ERM = isnull(@dbname ,'Null @dbname ') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			

			Raiserror(@ERM,@ERS,1)

			IF @ERS > 11 Goto OnErrorExitCursor

		End Catch

	END
	FETCH NEXT FROM wttdbc INTO @dbname, @isBrokerEnabled, @RecoveryModel  
END

OnErrorExitCursor: 


CLOSE wttdbc
DEALLOCATE wttdbc

if exists(SELECT * FROM #MyResults where isBrokerEnabled=0) 
BEGIN
  SELECT @ERM = 'Broker is not enabled on '
  SELECT @ERM = COALESCE(@ERM,'') + dbname 
	from (  SELECT DISTINCT dbname from #MyResults   where isBrokerEnabled=0 ) md 

  Raiserror(@ERM,0,1) with nowait 

END 
ExitScript: 
GO
