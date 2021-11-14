/* UNCONDITIONAL LOOP syntax */
<<label>>
loop
    statements;
end loop;


/* nested loops */
<<outer>>
loop 
    statements;
    <<INNER>>
    loop
        /* .. */
        exit <<INNER>>
    end loop;
end loop;


/* while loop SYNTAX in PL/pgSQL */
[<<label>>]
while condition loop 
    statments;
end loop;


/* for loop syntax in SQL */
[ <<label>> ]
for loop_counter in [ reverse ] from .. to [ by step ] loop 
    statements;
end loop [ label ];


/* for loop syntax to iterate ove result set. */
[ <<label>> ]
for varRec in query loop
    statements;
end loop [ label ];


/* for loop to iterate over the result set of a dynamic query */
[ <<label>> ]
for row in EXECUTE query_expression [using query_param, [, ...]] loop
    statements;
end loop;


/* syntax for exit */
exit [label] [when boolean_expression]


/* syntax for continue */
continue [loop_label] [when condition]


/* syntax for GRANT command */
GRANT privilege_list | ALL 
ON table_name 
TO role_name;


/* syntax for REVOKE command */
REVOKE privilege_list | ALL
ON TABLE table_name | ALL TABLES IN SCHEMA schema_name 
FROM role_name;


/* syntax to create function */
create or replace function function_name(param_list)
    return return_type 
    language plpgsql
as $$
declare
    --variable declaration
begin 
    --logic
end $$;


/* Syntax of a function that returns a TABLE */
create or replace function function_name(param_list)
    return table(column_list)
    language plpgsql
as $$
declare
    --variable declaration
begin 
    --logic
end; $$;


/* syntax for stored procedure */
create [or replace] procedure procedure_name$0(parameter_list)
language plpgsql
as $$
declare
-- variable declaration
begin
-- stored procedure body
end; $$;


/* syntax for calling a stored procedure */
call stored_procedure_name(argument_list);


/* syntax for triggers */
CREATE TRIGGER trigger_name 
{Before | After} { event }
ON table_name 
[For [Each] {Row | Statement}] EXECUTE PROCEDURE trigger_function;


/* query for getting a list of stored procedure */
select n.nspname as schema_name,
       p.proname as specific_name,
       l.lanname as language,
       /* case when l.lanname = 'internal' then p.prosrc
            else pg_get_functiondef(p.oid)
            end as definition, */
       pg_get_function_arguments(p.oid) as arguments
from pg_proc p
left join pg_namespace n on p.pronamespace = n.oid
left join pg_language l on p.prolang = l.oid
left join pg_type t on t.oid = p.prorettype 
where n.nspname not in ('pg_catalog', 'information_schema')
      and p.prokind = 'p'
order by schema_name, specific_name;

/* query to view all permissions */


/* query to export table into a csv file */
create or replace procedure exportIntoCSV(
    IN _fileName TEXT
)
language plpgsql
as $$
declare
    filepath text := '';
begin
    filepath = 'C:\fordbmsproject\'
    EXECUTE (COPY course to 'C:\')
end; $$;
/* **************************************************************************************************************************************************************************************** */


/* IMPORTANT Dynamic query**************************************************************************************************************************************************************************************** */
create or replace procedure fixusing(
    sortType INTEGER,
    recCount INTEGER
)
language plpgsql
as $$
declare
    sort_type   smallint;
    rec_count   integer;
    rec         record;
    query       text;
begin 
    sort_type := sortType;
    rec_count := recCount;
    query := 'select * from course ';
    
    if sort_type = 1 then 
        query := query || 'order by title';
    elsif sort_type = 2 then 
        query := query || 'order by courseid';
    else 
        raise 'Invalid : sort_type %', sort_type;
        return;
    end if;
    
    query := query || ' limit $1';

    for rec in execute query using rec_count loop 
        raise notice '% - %', rec.courseid, rec.title;
    end loop;
end $$;
/* Dynamic query ends **************************************************************************************************************************************************************************************** */

/* syntax for exiting simple being .. end block using EXIT */
do $$
begin 
    <<simple_block>>
    begin 
        exit simple_block;
        -- for demo purpose
        raise notice '%', 'unreachable!';
    end;
    raise notice '%', 'End of block';
end $$;


do $$ 
DECLARE 
    created_at time := now();
BEGIN
    raise notice '%', created_at;
    perform pg_sleep(2);
    raise notice '%', created_at;
END
$$;

do $$ 
<<outer_block>>
declare 
    counter integer := 0;
BEGIN
    counter := counter + 1;
    raise notice 'The current value of the counter is %', counter;

    <<inner_block>>
    DECLARE
        counter integer := 0;
    BEGIN
        counter := counter + 10;
      raise notice 'Counter in the subblock is %', counter;
        raise notice 'Counter in outer block is %', outer_block.counter;
    END inner_block;

    raise notice 'Counter integer in the outer block is %', counter;
END outer_block $$;


do 
$$ 
declare 
    rec record;
begin 
    for rec in (select name, year from battles where year > 1950)
    loop
        raise notice '% was fought in % year', rec.name, rec.year;
    end loop;
end;
$$;

do 
$$
declare
    counter integer := 4;
begin 
    if counter > 5 THEN 
        raise notice 'this is fucking goood!';
    ELSE
        raise notice 'this is just good!';
    end if;
end;
$$;



do 
$$
declare
    n         integer := 50;
    fib       integer := 0;
    counter   integer := 0;
    i         integer := 0;
    j         integer := 1;
begin 
    raise notice '1th fibonacci is 0';
    <<outer>>
    loop
        fib := i + j;
        j := i;
        i := fib;
        counter := counter + 1;
        raise notice '%th fibonacci is %',
                counter+1, 
                fib; 
        if counter >= n-1 then 
            exit outer;
        end if;
    end loop;
end;
$$;

do $$
declare
    
begin 
    for counter in reverse 30 .. 10 by 3 loop 
        raise notice 'value is %', counter;
    end loop;
end $$;

course(courseid, title, dept_name, credits);

do $$
declare
    rec record;
begin 
    for rec in (select * from course) loop
        raise notice '% (%) of % department(% credits)',
            rec.title, 
            rec.courseid,
            rec.dept_name,
            rec.credits;
    end loop;
end $$;





/* comparison of if loops */
if counter > 10 then 
    exit;
end if;

-- cleaner one.
exit when counter > 10;


create or replace function printtext(yourtext text)
    returns int 
    language plpgsql 
as $$
begin 
    raise notice '%', yourtext;
    -- return 0;
    return;
end $$;


create or replace function get_film_stat(out min_len int, out max_len int, out avg_len numeric)
    language plpgsql 
as $$
begin 
    select min(length), max(length), avg(length)::numeric(5, 1) into min_len, max_len, avg_len
    from film;
end $$;


create or replace function swap(
            inout x int,
            inout y int
)
    language plpgsql
as $$
begin 
    select x, y into y,x;
end; $$;


create or replace function get_film (
  p_pattern varchar
) 
	returns table (
		film_title varchar,
		film_release_year int
	) 
	language plpgsql
as $$
begin
	return query 
		select
			title,
			release_year::integer
		from
			film
		where
			title ilike p_pattern;
end;$$;

drop table if exits accounts;

create table accounts(
    id int generated by default as identity, 
    name varchar(100) not null, 
    balance dec(15, 2) not null, 
    primary key(id)
);

insert into accounts(name, balance) values('Bob', 10000);
insert into accounts(name, balance) values('Alice', 10000);


create or replace procedure transfer(
    sender int, 
    receiver int, 
    amount dec
)
    language plpgsql 
as $$
begin 
    -- subtracting the amount from the sender's account
    update accounts 
    set balance = balance - amount
    where id = sender;

    -- adding the amount to the receiver's account
    update accounts 
    set balance = balance + amount 
    where id = receiver;

    commit;
end; $$;


/* Syntax of a function that returns a TABLE */
create or replace function function_name(param_list)
    return table(column_list)
    language plpgsql
as $$
declare
    --variable declaration
begin 
    --logic
end; $$;


create or replace function viewcourse()
returns table(
        courseid INTEGER,
        title varchar(20),
        dept_name varchar(6),
        credits INTEGER
    )
language plpgsql
as $$
DECLARE
    rec record;
begin
    for rec in (select * from course) loop 
        courseid := rec.courseid;
        title := rec.title;
        dept_name := rec.dept_name;
        credits := rec.credits;
        return next;
    end loop;  
end; $$;
select * from viewcourse();


create or replace procedure updateCourseCatalogue(
    IN _courseid INTEGER,
    IN _title text,
    IN _dept_name text,
    IN _credits INTEGER
)
language plpgsql SECURITY DEFINER
as $$
declare
begin
    INSERT INTO course(courseid, title, dept_name, credits)
        values(_courseid, _title, _dept_name, _credits);
end; $$;








SELECT grantee, privilege_type 
FROM information_schema.role_table_grants 
WHERE table_name='department' and grantee<>'postgres' and grantee<>'public';

drop role academicsection     ;
drop role batchadvisor        ;
drop role batchadvisor_1      ;
drop role batchadvisor_2      ;
drop role batchadvisor_3      ;
drop role batchadvisor_4      ;
drop role batchadvisor_5      ;
drop role deanacademicsoffice ;
drop role faculty             ;
drop role faculty_1           ;
drop role faculty_2           ;
drop role faculty_3           ;
drop role faculty_4           ;
drop role student_1           ;
drop role student_2           ;
drop role student_3           ;
drop role student_4           ;
drop role students;

delete from FacultyGradeTable_9;
delete from transcript_1
where courseid=9;