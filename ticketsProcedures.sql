 
/* ********************************** UPDATE FUNCTIONS START ******************************************************* */
/* stored procedure for a student to raise a ticket for any course (at max one ticket per course offering) */
create or replace procedure raiseTicket(
    IN _studentID INTEGER,
    IN _insID INTEGER,
    IN _courseID INTEGER,
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _timeSlotID INTEGER
)
language plpgsql SECURITY DEFINER
as $$
declare
    tableName text;
    facultyTableName text;
    batchAdvisorTableName text;
    query text;
    cnt INTEGER := 0;
    _studentTicketID INTEGER;
    _deptID INTEGER;
BEGIN
    tableName := 'StudentTicketTable_' || _studentID::text;
    
    query =  'select count(*) 
                from '|| tableName ||'
                    where insID = $1 and
                    courseID = $2 and
                    semester = $3 and
                    year = $4 and
                    timeSlotID = $5';

    for cnt in EXECUTE query using _insID, _courseID, _semester, _year, _timeSlotID loop 
        exit;
    end loop;
    if cnt != 0 then 
        raise notice 'Ticket is already raised !!!';
        return;
    end if;


    /* inserting into Student Ticket Table */
    query := 'INSERT INTO ' || tableName || '(insID,courseID,semester,year,timeSlotID,facultyVerdict,batchAdvisorVerdict,deanAcademicsOfficeVerdict) values('||_insID||','||_courseID||','||_semester||','||_year||','||_timeSlotID||',NULL,NULL,NULL)';

    EXECUTE query;

    query =  'select ticketID
                from '|| tableName ||'
                    where insID = $1 and
                    courseID = $2 and
                    semester = $3 and
                    year = $4 and
                    timeSlotID = $5';

    for _studentTicketID in EXECUTE query using _insID, _courseID, _semester, _year, _timeSlotID loop 
        exit;
    end loop;

    /* inserting into Faculty Ticket Table */
    facultyTableName := 'FacultyTicketTable_' || _insID::text;
    query := 'INSERT INTO ' || facultyTableName || '(studentID, studentTicketID,facultyVerdict,batchAdvisorVerdict,deanAcademicsOfficeVerdict) VALUES('||_studentID||','||_studentTicketID||',NULL,NULL,NULL)';
    EXECUTE query;

    /* inserting into Batch Advisor Ticket Table */
    -- getting student's department ID
    select Student.deptID into _deptID from Student where Student.studentID = _studentID;    
    
    batchAdvisorTableName := 'BatchAdvisorTicketTable_' || _deptID::text;
    query := 'INSERT INTO ' || batchAdvisorTableName || '(studentID, studentTicketID,facultyVerdict,batchAdvisorVerdict,deanAcademicsOfficeVerdict) VALUES('||_studentID||','||_studentTicketID||',NULL,NULL,NULL)';
    EXECUTE query;


    /* inserting into Dean Ticket Table */
    query := 'INSERT INTO DeanAcademicsOfficeTicketTable(studentID, studentTicketID,facultyVerdict,batchAdvisorVerdict,deanAcademicsOfficeVerdict) VALUES('||_studentID||','||_studentTicketID||',NULL,NULL,NULL)';
    EXECUTE query;
    
END; $$;
/* ************************************************************************************************************************ */


/* stored procedure for the faculty to update its ticket table */
create or replace procedure updateFacultyTicketTable(
    IN _insID INTEGER,
    IN _studentTicketID INTEGER,  
    IN _studentID INTEGER,  
    IN _facultyVerdict BOOLEAN,    
)
language plpgsql
as $$
declare
-- variable declaration
    tableName text;
    query text;
    _deptID INTEGER;
    _validInsID INTEGER;
    _validStudentTicketID INTEGER;
    _validStudent INTEGER;
begin
    /* check for valid instructorID */
    select count(*) into _validInsID
    from Instructor
    where Instructor.insID = _insID;
    if _validInsID = 0 then
        raise notice 'Invalid Instructor ID entered !!!';
        return;
    end if;
    
    /* add checks for valid studentID */
    SELECT count(*) INTO _validStudent
    FROM Student 
    WHERE Student.studentID = _studentID;
    if _validStudent = 0 then
        raise notice 'No such student with the entered student ID exists!';
        return;
    end if;
    
    /* add checks for valid student ticket ID */
    tableName:= 'FacultyTicketTable_' || _insID::text;
    query:= 'select count(*) FROM ' || tableName ||
        ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID
        ' AND ' || tableName|| '.studentID = ' || _studentID;
    
    for _validStudentTicketID in EXECUTE query loop 
        break;
    end loop;
    if _validStudentTicketID = 0 then
        raise notice 'Student Ticket ID does not exist.';
        return;
    end if;
    
    if _facultyVerdict <> 0 and facultyVerdict <> 1 then 
        raise notice 'Invalid faculty verdict as input !!!';
        return;
    end if;

    tableName := 'FacultyTicketTable_' || _insID::text;

    query := 'UPDATE '|| tableName||'
    SET facultyVerdict = ' || _facultyVerdict ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID;

    EXECUTE query;
    
    
    /* Update the verdict of the faculty in the Student Ticket Table */
    tableName:= 'StudentTicketTable_'|| _studentID::text;
    query := 'UPDATE '|| tableName||'
    SET facultyVerdict = ' || _facultyVerdict ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID;
    EXECUTE query;

    -- Finding the department of the student
    select Student.deptID into _deptID
    from Student
    where Student.studentID = _studentID;
    /* Update the verdict of the faculty in the BatchAdvisor Ticket Table */
    tableName:= 'BatchAdvisorTicketTable_' || _deptID::text;
    query := 'UPDATE '|| tableName ||'
    SET facultyVerdict = ' || _facultyVerdict ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID 
    ' AND ' || tableName|| '.studentID = ' || _studentID;
    EXECUTE query;

    /* Update the verdict of the faculty in the DeanAcademicsOffice Ticket Table */
    tableName:= 'DeanAcademicsOfficeTicketTable';
    query := 'UPDATE '|| tableName||'
    SET facultyVerdict = ' || _facultyVerdict ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID 
    ' AND ' || tableName|| '.studentID = ' || _studentID;
    EXECUTE query;
 
end; $$;
/* ************************************************************************************************************************ */

/* Stored procedure to update the ticket table of the batch advisor */
create or replace procedure updateBatchAdvisorTicketTable(
    IN _deptName VARCHAR(20),
    IN _studentTicketID INTEGER,  
    IN _studentID INTEGER,  
    IN _batchAdvisorVerdict BOOLEAN,    
)
language plpgsql
as $$
declare
    tableName text;
    query text;
    _insID INTEGER;
    _studentDeptID INTEGER;
    _deptID INTEGER;
    _validStudentTicketID INTEGER;
    _validStudent INTEGER;
begin
    /* find the department ID from the deptName. Checks added for invalid department names */
    _deptID := -1;
    select Department.deptID into _deptID 
    from Department 
    where Department.deptName = _deptName; 
    if _deptID = -1 then
        raise notice 'Incorrect Deparment Name entered!';
        return;
    end if;
    
    /* add checks for valid studentID */
    SELECT count(*) INTO _validStudent
    FROM Student 
    WHERE Student.studentID = _studentID;
    if _validStudent = 0 then
        raise notice 'No such student with the entered student ID exists!';
        return;
    end if;

    /* add checks for valid student ticket ID */
    tableName:= 'BatchAdvisorTicketTable_' || _deptID::text;
    query:= 'SELECT count(*) FROM ' || tableName ||
        ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID
        ' AND ' || tableName|| '.studentID = ' || _studentID;
    
    for _validStudentTicketID in EXECUTE query loop 
        break;
    end loop;

    if _validStudentTicketID = 0 then
        raise notice 'Student Ticket ID does not exist.';
        return;
    end if;
    
    /* check whether the student department is same as the batch advisor's department */
    select Student.DeptID into _studentDeptID
    from Student
    where Student.studentID = _studentID;
    if _studentDeptID <> _deptID then 
        raise notice 'The student department does not match with the faculty advisor department !!!';
        return;
    end if;

    /* The batch advisor verdict should either be 0 or 1 as it is of boolean type */
    if _batchAdvisorVerdict <> 0 and _batchAdvisorVerdict <> 1 then 
        raise notice 'Invalid Batch Advisor verdict as input !!!';
        return;
    end if;

    /* Update the verdict of the faculty in the BatchAdvisor Ticket Table */
    tableName:= 'BatchAdvisorTicketTable_' || _deptID::text;
    query := 'UPDATE '|| tableName ||'
    SET batchAdvisorVerdict = ' || _batchAdvisorVerdict ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID 
    ' AND' || tableName|| '.studentID = ' || _studentID;
    EXECUTE query;
    

    /* Update the verdict of the batch advisor in the Faculty Ticket Table */
    -- Finding the instructor ID first
    tableName := 'StudentTicketTable_' || _studentID::text;
    query := 'SELECT '||tableName||  '.insID FROM '|| tableName ||
    ' WHERE '||tableName||'.studentTicketID = '||_studentTicketID||' and '||tableName||'.studentID = '||_studentID;

    for _insID in EXECUTE query loop 
        break;
    end loop;
    

    tableName := 'FacultyTicketTable_' || _insID::text;
    query := 'UPDATE '|| tableName||'
    SET batchAdvisorVerdict = ' || _batchAdvisorVerdict ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID
    ' AND ' || tableName|| '.studentID = ' || _studentID;
    EXECUTE query;


    /* Update the verdict of the batch advisor in the DeanAcademicsOffice Ticket Table */
    tableName:= 'DeanAcademicsOfficeTicketTable';
    query := 'UPDATE '|| tableName ||'
    SET batchAdvisorVerdict = ' || _batchAdvisorVerdict ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID 
    ' AND ' || tableName|| '.studentID = ' || _studentID;
    EXECUTE query;
    

    /* Update the verdict of the batch advisor in the Student Ticket Table */
    tableName:= 'StudentTicketTable_'|| _studentID::text;
    query := 'UPDATE '|| tableName||'
    SET batchAdvisorVerdict = ' || _batchAdvisorVerdict ||
    ' wHERE '|| tableName||'.studentTicketID = ' || _studentTicketID;
    EXECUTE query; 

end; $$;

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
end; $$;
/* ********************************** UPDATE FUNCTIONS END ******************************************************* */


/* ********************************** VIEW FUNCTIONS START******************************************************* */


/* Prints all the tickets from the Student Ticket Table for which the DeanAcademicsOffice Verdict is pending */
create or replace procedure viewStudentTicketTable(
    IN _studentID INTEGER
)
language plpgsql
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
/* ************************************************************************************************************************ */


/* Shows only the pending tickets of the Faculty Ticket Table */
create or replace procedure viewFacultyTicketTable(
    IN _insID INTEGER
)
language plpgsql
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
/* ************************************************************************************************************************ */

/* Shows only the pending tickets of the Batch Advisor Ticket Table */
create or replace procedure viewBatchAdvisorTicketTable(
    IN _deptName VARCHAR(20),
)
language plpgsql
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
/* ************************************************************************************************************************ */

/* Shows only the pending tickets of the DeanAcademicsOffice Ticket Table */
create or replace procedure viewDeanAcademicsOfficeTicketTable()
language plpgsql
as $$
declare
begin
    EXECUTE (select * from DeanAcademicsOfficeTicketTable
    where deanAcademicsOfficeVerdict = NULL);
end; $$;
/* ************************************************************************************************************************ */
