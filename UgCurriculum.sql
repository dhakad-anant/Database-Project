create or replace procedure canGraduate(
    IN _studentID  INTEGER;
)
language plpgsql
as $$
declare
    currentCGPA Numeric(4,2);
    deptID INTEGER;
    curriculumID INTEGER;
    batch INTEGER;
    transcriptTable TEXT;
    curriculumList TEXT;
    undoneProgramCore INTEGER;
    undoneProgramElective INTEGER;
    undoneScienceCore INTEGER;
    undoneOpenElective INTEGER;
begin
    -- first find the deptId and batch of the student
    deptID:=-1;
    select Student.deptID into deptID
    from Student
    where Student.studentID=_studentID;

    if deptID=-1 then
        raise notice 'Incorrect student Id!!';
        return;
    end if;

    select Student.batch into batch
    from Student
    where Student.studentID=_studentID;

    -- Check if the student has a minimum of 5 CGPA or not
    call calculate_current_CGPA(_studentID,currentCGPA);
    if currentCGPA<5.0 then
        raise notice 'CGPA criteria not satisfied as per the UG Curriculum!!!';
        return;
    end if;

    -- find the curriculum id of the UG curriculum that the student is enrolled in
    select UGCurriculum.curriculumID into curriculumID
    from UGCurriculum
    where UGCurriculum.deptID=deptID and UGCurriculum.batch=batch;

    -- Curriculum List for currcilumID
    curriculumList:= 'CurriculumList_' || curriculumID::text;

    -- transcript table of the student
    transcriptTable:= 'Transcript_' || _studentID::text;
    
    -- Check if the student has done all the courses mentioned in its program core

    query:= 'SELECT count(*) FROM ' || curriculumList ||
    ' WHERE ' || curriculumList|| '.courseCategory=''Program Core'' AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || ' WHERE grade<>''F'' AND grade<>''NULL'')';

    for undoneProgramCore in EXECUTE query loop
        break;
    end loop;

    if undoneProgramCore<>0 then 
        raise notice 'All Program Cores have not been completed!!!';
        return;
    end if;

    -- Check if the student has done all the courses mentioned in its program electives

    query:= 'SELECT count(*) FROM ' || curriculumList ||
    ' WHERE ' || curriculumList|| '.courseCategory=''Program Elective'' AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || ' WHERE grade<>''F'' AND grade<>''NULL'')';

    for undoneProgramElective in EXECUTE query loop
        break;
    end loop;

    if undoneProgramElective<>0 then 
        raise notice 'All Program Electives have not been completed!!!';
        return;
    end if;

    -- Check if the student has done all the courses mentioned in its science core
    query:= 'SELECT count(*) FROM ' || curriculumList ||
    ' WHERE ' || curriculumList|| '.courseCategory=''Science Core'' AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || ' WHERE grade<>''F'' AND grade<>''NULL'')';

    for undoneScienceCore in EXECUTE query loop
        break;
    end loop;

    if undoneScienceCore<>0 then 
        raise notice 'All Science Cores have not been completed!!!';
        return;
    end if;

    -- Check if the student has done all the courses mentioned in its open electives

    query:= 'SELECT count(*) FROM ' || curriculumList ||
    ' WHERE ' || curriculumList|| '.courseCategory=''Open Elective'' AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || ' WHERE grade<>''F'' AND grade<>''NULL'')';

    for undoneOpenElective in EXECUTE query loop
        break;
    end loop;

    if undoneOpenElective<>0 then 
        raise notice 'All Open Electives have not been completed!!!';
        return;
    end if;

    raise notice 'Congratulations! You are eligible to graduate.';
end; $$;