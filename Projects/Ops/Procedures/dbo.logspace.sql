USE OPS
Go

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = N'dbo' AND SPECIFIC_NAME = N'logspace' )
   DROP PROCEDURE dbo.logspace
GO

CREATE PROCEDURE dbo.logspace
	@dbid int = null, 
	@mbfree int = null OUTPUT
AS
Begin
SET NOCOUNT ON; 

declare @drives table(drive varchar(1), mbfree int) 
insert into @drives(drive,mbfree) 
exec master.sys.xp_fixeddrives

select @mbfree = mbfree from @drives 
where Drive in (select left(Physical_name,1) drive from master.sys.master_files where database_id=@dbid and Type=1)


end 
GO

if 1=2
Begin

DECLARE @dbid int, @mbfree int
 set @dbid = db_id() 
EXECUTE dbo.logspace @dbid = @dbid, @mbfree = @mbfree OUTPUT

SELECT @mbfree

END 
go


if 1=2 
begin
	declare @mbfree int, @dbid int , @test int 

	 set @dbid = db_id() 
	EXECUTE dbo.logspace @dbid = @dbid, @mbfree = @mbfree OUTPUT
	SET @test = @mbfree 


	While @test <= @mbfree
	Begin
	  Raiserror('Waiting',0,1) with nowait 
	  EXECUTE dbo.logspace @dbid = @dbid, @mbfree = @mbfree OUTPUT
	  waitfor delay '00:00:01' 

	End


end
GO


