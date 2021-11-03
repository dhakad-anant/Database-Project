-- CREATE TABLE Transcript(
--     studentID INTEGER NOT NULL,
--     semester INTEGER NOT NULL,
--     year INTEGER NOT NULL,
--     grade VARCHAR(2) NOT NULL,
--     PRIMARY KEY(courseID),
--     FOREIGN KEY(courseID) REFERENCES CourseCatalogue(courseID)
-- );

/* Doubt: How do we know which Btech Table to Reference for each student?🤔
Doubt: What would be the primary key for this table? */
/* CREATE TABLE Btech(
    courseID VARCHAR(10) NOT NULL,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    grade VARCHAR(2) NOT NULL,
    PRIMARY KEY(courseID),
    FOREIGN KEY(courseID) REFERENCES CourseCatalogue(courseID)
); */





/* ******************************TRIGGER 2 - Compute the current CGPA of any student*********************************************************************************************/
create or replace procedure calculate_current_CGPA(
    IN INT studentID, 
    INOUT currenCGPA numeric(4,2) )
    language plpgsql    
as $$
declare
    -- Transcritp_1
    transcriptTable text;
    totalCredits    INTEGER := 0;
    numerator       INTEGER := 0;
    rec             record;
    CGPA            NUMERIC := 0.0;
    query           TEXT;
begin
    transcriptTable := 'Transcript_' || studentID::text;

    query:= 'SELECT (CourseCatalogue.C, GradeMapping.val)
            FROM transcriptTable, CourseCatalogue, GradeMapping
            WHERE transcriptTable.courseID = CourseCatalogue.courseID AND 
            transcriptTable.year = CourseCatalogue.year AND 
            transcriptTable.semester = CourseCatalogue.semester AND
            grade <>'F' and grade IS NOT NULL
            transcriptTable.grade = GradeMapping.grade'

    for rec in Execute query loop
        totalCredits := totalCredits + rec.C;
        numerator := numertor + (rec.val * rec.C);
    end loop;
    
    CGPA := (numerator/totalCredits)::NUMERIC(4, 2);
    currentCGPA:=CGPA;
    raise notice 'CGPA for studentID % is %', 
        studentID, 
        CGPA;
end; $$;

-- cgpa = (summation{no. of credits x grade_in_that_course})/totalCredits

/* ******************************************************************************************** TRIGGER 2 - generate_transcript_table ends ******************************************************************************************** */




/* ******************************TRIGGER 2 - uploading_time-table slots*********************************************************************************************/
create or replace procedure upload_timetable_slots()
language plpgsql
as $$
declare
    filepath    text;
    query    text;
begin
    filepath := '''C:\fordbmsproject\filename.csv''';

    query := 'COPY TimeSlot(timeSlotID, slotName, duration, monday, tuesday, wednesday, thursday, friday) 
              FROM ' || filepath || 
              ' DELIMITER '','' 
              CSV HEADER;';
    EXECUTE QUERY;
end; $$;

-- call upload_timetable_slots();
/* ******************************************************************************************** TRIGGER 1 - uploading_time-table slots ends ******************************************************************************************** */















































/* 
CREATE or replace procedure test2()
language plpgsql
as $$
declare
    pradeep text;
    query text;
    tmp text;
begin
    pradeep := 'anant';
    -- query := 'CREATE table somename(
    --     x integer not null
    -- );';
    query := 'CREATE table ';
    query := query || pradeep;
    tmp := '(
        x integer not null,
        name varchar(20) not null,
        lastName varchar(20) not null,
        salary int not null,
        PRIMARY key(salary)
    );';
    query := query || tmp;
    EXECUTE query;
    execute 'grant something something';
end; $$;

insert into anant(x, name, lastName, salary) values(1, 'anant', 'dhakad', 10); */