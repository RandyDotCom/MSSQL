--C:\Users\v-ranpi\Documents\SQL Server Management Studio\Projects\Ops\Scripts\SchemaReport.sql

--if object_id('tempdb..#Tables') is not null 
--  Drop Table #tables 

--Select
--	o.[OBJECT_ID], 
--	s.name [schema],
--	o.[Name] as [table_name],
--	o.[Type],
--	o.[Modify_date],
--	Cast(0 as bigint) [ROWS],
--	cast(0 as bigint) [ROWLENGTH] ,
--	Cast(0 as real) [DataPageWeight],
--	CAST(0 as int) [TableTextInRowLimit],
--	CAST(0 as int) [maxColumnLenFound],
--	c.[name] as Column_Name ,
--	t.name as [DataType],
--	c.[column_id] ,
--	c.[system_type_id] ,
--	c.[user_type_id] ,
--	c.[max_length] ,
--	c.[precision] ,
--	c.[scale] ,
--	c.[is_identity] ,
--	c.[is_nullable] , 
--	c.collation_name 
--INTO #tables
--FROM
--	sys.objects o,
--	sys.Columns c,  -- Select * from
--	sys.systypes t,
--	sys.schemas s 
--WHERE 
--	o.[Object_ID] = c.[OBJECT_ID]
--	and o.schema_id = s.schema_id 
--	and c.[user_type_id] = t.[xusertype]
--	and o.[Type]='U'
--	and o.[name] not in ('sysdiagrams')

--ORDER BY
--	o.[TYPE], o.[NAME], C.is_identity DESC, Column_id




--DECLARE @xdid int  = null  --int
--	,@Property varchar(50) = null  --varchar
--	,@Context varchar(50) = null  --varchar
--	,@xData xml  = null  --xml
--	,@debug int  = null  --int

--select @xData = (
--Select [schema], table_name, column_name, dataType from #Tables [obj]
--for xml auto, root('schema')
--) 

--SELECT @xdid = @xdid
--	,@Property = 'Database'
--	,@Context = 'Schema Current'
--	,@xData = @xData
--	,@debug = @debug

--EXECUTE dbo.xmlReports_put @xdid = @xdid
--	,@Property = @Property
--	,@Context = @Context
--	,@xData = @xData
--	,@debug = @debug



--DECLARE @stmt varchar(max) 
--select @stmt = Replace('""\\wpchive\central\EIACollection\Repository\MSSQL\OpsHealth\Schema.xml""','"','') 

--	if OBJECT_ID('tempdb..#xmlfromfile') is not null 
--	DROP table #xmlfromfile

--Create Table #xmlfromfile(xd xml) 

--SELECT @stmt='SELECT * FROM OPENROWSET( BULK ''' + @stmt + ''', SINGLE_BLOB) AS x '

--insert into #xmlfromfile(xd) 
--EXEC (@STMT)

--SELECT @xData = xd FROM #xmlfromfile


--SELECT 
--	@Property = 'Database'
--	,@Context = 'Schema Previous'
--	,@xData = @xData
--	,@debug = @debug

--EXECUTE xmlReports_put @xdid = @xdid
--	,@Property = @Property
--	,@Context = @Context
--	,@xData = @xData
--	,@debug = @debug

	