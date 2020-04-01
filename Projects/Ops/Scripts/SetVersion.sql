use ops
go

Declare @BuildDate varchar(100) , @debug int 

select @builddate=convert(varchar(100),getdate(),0)

exec dbo.Settings_put @Context='Instance', @Name='Ops Build Date', @value=@builddate  

exec dbo.Settings_put @Context='Instance', @Name='Ops Build Version', @value='GOLD 2.5.1'

select @@SERVERNAME [ServerName], 'Ops Build Version:' + ops.dbo.fnSetting('Instance','Ops Build Version')


--Exec ops.dbo.BackupFiles_Report @includeSystems=1
--SELECT ops.dbo.fnSetting('Instance','Ops Build Version') [Ops Version]

