/* procedure uploading_time-table slots**********************************final**********************************/
create or replace procedure upload_timetable_slots()
language plpgsql
as $$
declare
    filepath    text;
    query    text;
begin
    filepath := '''C:\media\timetable.csv''';
    /* query := '
        COPY persons(first_name, last_name, dob, email)
        FROM 'C:\sampledb\persons.csv'
        DELIMITER ','
        CSV HEADER;
    '; */

    query := 'COPY TimeSlot(timeSlotID, slotName, duration, monday, tuesday, wednesday, thursday, friday) 
              FROM ' || filepath || 
              ' DELIMITER '','' 
              CSV HEADER;';
    EXECUTE QUERY;
end; $$;

-- call upload_timetable_slots();
/* *********************************************************************************************************** */

/* insert into Course Offering Table */
create or replace procedure offerCourse(
    IN _courseID INTEGER, 
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _cgpa NUMERIC(4, 2),
    IN _insID INTEGER,
    IN _slotName VARCHAR(20),
    IN _list_batches INTEGER[]
)
language plpgsql SECURITY DEFINER
as $$
declare
    cnt INTEGER = 0;
    courseOfferingExists INTEGER;
    teachesExists INTEGER;
    allotedTimeSlotID INTEGER = -1;
    batch INTEGER;
    courseOfferingID INTEGER;
begin
    SELECT count(*) INTO cnt 
    FROM CourseCatalogue 
    WHERE CourseCatalogue.courseID = _courseID;

    IF cnt = 0 THEN 
        raise notice 'Course not in CourseCatalogue!!!';
        return;
    END IF;

    IF _cgpa != NULL AND (_cgpa > 10.0 or _cgpa < 0.0) THEN
        raise notice 'Invalid CGPA value!!!';
        return;
    END IF;

    -- Finding the timeslotId
    SELECT timeSlotID INTO allotedTimeSlotID
    FROM TimeSlot 
    WHERE TimeSlot.slotName = _slotName;

    IF allotedTimeSlotID = -1 THEN 
        raise notice 'TimeSlot does not exist!!!';
        return;
    END IF;

    -- check if this course offering already exists or not
    SELECT count(*) INTO courseOfferingExists
    FROM CourseOffering
    WHERE CourseOffering.courseID=_courseID AND CourseOffering.semester=_semester AND CourseOffering.year=_year AND CourseOffering.cgpa=_cgpa AND CourseOffering.timeSlotID=allotedTimeSlotID;

    IF courseOfferingExists=0 THEN 
        INSERT INTO CourseOffering(courseID, semester, year, cgpaRequired,timeSlotID) VALUES(_courseID, _semester, _year, _cgpa,allotedTimeSlotID);
    
        -- Finding the courseOffering ID
        SELECT CouseOffering.courseOfferingID INTO courseOfferingID
        FROM CourseOffering
        WHERE CourseOffering.courseID=_courseID AND CourseOffering.semester=_semester AND CourseOffering.year=_year AND CourseOffering.cgpa=_cgpa AND CourseOffering.timeSlotID=allotedTimeSlotID;

        FOREACH batch IN ARRAY _list_batches LOOP
            INSERT INTO BatchesAllowed(CourseOfferingID,batch) VALUES(courseOfferingID,batch);
        END LOOP;
    END IF;

    -- Check if there is a similar entry into the teaches table or not
    SELECT count(*) INTO teachesExists
    FROM Teaches
    WHERE Teaches.courseID=_courseID AND Teaches.semester=_semester AND Teaches.year=_year AND Teaches.cgpa=_cgpa AND Teaches.insID=_insID AND Teaches.timeSlotID=allotedTimeSlotID;

    IF teachesExists<>0 THEN
        raise notice 'Course offering already exists!!!';
        return;
    END IF;

    CALL InsertIntoTeaches(_insID,_courseID,_semester,_year,allotedTimeSlotID);
END; $$;
/* ********************************************************************** */

/* insert into teaches */
CREATE OR replace PROCEDURE InsertIntoTeaches(
    IN _insID INTEGER,
    IN _courseID INTEGER, 
    IN _semester INTEGER,
    IN _year INTEGER,
    IN allotedTimeSlotID INTEGER
)
language plpgsql SECURITY DEFINER
as $$
declare
BEGIN   
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
language plpgsql SECURITY DEFINER
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
REVOKE ALL 
ON PROCEDURE RegisterStudent
FROM PUBLIC;

GRANT EXECUTE 
ON PROCEDURE RegisterStudent 
TO students;

/* ----------------------------------------------------------- */


/* Procedure the print the Transcript Table (gradesheet) of a student */
create or replace procedure printGradeSheet(
    IN studentID INTEGER
)
language plpgsql
as $$
declare

begin

end; $$;
/****************************************************************************************/


/* Compute the current CGPA of any student************************************************************************/
create or replace procedure calculate_current_CGPA(
    IN studentID INTEGER, 
    INOUT currentCGPA NUMERIC(4,2) 
)
language plpgsql SECURITY DEFINER   
as $$
declare
    transcriptTable text;
    totalCredits    INTEGER := 0;
    numerator       INTEGER := 0;
    rec             record;
    CGPA            NUMERIC := 0.0;
    query           TEXT;
    credits         NUMERIC(4,2);
    val             INTEGER;
begin
    transcriptTable := 'Transcript_' || studentID::text;

    query := 'SELECT CourseCatalogue.C, GradeMapping.val
            FROM '||transcriptTable||', CourseOffering, GradeMapping, CourseCatalogue
            WHERE '||transcriptTable||'.courseID = CourseOffering.courseID AND 
            '||transcriptTable||'.year = CourseOffering.year AND 
            '||transcriptTable||'.semester = CourseOffering.semester AND 
            '||transcriptTable||'.grade <> ''F'' AND '||transcriptTable||'.grade IS NOT NULL AND 
            '||transcriptTable||'.grade = GradeMapping.grade AND 
            '||transcriptTable||'.timeSlotID =  CourseOffering.timeSlotID AND 
            CourseCatalogue.courseID = CourseOffering.courseID';

    for credits, val in EXECUTE query loop
        totalCredits := totalCredits + credits;
        numerator := numerator + (val * credits);
    end loop;
    
    CGPA := (numerator/totalCredits)::NUMERIC(4, 2);

    currentCGPA := CGPA;
    
    raise notice 'CGPA for studentID % is %',studentID,CGPA;
end; $$;

create or replace procedure print_current_CGPA(
    IN studentID INTEGER
)
language plpgsql SECURITY DEFINER   
as $$
declare
    currentCGPA NUMERIC(4, 2) := 0;
begin
    call calculate_current_CGPA(studentID, currentCGPA)
    raise notice 'CGPA for studentID % is %',studentID,currentCGPA;
end; $$;
-- cgpa = (summation{no. of credits x grade_in_that_course})/totalCredits
/****************************************************************************************** */



/* Procedure for uploading grades of a particular (course, semester, year, instructor) */
create or replace procedure uploadCourseGrade()
language plpgsql
as $$
declare

begin

end; $$;
/****************************************************************************************/



/********************  TESTING CODE ****************************************************************************************************** /

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




/* Export INTO a csv file************************************************************************************************ */
create or replace procedure exportTranscript(
    _studentID integer
)
language plpgsql SECURITY INVOKER
as $$
declare
    tableName text;
    _fileName text;
begin
    tableName := 'transcript_' || _studentID::text;
    _fileName := 'ReportStudent_' || _studentID::text;
    call exportTableIntoCSV(tableName, _fileName);
end; $$;

create or replace procedure exportTableIntoCSV(
    tableName text,
    _fileName text
)
language plpgsql SECURITY DEFINER
as $$
declare
    query text;
begin
    query := 'COPY '||tableName||' to ''C:\media\'||_fileName||'.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE query;
end; $$;
/* ************************************************************************************************************ */
