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


/* Registering student */
create or replace procedure RegisterStudent(
    IN _studentID INTEGER,
    IN _courseID INTEGER,
    IN _semester INTEGER,
    IN _year INTEGER
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
    
begin
    prevPrevCredit:=-1
    prevCredit:=-1

    select sum(C) into currentCredit
    from tableName, CourseCatalogue
    where tableName.courseID=CourseCatalogue.courseID and tableName.semester=_semester;

    -- Credit of the course that we are currently enrolling in
    select C into courseCredit
    from CourseCatalogue
    where CourseCatalogue.courseId=_courseID;

    currentCredit:=currentCredit+ courseCredit;

    
    -- check 1.25 rule

    
    tableName:= 'Transcript_' || _studentID::text;

    
    select sum(C) into prevCredit
    from tableName, CourseCatalogue
    where tableName.courseID=CourseCatalogue.courseID and tableName.semester=_semester-1;

    select sum(C) into prevPrevCredit
    from tableName, CourseCatalogue
    where tableName.courseID=CourseCatalogue.courseID and tableName.semester=_semester-2;

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



    -- check if there is a clash timeslot 

    -- check course cgpa requirement



end; $$; 


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