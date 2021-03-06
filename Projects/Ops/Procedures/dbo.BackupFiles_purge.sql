use ops
go

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'BackupFiles_purge' )
   DROP PROCEDURE dbo.BackupFiles_purge
GO

-- =============================================
-- Author:		Randy
-- Create date: 200160304
-- Description:	Deletes Backup files
-- =============================================
CREATE PROCEDURE dbo.BackupFiles_purge 
	@ServerName nvarchar(300) = null, 
	@DatabaseName nvarchar(300) = null  ,
	@dir nvarchar(400) = null , 
	@doSource bit = null,
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
SET XACT_ABORT ON;
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
declare @cmd nvarchar(4000), @rc int 
DECLARE @CMDOUT TABLE (LINE NVARCHAR(MAX))

if @debug is not null 
  exec dbo.sp_help_executesproc 'BackupFiles_purge','dbo'



DECLARE BFF CURSOR READ_ONLY FOR 
select FILEID, filepath from dbo.BackupFiles 
where servername = @ServerName
 and ((isnull(@DatabaseName,'')='') OR (DatabaseName = @DatabaseName))
 and ((isnull(@dir,'')='') OR (filepath like @dir+'%'))

DECLARE @Filepath nvarchar(max) , @fileid int 
OPEN BFF

FETCH NEXT FROM BFF INTO @fileid,@Filepath
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		Begin Try 

		
		SELECT @cmd = 'del "' + @Filepath + '"' 

		if @debug is not null
		 Raiserror(@cmd,0,1)

		 INSERT INTO @CMDOUT(LINE) 
		 exec @rc = xp_cmdshell @cmd 

		 IF NOT EXISTS(SELECT * FROM @CMDOUT WHERE LINE LIKE '%DENIED%')
		 BEGIN
			delete from dbo.BackupFiles where Fileid=@fileid 
		 END 
		
		End Try

		Begin Catch

			select @ERM = isnull(@Filepath,'Null @Filepath') + ' Raised Error'+ char(10) + ERROR_MESSAGE()
			, @ERS = ERROR_SEVERITY() 
			

			Raiserror(@ERM,@ERS,1)

			
		End Catch

	END
	FETCH NEXT FROM BFF INTO @fileid,@Filepath
END

OnErrorExitCursor: 


CLOSE BFF
DEALLOCATE BFF

--print isnull(@dir,'NULL')

if @dir is null and @doSource = 1 
Begin
	
	set @cmd = 'SQLCMD -S ' + @ServerName + ' -d Ops -E -Q "BackupFiles_purge ''' + @ServerName + ''',''' + isnull(@DatabaseName,'') + ''''
	if @debug is not null
	Raiserror(@CMD,0,1) with nowait 

	Exec @rc = xp_cmdshell @cmd 
	Print @rc 

end 


END
GO


IF 1=2
BEGIN
	--exec dbo.sp_help_executesproc 'BackupFiles_purge','dbo'

DECLARE @ServerName nvarchar(max) = null 
	,@DatabaseName nvarchar(max) = null 
	,@dir nvarchar(max) = null 
    ,@doSource bit  = null 
	,@debug int  = null 

SELECT @ServerName = 'WDGTWTTSQLARCH' --nvarchar
	-- ,@DatabaseName = 'NetWorking' --nvarchar
	--,@dir = '\\osgtfs01\sqlbackups3' --nvarchar
	,@doSource = 0
	,@debug = 1 --int
	
EXECUTE [dbo].BackupFiles_purge @ServerName = @ServerName --nvarchar
	,@DatabaseName = @DatabaseName --nvarchar
	,@dir = @dir --nvarchar
	,@doSource = @doSource
	,@debug = @debug --int

END