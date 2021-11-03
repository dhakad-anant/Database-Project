create or replace procedure canGraduate(
    IN _studentID  INTEGER
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
    SELECT Student.deptID INTO deptID
    FROM Student
    WHERE Student.studentID=_studentID;

    IF deptID=-1 THEN
        raise notice 'Incorrect student Id!!';
        return;
    END IF;

    SELECT Student.batch INTO batch
    FROM STUDENT
    WHERE Student.studentID=_studentID;

    -- Check if the student has a minimum of 5 CGPA or not
    CALL calculate_current_CGPA(_studentID,currentCGPA);
    IF currentCGPA<5.0 THEN
        raise notice 'CGPA criteria not satisfied as per the UG Curriculum!!!';
        return;
    END IF;

    -- find the curriculum id of the UG curriculum that the student is enrolled in
    SELECT UGCurriculum.curriculumID INTO curriculumID
    FROM UGCurriculum
    WHERE UGCurriculum.deptID=deptID AND UGCurriculum.batch=batch;

    -- Curriculum List for currcilumID
    curriculumList:= 'CurriculumList_' || curriculumID::text;

    -- transcript table of the student
    transcriptTable:= 'Transcript_' || _studentID::text;
    
    -- Check if the student has done all the courses mentioned in its program core

    query:= 'SELECT count(*) FROM ' || curriculumList ||
    ' WHERE ' || curriculumList|| '.courseCategory=''Program Core'' AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || ' WHERE grade=''A'' OR grade=''A-'' OR grade=''B'' OR grade=''B-'' OR grade=''C'' OR grade=''C-'')';

    for undoneProgramCore IN EXECUTE query LOOP
        break;
    END LOOP;

    IF undoneProgramCore<>0 THEN 
        raise notice 'All Program Cores have not been completed!!!';
        return;
    END IF;

    -- Check if the student has done all the courses mentioned in its program electives

    query:= 'SELECT count(*) FROM ' || curriculumList ||
    ' WHERE ' || curriculumList|| '.courseCategory=''Program Elective'' AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || ' WHERE grade=''A'' OR grade=''A-'' OR grade=''B'' OR grade=''B-'' OR grade=''C'' OR grade=''C-'')';

    for undoneProgramElective IN EXECUTE query LOOP
        break;
    END LOOP;

    IF undoneProgramElective<>0 THEN 
        raise notice 'All Program Electives have not been completed!!!';
        return;
    END IF;

    -- Check if the student has done all the courses mentioned in its science core
    query:= 'SELECT count(*) FROM ' || curriculumList ||
    ' WHERE ' || curriculumList|| '.courseCategory=''Science Core'' AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || ' WHERE grade=''A'' OR grade=''A-'' OR grade=''B'' OR grade=''B-'' OR grade=''C'' OR grade=''C-'')';

    for undoneScienceCore IN EXECUTE query LOOP
        break;
    END LOOP;

    IF undoneScienceCore<>0 THEN 
        raise notice 'All Science Cores have not been completed!!!';
        return;
    END IF;

    -- Check if the student has done all the courses mentioned in its open electives

    query:= 'SELECT count(*) FROM ' || curriculumList ||
    ' WHERE ' || curriculumList|| '.courseCategory=''Open Elective'' AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || ' WHERE grade=''A'' OR grade=''A-'' OR grade=''B'' OR grade=''B-'' OR grade=''C'' OR grade=''C-'')';

    for undoneOpenElective IN EXECUTE query LOOP
        break;
    END LOOP;

    IF undoneOpenElective<>0 THEN 
        raise notice 'All Open Electives have not been completed!!!';
        return;
    END IF;

    raise notice 'Congratulations! You are eligible to graduate.';
end; $$;