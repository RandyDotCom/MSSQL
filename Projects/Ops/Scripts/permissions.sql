--execute as user = 'ntdev\swamyn' -- Set this to the user name you wish to check
--execute as user = 'redmond\dongl' -- Set this to the user name you wish to check
--select * from fn_my_permissions(null, 'DATABASE') -- Leave these arguments, don't change to MyDatabaseName
--order by subentity_name, permission_name
--revert


--USE [master]
--GO

--/****** Object:  Login [REDMOND\dongl]    Script Date: 12/1/2014 2:10:28 PM ******/
--IF  EXISTS (SELECT * FROM sys.server_principals WHERE name = N'REDMOND\dongl')
--DROP LOGIN [REDMOND\dongl]
--GO

--/****** Object:  Login [REDMOND\dongl]    Script Date: 12/1/2014 2:10:28 PM ******/
--IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'REDMOND\dongl')
--CREATE LOGIN [REDMOND\dongl] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]
--GO

--[NTDEV\SG_Fungates_DB_RO]
--USE [PerfGate]
--GO
--CREATE USER [REDMOND\dongl] FOR LOGIN [REDMOND\dongl]
--GO
--USE [PerfGate]
--GO
--ALTER ROLE [db_owner] ADD MEMBER [REDMOND\dongl]
--GO
