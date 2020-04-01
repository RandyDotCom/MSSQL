USE OPS 
GO
EXEC dbo.sp_changedbowner @loginame = N'sa', @map = false 
GO

IF 1=2 
BEGIN

SET NOCOUNT ON;

--DECLARE obc CURSOR READ_ONLY FOR 
--SELECT 'DROP ' + case ob.type when 'P' then 'Procedure ' 
--	when 'V' then 'View '
--	else 'Function ' 
-- end +'[' + ob.name+']'  
--	FROM 
--	sys.objects ob
--where 1= 1 
-- and ob.type in ('FN','IF','P','TF','V')
-- and ob.name not in ('fn_diagramobjects','fn_split','sp_alterdiagram')
-- and ob.name not like '%diagram%'	
--order by 
--	ob.type, ob.name  


--DECLARE @stmt varchar(max)
--, @ERM nvarchar(max) , @ERN int, @ERS int 

--OPEN obc

--FETCH NEXT FROM obc INTO @stmt
--WHILE (@@fetch_status <> -1)
--BEGIN
--	IF (@@fetch_status <> -2)
--	BEGIN
--		BEGIN TRY 
			
--			Raiserror(@stmt,0,1)  with nowait 
--			--EXEC(@stmt) 
			
			
--		END TRY 
--		BEGIN CATCH 
			
			
--			SELECT 
--			  @ERM = ERROR_MESSAGE()
--			, @ERN=isnull(@ERN,0) + 1 
--			, @ERS=ERROR_SEVERITY()
			
--			--GOTO onErrorExit 
			
--		END CATCH 
		
--	END
--	FETCH NEXT FROM obc INTO @stmt
--END

--OnErrorExit: 


--CLOSE obc
--DEALLOCATE obc
END 

GO 

