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
    in _name text
)
language plpgsql SECURITY DEFINER
as $$
declare 
    rec record;
begin 
    INSERT into department(deptname) values(_name);
    -- for rec in (select * from department)
    -- loop
    --     raise notice '% ', rec;
    -- end loop;
    -- -- select * from department;
END; $$;

call test2('me');

grant on procedure 