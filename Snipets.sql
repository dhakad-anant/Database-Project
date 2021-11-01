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

grant execute on procedure <procedure_name> to role;


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

create or replace procedure test(
    in _name text
)
language plpgsql SECURITY INVOKER
as $$
declare 
begin 
    INSERT into department(deptname) values(_name);
END; $$;
call test();



drop trigger <trigger_name> on <tableName> ;
select * from department;

drop table if exists department_demo;
create table department_demo(
    name varchar(20) 
);
drop trigger trigger_name on department ;
drop function trigger_function();
CREATE FUNCTION trigger_function()
    RETURNS TRIGGER 
    LANGUAGE PLPGSQL SECURITY INVOKER
AS $$
BEGIN
    -- trigger logic
    INSERT INTO department_demo(name) values(new.deptname);
    raise notice 'Hehe! I am a trigger function.';
    return new;
END;
$$;
CREATE TRIGGER trigger_name 
    AFTER INSERT
    ON department
    FOR EACH STATEMENT
        EXECUTE PROCEDURE trigger_function();