USE [master]
GO

--IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'REDMOND\osgtadm')
--BEGIN
--	CREATE LOGIN [REDMOND\osgtadm] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]
--END 
--GO

----EXEC master..sp_addsrvrolemember @loginame = N'REDMOND\osgtadm', @rolename = N'sysadmin'
----GO


