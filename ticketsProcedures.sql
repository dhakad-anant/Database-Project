 
/* ********************************** UPDATE FUNCTIONS START ******************************************************* */



/* ************************************************************************************************************************ */


create or replace procedure updateDeanAcademicsOfficeTicketTable(
    IN _studentTicketID INTEGER,    
    IN _studentID INTEGER,    
    IN _deanAcademicsOfficeVerdict BOOLEAN,    
)
language plpgsql
as $$
declare
    tableName text;
    query text;
    _deptID INTEGER;
    _insID INTEGER;
    _validStudent INTEGER;
    _validStudentTicketID INTEGER;

    facultyGradeTableName, studentTrancriptTableName text;
    _courseID integer; /* to find */
    _sectionID integer; /* to find */
    _semester integer; /* to find */
    _year integer; /* to find */
    _timeSlotID integer; /* to find */
begin
    /* Checks for valid studentID */
    SELECT count(*) INTO _validStudent
    FROM Student 
    WHERE Student.studentID = _studentID;
    if _validStudent = 0 then
        raise notice 'No such student with the entered student ID exists!';
        return;
    end if;

     /* find the department ID from the student Table */
    select Student.deptID into _deptID 
    from Student 
    where Student.studentID = _studentID; 

    /* add checks for valid student ticket ID */
    select count(*) into _validStudentTicketID
    from DeanAcademicsOfficeTicketTable
    where DeanAcademicsOfficeTicketTable.studentTicketID = _studentTicketID
    and DeanAcademicsOfficeTicketTable.studentID = _studentID;
    if _validStudentTicketID = 0 then
        raise notice 'Student Ticket ID does not exist in the Deans Ticket Table !!!';
        return;

    /* The DeanAcademicsOffice verdict should either be 0 or 1 as it is of boolean type */
    if _deanAcademicsOfficeVerdict <> 0 and _deanAcademicsOfficeVerdict <> 1 then 
        raise notice 'Invalid DeanAcademicsOffice verdict as input !!!';
        return;
    end if;

    /* Updating the verdict in the DeanAcademicsOfficeTicketTable */
    tableName := 'DeanAcademicsOfficeTicketTable';
    query := 'UPDATE '|| tableName||'
    SET deanAcademicsOfficeVerdict = ' || _deanAcademicsOfficeVerdict ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID ||
    ' AND ' || tableName|| '.studentID = ' || _studentID;
    EXECUTE query;


    /* Update the verdict in the Student Ticket Table */
    tableName:= 'StudentTicketTable_'|| _studentID::text;
    query := 'UPDATE '|| tableName||'
    SET deanAcademicsOfficeVerdict = ' || _deanAcademicsOfficeVerdict ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID;
    EXECUTE query; 


    /* Update the verdict in the Faculty Ticket Table */
    -- Finding the instructor ID first
    tableName := 'StudentTicketTable_' || _studentID::text;
    query := 'SELECT '||tableName||'.insID  
    FROM '|| tableName ||
    ' WHERE '||tableName||'.studentTicketID = '||_studentTicketID||' and '||tableName||'.studentID = '||_studentID;
    for _insID in EXECUTE query loop 
        break;
    end loop;
    tableName := 'FacultyTicketTable_' || _insID::text;
    query := 'UPDATE '|| tableName||'
    SET deanAcademicsOfficeVerdict = ' || _deanAcademicsOfficeVerdict ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID
    ' AND ' || tableName|| '.studentID = ' || _studentID;
    EXECUTE query;


    /* Update the verdict in the BatchAdvisor Ticket Table */
    tableName := 'BatchAdvisorTicketTable_' || _deptID::text;
    query := 'UPDATE '|| tableName ||'
    SET deanAcademicsOfficeVerdict = ' || _deanAcademicsOfficeVerdict ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID 
    ' AND ' || tableName|| '.studentID = ' || _studentID;
    EXECUTE query;


    -- If the verdict of Dean Academics office is yes, register the student for that given course
    if _deanAcademicsOfficeVerdict then 

        tableName := 'StudentTicketTable_' || _studentID::text;

        query := 'select ('||tableName||'.courseID, '||tableName||'.semester, '||tableName||'.year, '||tableName||'.timeSlotID) 
                  from '||tableName||' 
                  where '||tableName||'.ticketID = '||_studentTicketID||'';

        for (_courseID, _semester, _year, _timeSlotID) in query loop 
            exit;
        end loop;

        /* inserting into student Transcript Table */
        studentTrancriptTableName := 'Transcript_' || _studentID::text;
        query := 'INSERT INTO ' || studentTrancriptTableName ||'(courseID, semester, year, timeSlotID) 
        VALUES ('||_courseID::text||','||_semester::text||','||_year::text||','||_timeSlotID::text||')';
        EXECUTE query;

        select Teaches.sectionID into _sectionID
        from Teaches 
        where Teaches.insID = _insID and
            Teaches.courseID = _courseID and
            Teaches.semester = _semester and
            Teaches.year = _year and
            Teaches.timeSlotID = _timeSlotID;

        /* inserting into FacultyGradeTable_{_sectionID} */
        facultyGradeTableName := 'FacultyGradeTable_' || _sectionID::text;
        query := 'INSERT INTO ' || facultyGradeTableName ||'(studentID) VALUES ('||_studentID::text||')';
        EXECUTE query;
    end if;
end; $$;
/* ********************************** UPDATE FUNCTIONS END ******************************************************* */


/* ********************************** VIEW FUNCTIONS START******************************************************* */


/* Prints all the tickets from the Student Ticket Table for which the DeanAcademicsOffice Verdict is pending */
create or replace procedure viewStudentTicketTable(
    IN _studentID INTEGER
)
language plpgsql SECURITY INVOKER
as $$
declare
    tableName text;
    query text;
    _validStudent INTEGER;
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
    
    EXECUTE query;
end; $$;
REVOKE ALL ON PROCEDURE viewStudentTicketTable FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE viewStudentTicketTable TO Students;
/* ************************************************************************************************************************ */

/* Shows only the pending tickets of the Faculty Ticket Table */
create or replace procedure viewFacultyTicketTable(
    IN _insID INTEGER
)
language plpgsql SECURITY INVOKER
as $$
declare
    tableName text;
    query text;
    _validInsID INTEGER;
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
              where '||tableName||'.facultyVerdict = NULL;';
    EXECUTE query;
end; $$;
REVOKE ALL ON PROCEDURE viewFacultyTicketTable FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE viewFacultyTicketTable TO FACULTY;
/* ************************************************************************************************************************ */

/* Shows only the pending tickets of the Batch Advisor Ticket Table */
create or replace procedure viewBatchAdvisorTicketTable(
    IN _deptName VARCHAR(20)
)
language plpgsql SECURITY INVOKER
as $$
declare
    tableName text;
    query text;
    _deptID INTEGER;
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

    tableName := 'BatchAdvisor_' || _deptID::text;

    query := 'select * 
              from '||tableName||' 
              where '||tableName||'.batchAdvisorVerdict = NULL;';
    EXECUTE query;
end; $$;
REVOKE ALL ON PROCEDURE viewBatchAdvisorTicketTable FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE viewBatchAdvisorTicketTable TO BatchAdvisor;
/* ************************************************************************************************************************ */

/* Shows only the pending tickets of the DeanAcademicsOffice Ticket Table */
create or replace procedure viewDeanAcademicsOfficeTicketTable()
language plpgsql SECURITY INVOKER
as $$
declare
begin
    EXECUTE (select * from DeanAcademicsOfficeTicketTable
    where deanAcademicsOfficeVerdict = NULL);
end; $$;
REVOKE ALL ON PROCEDURE viewDeanAcademicsOfficeTicketTable FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE viewDeanAcademicsOfficeTicketTable TO DeanAcademicsOffice;
/* ************************************************************************************************************************ */
