USE [OPS]
GO
/****** Object:  UserDefinedFunction [dbo].[ConvertListToTable]    Script Date: 7/7/2014 2:16:51 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ConvertListToTable]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION [dbo].[ConvertListToTable]
GO
/****** Object:  UserDefinedFunction [dbo].[ConvertListToTable]    Script Date: 7/7/2014 2:16:52 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ConvertListToTable]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
BEGIN
execute dbo.sp_executesql @statement = N'CREATE FUNCTION [dbo].[ConvertListToTable] 
/**************************************************************************************************************
********
*                                                                                                               
     
*                                                ConvertListToTable                                             
           
*                                                --------                                                       
*                                                                                                               
     
* DESCRIPTION:	This Function will take a delimited list of vals and convert it to a table
*                                                                                                               
     
* DATE:	        Wed Oct 16 09:06:55 2002                                                                        
                             
*                                                                                                               
     
* AUTHOR:	Glantz                                                                                    
*                                                                                                               
     
* PARAMETERS:	 @List=,
*		 				                                                                
                                                                                                                
            
* INVOCATION:	ConvertListToTable @list, @valsAsInts, @delimiter                                               
          
***************************************************************************************************************
*******
*                                                 C H A N G E   L O G                                           
     
*                                                                                                               
     
* Programmer             Description                                                               Date/Request 
     
* ---------------------- ------------------------------------------------------------------------  
----------------  
*                                                                                                               
     
***************************************************************************************************************
*******/
--Declare the Input variables.	
(
@list varchar(8000),
@valsAsInts bit,
@delimiter varchar(5)
)

--Declare the Type of function to perform
RETURNS @tbl TABLE ( 	
	valID int IDENTITY(1,1)  NOT NULL,
	strVal varchar(255) NOT NULL,
	intVal int NULL 
)
AS
BEGIN

	DECLARE @str varchar(255)
	DECLARE @dlen int
	DECLARE @pos int

	SET @dlen = len( @delimiter )
   
  	WHILE RTRIM( LTRIM( REPLACE( @list, @delimiter, '''' ) ) ) <> ''''
	BEGIN  
		SET @pos = CHARINDEX( @delimiter, @list, 1 )  

		IF @pos = 0
			SET @str = @list
		ELSE
			SET @str = LTRIM( RTRIM( LEFT( @list, @pos - 1 ) ) )  

		IF @str <> ''''  
		BEGIN  
			SET @str = LTRIM( RTRIM( @str ) )

			IF @valsAsInts = 0
        			INSERT INTO @tbl( strVal ) VALUES ( @str )    
			ELSE
				INSERT INTO @tbl( strVal, intVal ) VALUES( @str, CAST( @str as int ) )
		END  

		IF @pos < LEN( @list ) AND @pos <> 0
		BEGIN
			SET @list = RIGHT( @list, len( @list ) - @pos - @dlen + 1 ) 
		END
		ELSE
		BEGIN
			SET @list = ''''
		END
	END
RETURN
END


' 
END

GO
