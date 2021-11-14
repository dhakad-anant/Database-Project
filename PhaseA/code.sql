/* ******************************TRIGGER 1 - generate_transcript_table*********************************************************************************************/
CREATE TRIGGER generate_transcript_table
after insert on Student 
For each STATEMENT 
EXECUTE PROCEDURE generate_transcript_table_trigger_function(studentID);

CREATE or replace FUNCTION generate_transcript_table_trigger_function(studentID INTEGER)
    returns TRIGGER
    language plpgsql
as $$
declare
    -- variable declaration
    tableName   text;
    query       text;
begin
    -- stored procedure body
    tableName := 'Transcript_' || studentID::text;
    query := 'CREATE Table ' || tableName;
    query := query || '
        (
            courseID VARCHAR(10) NOT NULL,
            semester INTEGER NOT NULL,
            year INTEGER NOT NULL,
            grade VARCHAR(2),
            PRIMARY KEY(courseID, semester, year),
            FOREIGN KEY(courseID, semester, year) REFERENCES CourseCatalogue(courseID, semester, year)
        );';
    
    EXECUTE query; -- transcript table created

    return new;
    -- handle permissions
    -- student(read only), dean(read & write), 
end; $$;   
/* ******************************************************************************************** TRIGGER 1 - generate_transcript_table ends ******************************************************************************************** */


/* Compute the current CGPA of any student************************************************************************/
create or replace PROCEDURE calculate_current_CGPA(IN INT studentID, out _cgpa)
    language plpgsql    
as $$
declare
    -- Transcritp_1
    transcriptTable text;
    totalCredits    INTEGER := 0;
    numerator       INTEGER := 0;
    rec             record;
    CGPA            NUMERIC := 0.0;
begin
    transcriptTable := 'Transcript_' || studentID::text;

    for rec in (
        select (CourseCatalogue.C, GradeMapping.val) into rec
        from transcriptTable, CourseCatalogue, GradeMapping
        where transcriptTable.courseID = CourseCatalogue.courseID AND 
            transcriptTable.year = CourseCatalogue.year AND 
            transcriptTable.semester = CourseCatalogue.semester AND
            transcriptTable.grade <> NULL AND
            transcriptTable.grade <> 'F' AND 
            transcriptTable.grade = GradeMapping.grade
    ) 
    loop
        totalCredits := totalCredits + rec.C;
        numerator := numertor + (rec.val * rec.C);
    end loop;
    
    CGPA := (numerator/totalCredits)::NUMERIC(4, 2);

    raise notice 'CGPA for studentID % is %', 
        studentID, 
        CGPA;
    _cgpa := CGPA 
    
end; $$;
-- cgpa = (summation{no. of credits x grade_in_that_course})/totalCredits
/****************************************************************************************** */

















































/* 
CREATE or replace procedure test2()
language plpgsql
as $$
declare
    pradeep text;
    query text;
    tmp text;
begin
    pradeep := 'anant';
    
    query := 'CREATE table ';
    query := query || pradeep;
    tmp := '(
        x integer not null,
        name varchar(20) not null,
        lastName varchar(20) not null,
        salary int not null,
        PRIMARY key(salary)
    );';
    query := query || tmp;
    EXECUTE query;
    execute 'grant something something';
end; $$;

insert into anant(x, name, lastName, salary) values(1, 'anant', 'dhakad', 10); */