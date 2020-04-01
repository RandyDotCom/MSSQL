DECLARE dbcur CURSOR READ_ONLY FOR 
select 
 Databasename , HARole 
from 
  Ops.dbo.Database_status_v

DECLARE @name nvarchar(max), @ERM nvarchar(max) , @ERS int, @harole nvarchar(50) 
OPEN dbcur

FETCH NEXT FROM dbcur INTO @name, @harole
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		Begin Try 

			if @harole is Null 
			 exec ops.dbo.Settings_put @Context='Instance', @name=@Name, @value=Null, @purge=1 
			else 
			Begin
			/* for support of a Secondary used for backups */
				if 1=2 
					exec ops.dbo.Settings_put @Context='Instance', @name=@Name, @value='DoNotBackup' 
				else 
					exec ops.dbo.Settings_put @Context='Instance', @name=@Name, @value='Backup'
			 END 
		End Try

		Begin Catch

			select @ERM = isnull(@name,'Null @name') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			

			Raiserror(@ERM,@ERS,1)

			IF @ERS > 11 Goto OnErrorExitCursor

		End Catch

	END
	FETCH NEXT FROM dbcur INTO @name, @harole
END

OnErrorExitCursor: 


CLOSE dbcur
DEALLOCATE dbcur
GO

Select * from ops.dbo.Settings where Context='Instance'

