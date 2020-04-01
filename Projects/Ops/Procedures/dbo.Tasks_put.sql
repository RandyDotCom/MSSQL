USE [Ops]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tasks_put]') AND type in (N'P', N'PC'))
	DROP PROCEDURE [dbo].[Tasks_put]
GO

SET ANSI_NULLS ON; SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Tasks_put]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[Tasks_put] AS' 
END
GO


ALTER procedure [dbo].[Tasks_put]
	@WorkerName varchar(max) = null,
	@step_name varchar(50) = null,
	@commandtype varchar(50) = null,
	@command nvarchar(max) = null,
	@RequestDate datetime = null,
	@TaskState varchar(50) = null,
	@KeyName nvarchar(600) = null,
	@LoginName sysname = null ,
	@xmlstring varchar(max) = null,
	@Taskid int = null OUTPUT, 
	@putdata bit = null,
	@userid int = null,
	@debug int = null

AS
BEGIN
  SET NOCOUNT ON;
  SET XACT_ABORT ON;
  declare @erm nvarchar(max), @JOb_id uniqueidentifier , @idTask int 
  select @JOb_id = newid() 

  if isnull(@command,'')='' 
    Begin
	  select @ERM = '@Command is required ' 
	  Raiserror(@ERM,11,1) with nowait 
	  Return 0; 
	end 

  select @putdata =1 , @TaskState='New', @LoginName = isnull(@LoginName,SYSTEM_USER)
  , @RequestDate = isnull(@requestdate,dateadd(minute,15,getdate()))
  , @commandtype = CASE WHEN @commandtype in ('Powershell','TSQL','CmdExec') then @commandtype else 'TSQL' end 
    
	if isnull(@putdata,0)=1 
	BEGIN
	 begin try
	  begin Transaction 
		/* Validate Data */
		  BEGIN

			insert into [dbo].[Tasks]([job_id], [WorkerName], [step_name], [commandtype], [command], [LoginName], [RequestDate], [TaskState], [KeyName])
			values (@job_id, @WorkerName, @step_name, @commandtype, @command, @LoginName, @RequestDate, @TaskState, @KeyName)

			SELECT @Taskid = scope_identity()
		  END
	  commit transaction
	end try
	begin catch 
	  rollback transaction
	    select @erm = ERROR_PROCEDURE() + 'Raised Error: ' + ERROR_MESSAGE()
		Raiserror(@ERM,11,1) with nowait 
	end catch

	END -- Valid @putdata

	--Print @Taskid
	--if @debug > 1 
	-- exec [dbo].[Tasks_get] @idTask=@idTask
		


END
GO


if 1=2
Begin 

--exec dbo.sp_help_executesproc 'tasks_put' 

DECLARE @WorkerName varchar(max) = null 
	,@step_name varchar(50) = null 
	,@commandtype varchar(50) = null 
	,@command nvarchar(max) = null 
	,@RequestDate datetime  = null 
	,@TaskState varchar(50) = null 
	,@KeyName nvarchar(max) = null 
	,@LoginName sysname  = null 
	,@xmlstring varchar(max) = null 
	,@Taskid int  = null 
	,@putdata bit  = null 
	,@userid int  = null 
	,@debug int  = null 

SELECT @Taskid = @Taskid --int
	,@WorkerName = 'Randy' --varchar
	,@step_name = 'Rocks' --varchar
	,@commandtype = 'TSQL' --varchar
	,@command = 'Raiserror(''Randy is creating an error'',11,1)' --nvarchar
	,@LoginName = @LoginName --varchar
	,@RequestDate = @RequestDate --datetime
	,@TaskState = 'NEW' --varchar
	,@KeyName = @KeyName --nvarchar
	,@xmlstring = @xmlstring --varchar
	,@putdata = @putdata --bit
	,@userid = @userid --int
	,@debug = @debug --int

EXECUTE [dbo].Tasks_put @WorkerName = @WorkerName --varchar
	,@step_name = @step_name --varchar
	,@commandtype = @commandtype --varchar
	,@command = @command --nvarchar
	,@RequestDate = @RequestDate --datetime
	,@TaskState = @TaskState --varchar
	,@KeyName = @KeyName --nvarchar
	,@LoginName = @LoginName --sysname
	,@xmlstring = @xmlstring --varchar
	,@Taskid = @Taskid OUTPUT  --int
	,@putdata = @putdata --bit
	,@userid = @userid --int
	,@debug = @debug --int

	print  @Taskid

END 
