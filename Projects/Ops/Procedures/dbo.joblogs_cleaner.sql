USE Ops 
GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON;
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo'
     AND SPECIFIC_NAME = N'joblogs_cleaner' )
   DROP PROCEDURE dbo.joblogs_cleaner
GO


CREATE PROCEDURE dbo.joblogs_cleaner 
	@rootpath varchar(max) = null, 
	@job_name nvarchar(max) = null,
	@command varchar(4000) = null,
	@maxDayAge int = null, 
	@debug int = null 
AS
BEGIN
SET NOCOUNT ON; 
DECLARE @ERM nvarchar(max), @ERS int, @ERN int 
DECLARE @RC int 
DECLARE @cmdout table (line varchar(max))
DECLARE @commandList table(cmd varchar(max)) 

IF @command is not null
begin
	insert into @commandList(cmd) values(@command)
	goto ExecCommands
end 

declare @LastLogName varchar(max) 

select @rootpath = isnull(@rootpath,dbo.[fnSetting]('Instance','BackupDirectory'))
 
Declare @tmstamp varchar(max) 
SELECT @tmstamp = CONVERT(varchar(100),getdate(),21)
SELECT @tmstamp = REPLACE(REPLACE(REPLACE(REPLACE(@tmstamp,'-',''),'.',''),':',''),' ','-')


--Raiserror(@tmstamp,0,1) with nowait 
if not exists(select job_id from msdb.dbo.sysjobs where name=@job_name)
begin
 select @ERM = 'Job not found ' + isnull(@job_name,' NULL')
 Raiserror(@ERM,11,1) 

end

insert into @commandList
select 'Type "' + jf.[filename] + '" > "' + replace(jf.[filename],'.log','_'+@tmstamp+'.log') + '"'
FROM(select distinct output_file_name [filename]
from  msdb.dbo.sysjobsteps 
 where output_file_name is not null and job_id = (select job_id from msdb.dbo.sysjobs where name=@job_name)
 ) jf 


 
SELECT @command = 'FORFILES /P ' + isnull(@RootPath,' Null Rootpath') + ' /S /M *.log /C "cmd /c DEL @path" /D -' + cast(isnull(@maxDayAge,2) as varchar(10)) 
--Raiserror(@command,11,1) 

 if @command is null 
 BEGIN
	Raiserror('@command for clean is null',11,1) with nowait 
	Return 0; 
 END

insert into @commandList (cmd) values(@command)

ExecCommands:

if @debug=3
BEGIN
  select cmd from @commandList
  Return 1; 
END



DECLARE CommandCurser CURSOR READ_ONLY FOR 
select cmd from @commandList

DECLARE @name nvarchar(max)
OPEN CommandCurser

FETCH NEXT FROM CommandCurser INTO @command
WHILE (@@fetch_status <> -1)
BEGIN
	IF (@@fetch_status <> -2)
	BEGIN

		Raiserror(@command,0,1) with nowait
	if isnull(@debug,0) <= 1 
	BEGIN		 
		Begin Try 

			insert into @cmdout
			exec @ern = xp_cmdshell @command
				if @ERN > 1 
				BEGIN
					SELECT @ERM = 'Return Code:' + Cast(@ERN as varchar(20))
					Raiserror(@ERM,11,1)
				END
		End Try
		Begin Catch

			select @ERS = ERROR_SEVERITY() 

			select @ERM = ERROR_MESSAGE() + char(10) + isnull(@command,'NUll @Command') + ' Return Code:' + isnull(Cast(@ERN as varchar(10)),' Null @ERN') 
			select @ERM = Coalesce(@ERM+char(10),'') + isnull(line,'') from @cmdout 
			Raiserror(@ERM,11,1)

			IF @ERS > 11 Goto OnErrorExitCursor

		End Catch
	END

			--select @ERM = ERROR_MESSAGE() + char(10) + isnull(@command,'NUll @Command') + ' Return Code:' + isnull(Cast(@ERN as varchar(10)),' Null @ERN') 
			--select @ERM = Coalesce(@ERM+char(10),'') + isnull(line,'') from @cmdout 
			--Raiserror(@ERM,0,1)
			delete @cmdout

	END
	FETCH NEXT FROM CommandCurser INTO @command
END

OnErrorExitCursor: 


CLOSE CommandCurser
DEALLOCATE CommandCurser



END
GO


IF 1=2
BEGIN
	--exec ops..sp_help_executesproc @procname='joblogs_cleaner', @schema='dbo'

DECLARE @rootpath varchar(max) = null 
	,@job_name nvarchar(max) = null 
	,@command nvarchar(max) = null 
	,@maxDayAge int  = null 
	,@debug int  = null 

SELECT @rootpath = @rootpath --varchar
	,@job_name = 'dbaBackupsLogs' --nvarchar
	,@command = @command --nvarchar
	,@maxDayAge = 1 --int
	,@debug = 1 --int

--select @command='dir \\vsotipsql01\sqlbackups'

EXECUTE [dbo].joblogs_cleaner @rootpath = @rootpath --varchar
	,@job_name = @job_name --nvarchar
	,@command = @command --nvarchar
	,@maxDayAge = @maxDayAge --int
	,@debug = @debug --int

END