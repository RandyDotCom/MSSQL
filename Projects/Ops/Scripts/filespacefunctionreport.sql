
DECLARE @stmt varchar(max)

DECLARE FileSpaceDBCursor CURSOR READ_ONLY FOR 
select Databasename from ops.dbo.Database_status_v where is_in_standby=0 and state_desc='ONLINE' and isnull(harole,'PRIMARY')='PRIMARY'

DECLARE @name nvarchar(max), @ERM nvarchar(max) , @ERS int
OPEN FileSpaceDBCursor

FETCH NEXT FROM FileSpaceDBCursor INTO @name
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN
		SELECT @stmt = Coalesce(@STMT + char(10) + 'UNION'+char(10),'') +  'select * from [' + @name + '].[dbo].[filespace]()'
	END
	FETCH NEXT FROM FileSpaceDBCursor INTO @name
END

OnErrorExitCursor: 


CLOSE FileSpaceDBCursor
DEALLOCATE FileSpaceDBCursor

Raiserror(@STMT,0,1) 
Exec (@STMT)


GO

