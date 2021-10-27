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
    tableName = 'facultyGradeTable_' || sectionID::text;
    query := 'CREATE table ';
    query := query || tableName;
    tmp := '(
        studentID integer not null,
        grade VARCHAR(2),
    );';
    query := query || tmp;

    EXECUTE query;
end; $$;
/* ********************************************************************** */





