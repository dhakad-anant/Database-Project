/* insert into Course Offering Table */
create or replace procedure offerCourse(
    IN _courseID INTEGER, 
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _cgpa NUMERIC(4, 2),
    IN _insID INTEGER,
    IN slotName VARCHAR(20),
    IN list_batches INTEGER[]
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

    -- check if this course offering already exists or not
    SELECT count(*) INTO courseOfferingExists
    FROM CourseOffering
    WHERE CourseOffering.courseID=_courseID AND CourseOffering.semester=_semester AND CourseOffering.year=_year AND CourseOffering.cgpa=_cgpa;

    if courseOfferingExists=0 then 
        INSERT INTO CourseOffering(courseID, semester, year, cgpaRequired) VALUES(_courseID, _semester, _year, _cgpa);
    
        -- Finding the courseOffering ID
        SELECT CouseOffering.courseOfferingID INTO courseOfferingID
        FROM CourseOffering
        WHERE CourseOffering.courseID=_courseID AND CourseOffering.semester=_semester AND CourseOffering.year=_year AND CourseOffering.cgpa=_cgpa;

        foreach batch IN ARRAY list_batches LOOP
            INSERT INTO BatchesAllowed(CourseOfferingID,batch) VALUES(courseOfferingID,batch);
        end loop;
    end if;

    -- Finding the timeslotId
    select timeSlotID into allotedTimeSlotID
    from TimeSlot 
    where TimeSlot.slotName = slotName;

    if allotedTimeSlotID = -1 then 
        raise notice 'TimeSlot does not exist!!!';
        return;
    end if;
    -- Check if there is a similar entry into the teaches table or not
    select count(*) into teachesExists
    from Teaches
    where Teaches.courseID=_courseID and Teaches.semester=_semester and Teaches.year=_year and Teaches.cgpa=_cgpa and Teaches.insID=_insID and Teaches.timeSlotID=allotedTimeSlotID;

    if teachesExists<>0 then
        raise notice 'Course offering already exists!!!';
        return;
    end if;

    call InsertIntoTeaches(_insID,_courseID,_semester,_year,allotedTimeSlotID);
end; $$;
/* ********************************************************************** */


/* insert into teaches */
create or replace procedure InsertIntoTeaches(
    IN _insID INTEGER,
    IN _courseID INTEGER, 
    -- IN _sectionID INTEGER,
    IN _semester INTEGER,
    IN _year INTEGER,
    -- IN slotName VARCHAR(20)
    IN allotedTimeSlotID INTEGER;
)
language plpgsql
as $$
declare
    -- cnt INTEGER = 0;
    -- allotedTimeSlotID INTEGER = -1;
BEGIN   
    -- select count(*) into cnt 
    -- from CourseOffering 
    -- where CourseOffering.courseID = _courseID AND
    --     CourseOffering.semester = _semester AND
    --     CourseOffering.year = _year;

    -- if cnt = 0 then 
    --     raise notice 'Course offering does not exist!!!';
    --     return;
    -- end if;

    -- select timeSlotID into allotedTimeSlotID
    -- from TimeSlot 
    -- where TimeSlot.slotName = slotName;

    -- if allotedTimeSlotID = -1 then 
    --     raise notice 'TimeSlot does not exist!!!';
    --     return;
    -- end if;

    INSERT into Teaches(insID,courseID,semester,year,timeSlotID) 
        values(_insID,_courseID,_semester,_year,allotedTimeSlotID);
END; $$;
/* ********************************************************************** */



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



/* procedure uploading_time-table slots*********************************************************************************************/
create or replace procedure upload_timetable_slots()
language plpgsql
as $$
declare
    filepath    text;
    query    text;
begin
    filepath := '''C:\fordbmsproject\timetable.csv''';
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
create or replace procedure calculate_current_CGPA(IN INT studentID)
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

