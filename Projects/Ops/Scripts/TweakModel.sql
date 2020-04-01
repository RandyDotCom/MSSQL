USE [master]
GO
Begin Try 
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modeldev', SIZE = 8000KB , FILEGROWTH = 1024000KB )
ALTER DATABASE [model] MODIFY FILE ( NAME = N'modellog', SIZE = 8000KB , FILEGROWTH = 1024000KB )
End try 
Begin Catch 
	Declare @ERM nvarchar(max)
	select @ERM = 'Update to Model Failed with error:'+char(10) + ERROR_MESSAGE()
	Print @ERM 
end Catch 
GO
