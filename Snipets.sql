-- Roles and Permissions
1. check current User
    select current_user;

2. grant "group_role" membership to role1, role2....
GRANT group_role TO role1, ... ;
REVOKE group_role FROM role1, ... ;

Example: grant student,joe to student_login;
    revoke student,joe from student_login;

3. remove permission to access stored procedure
revoke all on procedure <procedure_name> from public;



create or replace procedure test2(
    in value numeric(4,2),
    inout _id numeric(4,2)
)
language plpgsql SECURITY DEFINER
as $$
declare 
begin 
    -- INSERT into department(deptname) values(_name);
    -- for rec in (select * from department)
    -- loop
    --     raise notice '% ', rec;
    -- end loop;
    -- -- select * from department;
    -- select deptId into _id from department where department.deptName=_name;
    _id:=value/2;

END; $$;

create or replace procedure test(
    -- in _name text,
    -- inout _id integer
    -- in value integer
)
language plpgsql SECURITY DEFINER
as $$
declare 
    -- ans numeric(4,2);
    tableName text;
    query text;
begin 
    tableName:='department';
    query= 'SELECT * FROM ' || tableName;
    execute query;
    -- select * from tableName;
    -- INSERT into department(deptname) values(_name);
    -- for rec in (select * from department)
    -- loop
    --     raise notice '% ', rec;
    -- end loop;
    -- -- select * from department;
    -- ans:=-1;
    -- raise notice 'value of ans %',ans;
    -- call test2(value,ans);
    -- raise notice 'value of ans %',ans;
END; $$;

call test();

grant on procedure 