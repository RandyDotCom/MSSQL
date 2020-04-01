USE OPS
GO
SET NOCOUNT ON;

/* Stash current Database File locations */


insert into ops.dbo.Settings(Context, Name, Value)
select md.name [context], mf.name [name], mf.physical_name [value]
from master.sys.databases md
  inner join master.sys.master_files mf on mf.database_id = md.database_id 
  left outer join ops.dbo.Settings st on st.Context = md.name and st.Name = mf.name 
where st.idSettings is null 


--exec Ops.dbo.BackupFiles_Report
--GO



