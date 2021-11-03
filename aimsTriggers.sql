/* *************   TRIGGER - on inserting an entry in student table **************Final***********************/

drop trigger demo_trigger on demo;
drop function demo_trigger_function;
CREATE or replace FUNCTION demo_trigger_function()
    RETURNS TRIGGER 
    LANGUAGE PLPGSQL
AS $$
BEGIN
    raise notice 'Update trigger function';
    return NEW;
END;
$$;
CREATE TRIGGER faculty_trigger 
    AFTER UPDATE
    ON demo
    FOR EACH ROW
        EXECUTE PROCEDURE demo_trigger_function();

UPDATE demo
SET int=3 where int=1;



CREATE TRIGGER postInsertingStudent
AFTER INSERT ON Student 
FOR EACH STATEMENT 
EXECUTE PROCEDURE postInsertingStudent_trigger_function();

CREATE or replace FUNCTION postInsertingStudent_trigger_function(
    IN studentID INTEGER
)
returns TRIGGER
language plpgsql
as $$
declare
    tableName   text;
    query       text;
begin
    /* Create transcript table for each student */
    tableName := 'Transcript_' || new.studentID::text;
    query := 'CREATE TABLE ' || tableName;
    query := query || '
        (
            courseID INTEGER NOT NULL,
            semester INTEGER NOT NULL,
            year INTEGER NOT NULL,
            grade VARCHAR(2),
            PRIMARY KEY(courseID, semester, year),
            FOREIGN KEY(courseID, semester, year) REFERENCES CourseOffering(courseID, semester, year)
        );';
    
    EXECUTE query;

    /* Create seperate ticket table for each student */
    tableName := 'StudentTicketTable_' || new.studentID::text;
    query := 'CREATE TABLE ' || tableName;
    query := query || '
        (
            insID INTEGER NOT NULL,
            courseID INTEGER NOT NULL,
            semester INTEGER NOT NULL,
            year INTEGER NOT NULL,
            timeSlotID INTEGER NOT NULL,
            ticketID SERIAL, 
            facultyVerdict BOOLEAN,
            batchAdvisorVerdict BOOLEAN,
            deanAcademicsOfficeVerdict BOOLEAN,
            PRIMARY KEY(insID,courseID,semester,year,timeSlotID)
        );';
    
    EXECUTE query; -- transcript table created

    return new;
    -- handle permissions
    -- student(read only), dean(read & write), 
end; $$;   
/* ********************************************************************************************************** */


/* Trigger to generate faculty grade table corresponding to his (course, semester, year) */
CREATE TRIGGER GenerateFacultyGradeTable 
AFTER INSERT ON Teaches 
For each STATEMENT 
EXECUTE PROCEDURE GenerateFacultyGradeTable_trigger_function(
    new.sectionID
);

create or replace function GenerateFacultyGradeTable_trigger_function(
    IN sectionID INTEGER                                  -- Should a trigger function take any argument?
)
returns TRIGGER                                            
language plpgsql 
as $$
declare
    query text;
    tableName text;
begin 
    tableName = 'FacultyGradeTable_' || sectionID::text;
    query := 'CREATE TABLE ' || tableName || '(
        studentID integer not null,
        grade VARCHAR(2),
    );';

    EXECUTE query;
    return new;
    
end; $$;
/* ********************************************************************** */


/* On adding a new instructor to the instructor table, we create a seperate ticket table for each faculty */
CREATE TRIGGER postInsertingInstructor
after insert on Instructor 
For each STATEMENT 
EXECUTE PROCEDURE postInsertingInstructor_trigger_function();

CREATE or replace FUNCTION postInsertingInstructor_trigger_function(
)
returns TRIGGER
language plpgsql
as $$
declare
    -- variable declaration
    tableName   text;
    query       text;
begin

    tableName := 'FacultyTicketTable__' || new.insID::text;
    query := 'CREATE TABLE ' || tableName;
    query := query || '
        (
            studentID INTEGER NOT NULL,
            studentTicketID INTEGER NOT NULL,
            facultyVerdict BOOLEAN,
            BatchAdvisorVerdict BOOLEAN,
            DeanAcademicsOfficeVerdict BOOLEAN,
            PRIMARY KEY(studentID, studentTicketID)
        );';
    
    EXECUTE query; 
    return new;

end; $$; 
/* ************************************************************************ */


/* Creating BatchAdvisor through Trigger on insert in Department */
CREATE TRIGGER postInsertingDepartment
AFTER INSERT ON Department 
For each STATEMENT 
EXECUTE PROCEDURE postInsertingDepartment_trigger_function();

CREATE or replace FUNCTION postInsertingDepartment_trigger_function(
)
returns TRIGGER
language plpgsql SECURITY DEFINER
as $$
declare
    tableName   text;
    query       text;
begin
    tableName := 'BatchAdvisor_' || new.deptID::text;
    query := 'CREATE TABLE ' || tableName || '
        (
            insID INTEGER,
            deptID INTEGER NOT NULL,
            PRIMARY KEY(deptID)
        );';
    EXECUTE query; 

    query := 'INSERT INTO ' || tableName || '(insID, deptID) values('||NULL||','||new.deptID||')';
    EXECUTE query;

    tableName := 'BatchAdvisorTicketTable_' || new.deptID::text;
    query := 'CREATE TABLE ' || tableName || '
        (
            studentID INTEGER NOT NULL,
            studentTicketID INTEGER NOT NULL,
            facultyVerdict BOOLEAN,
            BatchAdvisorVerdict BOOLEAN,
            DeanAcademicsOfficeVerdict BOOLEAN,
            PRIMARY KEY(studentID, studentTicketID)
        );';
    EXECUTE query; 

    return new;
end; $$; 
/* ************************************************************************ */





































CREATE TRIGGER InsertInFacultyTicketTable
after insert on Student 
For each STATEMENT 
EXECUTE PROCEDURE InsertInFacultyTicketTable_trigger_function(
    
);

create or replace function InsertInFacultyTicketTable_trigger_function(
    
)
    return return_type 
    language plpgsql
as $$
declare
    --variable declaration
begin 
    --logic
end; $$;



