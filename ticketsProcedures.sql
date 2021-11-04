 
/* ********************************** UPDATE FUNCTIONS START ******************************************************* */



/* ************************************************************************************************************************ */



/* ********************************** UPDATE FUNCTIONS END ******************************************************* */


/* ********************************** VIEW FUNCTIONS START******************************************************* */


/* Prints all the tickets from the Student Ticket Table for which the DeanAcademicsOffice Verdict is pending */
create or replace function viewStudentTicketTable(
    IN _studentID INTEGER
)
return table(
    insID INTEGER,
    courseID INTEGER,
    semester INTEGER,
    year INTEGER,
    timeSlotID INTEGER,
    ticketID INTEGER, 
    facultyVerdict BOOLEAN,
    batchAdvisorVerdict BOOLEAN,
    deanAcademicsOfficeVerdict BOOLEAN
)
language plpgsql SECURITY INVOKER
as $$
declare
    tableName text;
    query text;
    _validStudent INTEGER;
    rec record;
begin
    SELECT count(*) INTO _validStudent
    FROM Student 
    WHERE Student.studentID = _studentID;
    if _validStudent = 0 then
        raise notice 'No such student with the entered student ID exists!';
        return;
    end if;
    
    tableName := 'StudentTicketTable_' || _studentID::text;
    
    query := 'select * 
              from '|| tableName ||' 
              where '||tableName||'.deanAcademicsOfficeVerdict = NULL;';
    
    
    for rec in query loop 
        insID := rec.insID;
        courseID := rec.courseID;
        semester := rec.semester;
        year := rec.year;
        timeSlotID := rec.timeSlotID;
        ticketID := rec.ticketID;
        facultyVerdict := rec.facultyVerdict;
        BatchAdvisorVerdict := rec.BatchAdvisorVerdict;
        DeanAcademicsOfficeVerdict := rec.DeanAcademicsOfficeVerdict;
        return next;
    end loop;
end; $$;
REVOKE ALL ON PROCEDURE viewStudentTicketTable FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE viewStudentTicketTable TO Students;

SELECT * from viewStudentTicketTable();
/* ************************************************************************************************************************ */


/* Shows only the pending tickets of the Faculty Ticket Table */
create or replace function viewFacultyTicketTable(
    IN _insID INTEGER
)
return table(
    studentID INTEGER,
    studentTicketID INTEGER,
    facultyVerdict BOOLEAN,
    BatchAdvisorVerdict BOOLEAN,
    DeanAcademicsOfficeVerdict BOOLEAN
)
language plpgsql SECURITY INVOKER
as $$
declare
    tableName text;
    query text;
    _validInsID INTEGER;
    rec record;
begin
    /* check for valid instructorID */
    select count(*) into _validInsID
    from Instructor
    where Instructor.insID = _insID;
    if _validInsID = 0 then
        raise notice 'Invalid Instructor ID entered !!!';
        return;
    end if;

    tableName := 'FacultyTicketTable_' || _insID::text;
    /* Only prints the tickets for which the decision has not been given yet */
    query := 'select * 
              from '||tableName||' 
              where '||tableName||'.facultyVerdict is NULL;';
    
    for rec in query loop 
        studentID := rec.studentID;
        studentTicketID := rec.studentTicketID;
        facultyVerdict := rec.facultyVerdict;
        BatchAdvisorVerdict := rec.BatchAdvisorVerdict;
        DeanAcademicsOfficeVerdict := rec.DeanAcademicsOfficeVerdict;
        return next;
    end loop;
end; $$;
REVOKE ALL ON PROCEDURE viewFacultyTicketTable FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE viewFacultyTicketTable TO FACULTY;

SELECT * from viewFacultyTicketTable();
/* ************************************************************************************************************************ */


/* Shows only the pending tickets of the Batch Advisor Ticket Table */
create or replace function viewBatchAdvisorTicketTable(
    IN _deptName VARCHAR(20)
)
return table(
    studentID INTEGER,
    studentTicketID INTEGER,
    facultyVerdict BOOLEAN,
    BatchAdvisorVerdict BOOLEAN,
    DeanAcademicsOfficeVerdict BOOLEAN
)
language plpgsql SECURITY INVOKER
as $$
declare
    tableName text;
    query text;
    _deptID INTEGER;
    rec record;
begin
    /* check if the deptID is valid or not */
    _deptID := -1
    select Department.deptID into _deptID
    from Department
    where Department.deptName = _deptName;
    if _deptID = -1 then
        raise notice 'Invalid Department name entered !!!';
        return;
    end if;

    tableName := 'BatchAdvisorTicketTable_' || _deptID::text;

    query := 'select * 
              from '||tableName||' 
              where '||tableName||'.batchAdvisorVerdict = NULL;';
    
    for rec in query loop 
        studentID := rec.studentID;
        studentTicketID := rec.studentTicketID;
        facultyVerdict := rec.facultyVerdict;
        BatchAdvisorVerdict := rec.BatchAdvisorVerdict;
        DeanAcademicsOfficeVerdict := rec.DeanAcademicsOfficeVerdict;
        return next;
    end loop;
end; $$;
REVOKE ALL ON PROCEDURE viewBatchAdvisorTicketTable FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE viewBatchAdvisorTicketTable TO BatchAdvisor;

SELECT * from viewBatchAdvisorTicketTable();
/* ************************************************************************************************************************ */


/* Shows only the pending tickets of the DeanAcademicsOffice Ticket Table */
create or replace function viewDeanAcademicsOfficeTicketTable()
return table(
        studentID INTEGER,
        studentTicketID INTEGER,
        facultyVerdict BOOLEAN,
        BatchAdvisorVerdict BOOLEAN,
        DeanAcademicsOfficeVerdict BOOLEAN
    )
language plpgsql SECURITY INVOKER
as $$
declare
    rec record;
begin
    for rec in (select * from DeanAcademicsOfficeTicketTable) loop 
        studentID := rec.studentID;
        studentTicketID := rec.studentTicketID;
        facultyVerdict := rec.facultyVerdict;
        BatchAdvisorVerdict := rec.BatchAdvisorVerdict;
        DeanAcademicsOfficeVerdict := rec.DeanAcademicsOfficeVerdict;
        return next;
    end loop;
end; $$;
REVOKE ALL ON PROCEDURE viewDeanAcademicsOfficeTicketTable FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE viewDeanAcademicsOfficeTicketTable TO DeanAcademicsOffice;

SELECT * from viewDeanAcademicsOfficeTicketTable();
/* ************************************************************************************************************************ */
