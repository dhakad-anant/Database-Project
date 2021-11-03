create or replace procedure RegisterStudent(
    IN _studentID INTEGER,
    IN _courseCode VARCHAR(10),
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
    _timeSlotID INTEGER;
    _insId INTEGER;
    totalClashes INTEGER;
    currentCGPA NUMERIC(4,2);
    cgpaRequired NUMERIC(4,2);
    _courseID INTEGER;
    query text;
    _sectionID INTEGER;
begin
    -- Computing the Course Id
    _courseID := -1;
    select CourseCatalogue.courseID into _courseID
    from CourseCatalogue
    where CourseCatalogue.courseCode = _courseCode;

    if _courseID = -1 then 
        raise notice 'Course Does not Exist!';
        return;
    end if;

    --  Computing the Instructor Id
    _insId := -1;
    select Instructor.insId into _insId
    from Instructor
    where Instructor.insName=_insName;

    if _insId = -1 then
        raise notice 'Instructor does not exist!';
        return;
    end if;


    -- -- Fetching the transcript table for each student
    studentTrancriptTableName:= 'Transcript_' || _studentID::text;

    query = 'SELECT sum(CourseCatalogue.C)
            FROM ' || studentTrancriptTableName || ', CourseCatalogue
            WHERE ' || studentTrancriptTableName ||'.courseID = CourseCatalogue.courseID 
            AND ' ||studentTrancriptTableName || '.semester = ' || _semester::text;

    FOR currentCredit in EXECUTE query loop 
        exit;
    end loop;
    

    -- -- Credit of the course that we are currently enrolling in
    SELECT CourseCatalogue.C INTO courseCredit
    from CourseCatalogue
    where CourseCatalogue.courseId = _courseID;

    currentCredit := currentCredit+ courseCredit;

    -- check 1.25 rule
    prevCredit:=-1;
    query = 'SELECT sum(CourseCatalogue.C)
            FROM ' || studentTrancriptTableName || ', CourseCatalogue
            WHERE ' || studentTrancriptTableName ||'.courseID = CourseCatalogue.courseID 
            AND (
                ('||studentTrancriptTableName||'.year = $1 and '||studentTrancriptTableName||'.semester = 2 and $2 = 1)
                                            OR 
                ('||studentTrancriptTableName||'.year = $3 and '||studentTrancriptTableName||'.semester = 1 and $4 = 2) 
            )';

    FOR prevCredit IN EXECUTE query using _year - 1, _semester, year, _semester  loop 
        exit;
    end loop;


    prevPrevCredit:=-1;
    query = 'SELECT SUM(CourseCatalogue.C)
            FROM ' || studentTrancriptTableName || ', CourseCatalogue
            WHERE ' || studentTrancriptTableName ||'.courseID = CourseCatalogue.courseID 
            AND '||studentTrancriptTableName||'.year = $1 AND '||studentTrancriptTableName||'.semester = $2';

    for prevPrevCredit in EXECUTE query using _year - 1, _semester  loop 
        exit;
    end loop;

    if prevCredit = -1 then
        maxCreditsAllowed := 18;
    elsif prevPrevCredit = -1 then
        maxCreditsAllowed := 18.5;
    else 
        averageCredits := (prevCredit + prevPrevCredit)/2;
        maxCreditsAllowed := averageCredits * 1.25;
    end if;

    if currentCredit > maxCreditsAllowed then 
        raise notice  'Credit Limit Exceeding !!!';
        return;
    end if;


    -- -- check if he/she fullfills all preReqs 
    SELECT count(*) INTO totalPreRequisite
    FROM PreRequisite
    WHERE PreRequisite.courseId = _courseID;

    query = 'SELECT count(*)
            FROM ' || studentTrancriptTableName || ', PreRequisite
            WHERE PreRequisite.courseID = $1 
            AND PreRequisite.preReqCourseID = ' ||studentTrancriptTableName||'.courseId 
            AND grade<>''F'' and grade IS NOT NULL 
            AND '||studentTrancriptTableName||'.semester <> $2 
            AND '||studentTrancriptTableName||'.year <> $3';

    for totalPreRequisiteSatisfied in EXECUTE query using _courseID, _semester, _year loop 
        exit;
    end loop;

    if totalPreRequisite <> totalPreRequisiteSatisfied then
        raise notice 'All PreRequisite not Satisfied!';
        return;
    end if;

    -- -- If time slot exists or not
    _timeSlotID := -1;
    select TimeSlot.timeSlotID into _timeSlotID 
    from TimeSlot
    where TimeSlot.slotName = _slotName;
    if _timeSlotID = -1 then
        raise notice 'Entered Time SLot does not exist !!!';
        return;
    end if;
    -- -- Checking for clashes in timeSlot    
    query = 'SELECT count(*)
            FROM ' || studentTrancriptTableName || ', Teaches
            WHERE '||studentTrancriptTableName||'.courseID = Teaches.courseID 
            AND '||studentTrancriptTableName||'.year = Teaches.year 
            AND '||studentTrancriptTableName||'.semester = Teaches.semester 
            AND '||studentTrancriptTableName||'.semester = $1 
            AND '||studentTrancriptTableName||'.year = $2
            AND teaches.insID = $3 
            AND teaches.timeSlotID= $4';

    for totalClashes in EXECUTE query using _semester, _year, _insId, _timeSlotID loop 
        exit;
    end loop;
    
    if totalClashes <> 0 then 
        raise notice 'Course with same time slot already enrolled in this semester';
        return;
    end if;


    -- -- check course cgpa requirement
    -- -- call function to calculate Current CGPA
    -- -- declare this function above this one
    -- -- currentCGPA:= calculate_current_CGPA(_studentID);
    -- select CourseOffering.cgpaRequired into cgpaRequired
    -- from CourseOffering
    -- where CourseOffering.courseID=_courseID and CourseOffering.semester=_semester and CourseOffering.year=_year;

    -- if currentCGPA < cgpaRequired then
    --     raise notice 'CGPA Criteria not Satisfied!';
    --     return;
    -- end if;
    
    -- /* All checks completed */
    -- SELECT Teaches.sectionID into _sectionID
    -- FROM Teaches
    -- WHERE Teaches.studentID = _studentID 
    --     AND Teaches.courseID = _courseID 
    --     AND Teaches.semester = _semester 
    --     AND Teaches.year = _year 
    --     AND Teaches.insID = _insId 
    --     AND Teaches.timeSlotID = _timeSlotID;

    -- raise notice 'section Id: %',_sectionID;
    
    -- facultyGradeTableName := 'FacultyGradeTable_' || _sectionID::text;

    -- query = 'INSERT INTO ' || facultyGradeTableName ||'(studentID) VALUES ('||_studentID::text||')';

    -- EXECUTE query;

end; $$; 
drop procedure RegisterStudent;

