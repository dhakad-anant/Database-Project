/* Dean sections floats a course in CourseOffering */
create or replace procedure offerCourse(
    IN _courseID INTEGER, 
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _cgpa NUMERIC(4, 2)
)
language plpgsql
as $$
declare
    cnt INTEGER = 0;
begin
    select count(*) into cnt 
    from CourseCatalogue 
    where CourseCatalogue.courseID = _courseID;

    if cnt = 0 then 
        raise notice 'Course not in CourseCatalogue!!!';
        return;
    end if;

    if _cgpa != NULL and (_cgpa > 10.0 or _cgpa < 0) THEN
        raise notice 'Invalid CGPA value!!!';
        return;
    end if;

    INSERT into CourseOffering(courseID, semester, year, cgpaRequired)
        values(_courseID, _semester, _year, _cgpa);
end; $$;
/* ********************************************************************** */


/* insert into teaches */
create or replace procedure InsertIntoTeaches(
    IN _insID INTEGER,
    IN _insID INTEGER,
    IN _courseID INTEGER, 
    IN _sectionID INTEGER,
    IN _semester INTEGER,
    IN _year INTEGER,
    IN slotName VARCHAR(20)
)
language plpgsql
as $$
declare
    cnt INTEGER = 0;
    allotedTimeSlotID INTEGER = -1;
BEGIN   
    select count(*) into cnt 
    from CourseOffering 
    where CourseOffering.courseID = _courseID AND
        CourseOffering.semester = _semester AND
        CourseOffering.year = _year;

    if cnt = 0 then 
        raise notice 'Course offering does not exist!!!';
        return;
    end if;

    select timeSlotID into allotedTimeSlotID
    from TimeSlot 
    where TimeSlot.slotName = slotName;

    if allotedTimeSlotID = -1 then 
        raise notice 'TimeSlot does not exist!!!';
        return;
    end if;

    INSERT into Teaches(insID,courseID,semester,year,timeSlotID) 
        values(_insID,_courseID,_semester,_year,allotedTimeSlotID);
    
END; $$;
/* ********************************************************************** */


/* ----------------------------------------------------------- */
/* Registering student */
create or replace procedure RegisterStudent(
    IN _studentID INTEGER,
    IN _courseCode VARCHAR(10) NOT NULL,
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _insName VARCHAR(50),
    IN _slotName VARCHAR(20)
)
language plpgsql
as $$
declare 
    studentTrancriptTableName text;
    facultyGradeTableName text;
    prevCredit NUMERIC(4,2);
    prevPrevCredit NUMERIC(4,2);
    averageCredits NUMERIC(10,2);
    maxCreditsAllowed NUMERIC(10,2);
    currentCredit NUMERIC(4,2);
    courseCredit NUMERIC(4,2);
    totalPreRequisite INTEGER;
    totalPreRequisiteSatisfied INTEGER;
    clash INTEGER;
    insId INTEGER;
    ifslot INTEGER;
    _timeSlotID INTEGER
    _insId INTEGER;
    totalClashes INTEGER;
    currentCGPA NUMERIC(4,2);
    cgpaRequired NUMERIC(4,2);
    _courseID INTEGER;
    query text;
    _sectionID INTEGER;
begin
    -- Computing the Course Id
    _courseID := -1
    select courseID into _courseID
    from CourseCatalogue
    where CourseCatalogue.courseCode = _courseCode;

    if _courseID = -1 then 
        raise notice 'Course Does not Exist!'
        return;
    end if;

    --  Computing the Instructor Id
    _insId := -1;
    select Instructor.insId into _insId
    from Instructor
    where Instructor.insName=_insName;

    if _insId = -1 then
        raise notice 'Instructor does not exist!'
        return;
    end if;


    -- Fetching the transcript table for each student
    studentTrancriptTableName:= 'Transcript_' || _studentID::text;

    query = 'SELECT sum(CourseCatalogue.C)
            from ' || studentTrancriptTableName || ', CourseCatalogue
            where ' || studentTrancriptTableName ||'.courseID = CourseCatalogue.courseID 
            and ' ||studentTrancriptTableName || '.semester = $1'

    for currentCredit in EXECUTE query using _semester loop 
        break;
    end loop;
    

    -- Credit of the course that we are currently enrolling in
    SELECT CourseCatalogue.C INTO courseCredit
    from CourseCatalogue
    where CourseCatalogue.courseId = _courseID;

    currentCredit := currentCredit+ courseCredit;

    -- check 1.25 rule
    prevCredit:=-1
    query = 'SELECT sum(CourseCatalogue.C)
            from ' || studentTrancriptTableName || ', CourseCatalogue
            where ' || studentTrancriptTableName ||'.courseID = CourseCatalogue.courseID 
            and (
                ('||studentTrancriptTableName||'.year = $1 and '||studentTrancriptTableName||'.semester = 2 and $2 = 1)
                                            OR 
                ('||studentTrancriptTableName||'.year = $3 and '||studentTrancriptTableName||'.semester = 1 and $4 = 2) 
            )';

    for prevCredit in EXECUTE query using _year - 1, _semester, year, _semester  loop 
        break;
    end loop;


    prevPrevCredit:=-1
    query = 'SELECT sum(CourseCatalogue.C)
            from ' || studentTrancriptTableName || ', CourseCatalogue
            where ' || studentTrancriptTableName ||'.courseID = CourseCatalogue.courseID 
            and '||studentTrancriptTableName||'.year = $1 and '||studentTrancriptTableName||'.semester = $2';

    for prevPrevCredit in EXECUTE query using _year - 1, _semester  loop 
        break;
    end loop;

    if prevCredit = -1 then
        maxCreditsAllowed := 18        
    else if prevPrevCredit = -1 then
        maxCreditsAllowed := 18.5
    else 
        averageCredits := (prevCredit + prevPrevCredit)/2;
        maxCreditsAllowed := averageCredits * 1.25;
    end if;

    if currentCredit > maxCreditsAllowed then 
        raise notice  'Credit Limit Exceeding !!!';
        return;
    end if;


    -- check if he/she fullfills all preReqs 
    SELECT count(*) INTO totalPreRequisite
    from PreRequisite
    where PreRequisite.courseId = _courseID;

    query = 'SELECT count(*)
            from ' || studentTrancriptTableName || ', PreRequisite
            where PreRequisite.courseID = $1 
            and PreRequisite.preReqCourseID = ' ||studentTrancriptTableName||'.courseId 
            and grade<>'F' and grade <> NULL 
            and '||studentTrancriptTableName||'.semester <> $2 
            and '||studentTrancriptTableName||'.year <> $3';

    for totalPreRequisiteSatisfied in EXECUTE query using _courseID, _semester, _year loop 
        break;
    end loop;

    if totalPreRequisite <> totalPreRequisiteSatisfied then
        raise notice 'All PreRequisite not Satisfied!'
        return;
    end if;

 

    -- If time slot exists or not
    _timeSlotID := -1;
    select TimeSlot.timeSlotID into _timeSlotID 
    from TimeSlot
    where TimeSlot.slotName = _slotName;
    if _timeSlotID = -1 then
        raise notice 'Entered Time SLot does not exist !!!'
        return;
    end if;
    -- Checking for clashes in timeSlot    
    query = 'SELECT count(*)
            from ' || studentTrancriptTableName || ', Teaches
            where '||studentTrancriptTableName||'.courseID = Teaches.courseID 
            and '||studentTrancriptTableName||'.year = Teaches.year 
            and '||studentTrancriptTableName||'.semester = Teaches.semester 
            and '||studentTrancriptTableName||'.semester = $1 
            and '||studentTrancriptTableName||'.year = $2
            and teaches.insID = $3 
            and teaches.timeSlotID= $4';

    for totalClashes in EXECUTE query using _semester, _year, _insId, _timeSlotID loop 
        break;
    end loop;
    
    if totalClashes <> 0 then 
        raise notice 'Course with same time slot already enrolled in this semester'
        return;
    end if;


    -- check course cgpa requirement
    -- call function to calculate Current CGPA
    -- declare this function above this one
    -- currentCGPA:= calculate_current_CGPA(_studentID);
    select CourseOffering.cgpaRequired into cgpaRequired
    from CourseOffering
    where CourseOffering.courseID=_courseID and CourseOffering.semester=_semester and CourseOffering.year=_year;

    if currentCGPA < cgpaRequired then
        raise notice 'CGPA Criteria not Satisfied!'
        return;
    end if;
    
    /* All checks completed */
    SELECT sectionID into _sectionID
    from Teaches
    where Teaches.studentID = _studentID 
        and Teaches.courseID = _courseID 
        and Teaches.semester = _semester 
        and Teaches.year = _year 
        and Teaches.insID = _insId 
        and Teaches.timeSlotID = _timeSlotID;

    facultyGradeTableName := 'FacultyGradeTable_' || _sectionID::text;

    query := 'INSERT INTO ' || facultyGradeTableName ||'(studentID,grade) VALUES ('||_studentID||', NULL)';

    EXECUTE query;

end; $$; 
/* ----------------------------------------------------------- */

/* g */
create or replace procedure raiseTicket(
    IN _studentID INTEGER,
    IN _insID INTEGER,
    IN _courseID INTEGER,
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _timeSlotID INTEGER
)
language plpgsql
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
        break;
    end loop;
    if cnt != 0 then 
        raise notice 'Ticket is already raised !!!';
        return;
    end if;


    /* inserting into student ticket table */
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
        break;
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
/* ************************ */


/* procedure to make a faculty a BatchAdvisor */
create or replace procedure makeBatchAdvisor(
    IN _insID INTEGER,
    IN _deptID INTEGER,
)
language plpgsql
as $$
declare
    tableName text;
begin
-- stored procedure body
    tableName = 'BatchAdvisor_' || new.deptID::text;

    query = 'UPDATE '|| tableName ||' SET insID = '|| _insID ||' where deptID = '||_deptID||';'
    EXECUTE query;
end; $$;
/*****************************************/

/*************************************************************  */
create or replace procedure viewFacultyTicketTable(
    IN _insID INTEGER
)
language plpgsql
as $$
declare
    tableName text;
    query text;
begin
    tableName := 'FacultyTicketTable_' || _insID::text;

    query := 'select * 
              from '||tableName||' 
              where '||tableName||'.facultyVerdict = NULL;';
    EXECUTE query;
end; $$;

create or replace procedure updateFacultyTicketTable(
    IN _insID INTEGER,
    IN _studentTicketID INTEGER,    
    IN _facultyVerdict BOOLEAN,    
)
language plpgsql
as $$
declare
-- variable declaration
    tableName text;
    query text;
begin
-- stored procedure body
    tableName := 'FacultyTicketTable_' || _insID::text;

    query := 'UPDATE '|| tableName||'
    SET facultyVerdict = ' || _facultyVerdict ||'
    where '|| tableName||'.studentTicketID = ' || _studentTicketID;
    
    EXECUTE query;
 
end; $$;
/************************************************************* */


/************************************************************* */
create or replace procedure viewBatchAdvisorTicketTable(
    IN _deptID INTEGER
)
language plpgsql
as $$
declare
    tableName text;
    query text;
begin
    tableName := 'BatchAdvisor_' || _deptID::text;

    query := 'select * 
              from '||tableName||' 
              where '||tableName||'.batchAdvisorVerdict = NULL;';
    EXECUTE query;
end; $$;


create or replace procedure updateBatchAdvisorTicketTable(
    IN _deptID INTEGER,
    IN _studentTicketID INTEGER,    
    IN _batchAdvisorVerdict BOOLEAN,    
)
language plpgsql
as $$
declare
-- variable declaration
    tableName text;
    query text;
begin
-- stored procedure body
    tableName := 'BatchAdvisorTicketTable_' || _deptID::text;

    query := 'UPDATE '|| tableName||'
    SET batchAdvisorVerdict = ' || _batchAdvisorVerdict ||'
    where '|| tableName||'.studentTicketID = ' || _studentTicketID;
    
    EXECUTE query;
 
end; $$;
/************************************************************* */


/************************************************************* */
create or replace procedure viewDeanAcademicsOfficeTicketTable()
language plpgsql
as $$
declare
begin
    EXECUTE (select * from DeanAcademicsOfficeTicketTable
    where deanAcademicsOfficeVerdict = NULL);
end; $$;


create or replace procedure updateDeanAcademicsOfficeTicketTable(
    IN _studentTicketID INTEGER,    
    IN _deanAcademicsOfficeVerdict BOOLEAN,    
)
language plpgsql
as $$
declare
-- variable declaration
    tableName text;
    query text;
begin
-- stored procedure body
    tableName := 'DeanAcademicsOfficeTicketTable';

    query := 'UPDATE '|| tableName||'
    SET deanAcademicsOfficeVerdict = ' || _deanAcademicsOfficeVerdict ||'
    where '|| tableName||'.studentTicketID = ' || _studentTicketID;
    
    EXECUTE query;
 
end; $$;
/************************************************************* */

/************************************************************* */
create or replace procedure viewStudentTicketTable(

)
language plpgsql
as $$
declare
begin
    select * from DeanAcademicsOfficeTicketTable
    where deanAcademicsOfficeVerdict = NULL;
end; $$;
/************************************************************* */







/********************  TESTING CODE ********************** /

/* running a query with dynamic tableName */
create or replace procedure testtest(
    tableName text
)
language plpgsql
as $$
declare
    query_expression text;
    rec record;
    cnt INTEGER;
    cnt2 INTEGER;
begin
    cnt := 1;
    cnt2 := 3;
    -- query_expression := 'select (id, name, balance) 
    -- from $1';
    query_expression := 'select id, name, balance
    from ' || tableName || ' where '||tableName||'.balance != $1 and '||tableName||'.id != $2';

    for rec in EXECUTE query_expression using cnt, cnt2 loop 
        raise notice '%', rec;
    end loop;
end; $$;

