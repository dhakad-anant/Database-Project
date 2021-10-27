/* Trigger to generate faculty grade table corresponding to his (course, semester, year) */
CREATE TRIGGER generateFacultyGradeTable
after insert on Teaches 
For each STATEMENT 
EXECUTE PROCEDURE generateFacultyGradeTable_trigger_function(
    new.sectionID
);

create or replace function generateFacultyGradeTable_trigger_function(
    IN sectionID INTEGER
)
    return return_type 
    language plpgsql
as $$
declare
    query, tmp,tableName text;
begin 
    tableName = 'FacultyGradeTable_' || sectionID::text;
    query := 'CREATE table ';
    query := query || tableName;
    tmp := '(
        studentID integer not null,
        grade VARCHAR(2),
    );';
    query := query || tmp;

    EXECUTE query;

    return new;
end; $$;
/* ********************************************************************** */

/* TRIGGER - generate_transcript_table****************************************************/
CREATE TRIGGER generate_transcript_table
after insert on Student 
For each STATEMENT 
EXECUTE PROCEDURE generate_transcript_table_trigger_function(studentID);

CREATE or replace FUNCTION generate_transcript_table_trigger_function(
    IN studentID INTEGER
)
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
            courseID INTEGER NOT NULL,
            semester INTEGER NOT NULL,
            year INTEGER NOT NULL,
            grade VARCHAR(2),
            PRIMARY KEY(courseID, semester, year),
            FOREIGN KEY(courseID, semester, year) REFERENCES CourseOffering(courseID, semester, year)
        );';
    
    EXECUTE query; -- transcript table created

    return new;
    -- handle permissions
    -- student(read only), dean(read & write), 
end; $$;   
/* ******************************************************************************************** TRIGGER 1 - generate_transcript_table ends ******************************************************************************************** */




