/* insert into teaches */
create [or replace] procedure InsertIntoTeaches(
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

