-- Roles and Permissions
1. check current User
    select current_user;

2. grant "group_role" membership to role1, role2....
GRANT group_role TO role1, ... ;
REVOKE group_role FROM role1, ... ;

Example: grant student,joe to student_login;
    revoke student,joe from student_login;

 3. remove permission to access stored procedure 
REVOKE ALL ON PROCEDURE <procedure_name> FROM PUBLIC;

grant execute on procedure <procedure_name> to role;

4. passing list as an argument to a stored procedure
    create or replace procedure test(
        in x integer[]
    )
    language plpgsql
    as $$
    declare
    -- variable declaration
        r integer;
        count integer;
        len integer;
    begin
        len:= array_length(x,1); -- to find the length of an array
        raise notice 'Length of array is: %',len;
        count:=0;
        foreach r in ARRAY x loop
            count=count+r;
            raise notice '%',r;
            end loop;
        -- end if;
        raise notice 'count is: %',count;
    end; $$;
    call test('{2,3}'::integer[]);

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