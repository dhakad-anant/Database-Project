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
    tableName text;
    prevCredit Numeric(4,2)r;
    prevPrevCredit Numeric(4,2)r;
    averageCredits Numeric(10,2);
    maxCreditsAllowed Numeric(10,2);
    currentCredit Numeric(4,2);
    courseCredit Numeric(4,2);
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
begin

    -- Computing the Course Id
    _courseID:=-1
    select courseID into _courseID
    from CourseCatalogue
    where CourseCatalogue.courseCode = _courseCode;

    if _courseID=-1 then 
        raise notice 'Course Does not Exist!'
        return;
    end if;

    --  Computing the Instructor Id
    _insId:=-1;
    select Instructor.insId into _insId
    from Instructor
    where Instructor.insName=_insName;

    if _insId= -1 then
        raise notice 'Instructor does not exist!'
        return;
    end if;


    SELECT sum(CourseCatalogue.C) INTO currentCredit
    from tableName, CourseCatalogue
    where tableName.courseID=CourseCatalogue.courseID and tableName.semester=_semester;

    -- Credit of the course that we are currently enrolling in
    SELECT CourseCatalogue.C INTO courseCredit
    from CourseCatalogue
    where CourseCatalogue.courseId=_courseID;

    currentCredit:=currentCredit+ courseCredit;

    -- check 1.25 rule
    tableName:= 'Transcript_' || _studentID::text;

    prevCredit:=-1
    SELECT sum(CourseCatalogue.C) INTO prevCredit
    from tableName, CourseCatalogue
    where tableName.courseID=CourseCatalogue.courseID and
     (
        (tableName.year = _year - 1 and tableName.semester = 2 and _semester = 1)
                                    OR 
        (tableName.year = _year and tableName.semester = 1 and _semester = 2) 
    );

    prevPrevCredit:=-1
    SELECT sum(CourseCatalogue.C) INTO prevPrevCredit
    from tableName, CourseCatalogue
    where tableName.courseID=CourseCatalogue.courseID and tableName.semester=_semester and tableName.year = _year -1;

    if prevCredit=-1 then
        maxCreditsAllowed:=18        
    else if prevPrevCredit =-1 then
        maxCreditsAllowed:=18.5
    else 
        averageCredits:= (prevCredit + prevPrevCredit)/2;
        maxCreditsAllowed:= averageCredits*1.25;
    end if;

    if currentCredit> maxCreditsAllowed then 
        raise notice  'Credit Limit Reached!';
        return;
    end if;



    -- check if he/she fullfills all preReqs 

    SELECT count(*) INTO totalPreRequisite
    from PreRequisite
    where PreRequisite.courseId=_courseID;

    SELECT count(*) INTO totalPreRequisiteSatisfied
    from tableName, PreRequisite
    where PreRequisite.courseID=_courseID and PreRequisite.preReqCourseID =tableName.courseId and grade<>'F' and grade <> NULL and tableName.semester<>_semester and tableName.year<>_year;

    if totalPreRequisite<>totalPreRequisiteSatisfied then
        raise notice 'All PreRequisite not Satisfied!'
        return;
    end if;

    -- check if there is a clash timeslot 

    -- If time slot exists or not
    _timeSlotID:=-1;
    select TimeSlot.timeSlotID into _timeSlotID 
    from TimeSlot
    where TimeSlot.slotName=_slotName;

    if _timeSlotID = -1 then
        raise notice 'Time SLot does not exist'
        return;
    end if;

    -- Checking for clashes in timeSlot
    select count(*) into totalClashes
    from tableName, Teaches
    where tableName.courseID = Teaches.courseID and tableName.year= Teaches.year and tableName.semester=teaches.semester and tableName.semester=_semester and tableName.year= _year and teaches.insID=_insId and teaches.timeSlotID= _timeSlotID;
    
    if totalClashes<>0 then 
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

end; $$; 
/* ----------------------------------------------------------- */

/* 
-- getting student info 
select * into studentInfo from student where student.studentID = studentID;

If semester-2 >= 0 then
select sum(credit) into prevprevCredit
from Btech
where Btech.semester = semester -2;
Else 
	// write assumption
	Prevprev = 18;
End if ;

select sum(credit) into prevCredit
from Btech
where Btech.semester = semester -1;

select sum(credit) into currentCredit
from Btech
where Btech.semester = semester;

currentCredit := currentCredit + courseCredit;

if currentCredit > 1.25/2 * (prevprevCredit + prevCredit) then
	raise error ‘Credit limit exceeded bro! Bs kr’;
*/


/* g */
create [or replace] procedure raiseTicket(
    IN _studentID INTEGER,
    IN _insID INTEGER,
    IN _courseID INTEGER,
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _courseID INTEGER,
    IN _timeSlotID INTEGER
)
language plpgsql
as $$
declare
    tableName text;
    facultyTableName text;
    batchAdvisorTableName text;
    tableName text;
    query_expression text;
    query text;
    cnt INTEGER := 0;
    _studentTicketID INTEGER;
BEGIN
    tableName := 'StudentTicketTable_' || _studentID::text;
    
    query_expression =  'select count(*) 
                        from '|| tableName ||'
                         where insID = $1 and
                            courseID = $2 and
                            semester = $3 and
                            year = $4 and
                            timeSlotID = $5';

    for cnt in EXECUTE query_expression using _insID, _courseID, _semester, _year, _timeSlotID loop 
        break;
    end loop;
    
    if cnt != 0 then 
        raise notice 'Ticket is already raised!!';
        return;
    end if;

    /* inserting into student ticket table */
    query := 'insert into ' || tableName || '(insID,courseID,semester,year,timeSlotID) values('||_insID||','||_courseID||','||_semester||','||_year||','||_timeSlotID||')';

    EXECUTE query;


    query_expression =  'select ticketID
                        from '|| tableName ||'
                         where insID = $1 and
                            courseID = $2 and
                            semester = $3 and
                            year = $4 and
                            timeSlotID = $5';

    for _studentTicketID in EXECUTE query_expression using _insID, _courseID, _semester, _year, _timeSlotID loop 
        break;
    end loop;


    /* inserting into faculty ticket table */
    facultyTableName := 'FacultyTicketTable_' || _insID::text;

    query := 'insert into ' || facultyTableName || '(studentID, studentTicketID) values('||_studentID||','||_studentTicketID||')';

    EXECUTE query;


    /* inserting into dean ticket table */
    query := 'insert into DeanAcademicsOfficeTicketTable(studentID, studentTicketID) values('||_studentID||','||_studentTicketID||')';

    EXECUTE query;
    
END; $$;
/* ************************ */








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
    from ' || tableName || ' where balance != $1 and id != $2';

    for rec in EXECUTE query_expression using cnt, cnt2 loop 
        raise notice '%', rec;
    end loop;
end; $$;

