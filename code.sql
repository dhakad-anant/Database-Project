CREATE TABLE CourseCatalogue(
    courseID VARCHAR(10) NOT NULL,
    L INTEGER NOT NULL,
    T INTEGER NOT NULL,
    P INTEGER NOT NULL,
    S INTEGER NOT NULL,
    C INTEGER NOT NULL,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    PRIMARY KEY(courseID, semester, year)
);

-- One student must not have more than one course having same timeSlot 
CREATE TABLE TimeSlot(
    timeSlotID INTEGER NOT NULL,
    duration integer NOT NULL, -- in minutes
    slotName varchar(20) not null,

    monday varchar(20) not null,
    tuesday varchar(20) not null,
    wednesday varchar(20) not null,
    thursday varchar(20) not null,
    friday varchar(20) not null,
    
    PRIMARY KEY(timeSlotID, slotName)
);


/* ******************************TRIGGER 2 - uploading_time-table slots*********************************************************************************************/
create or replace procedure upload_timetable_slots()
language plpgsql
as $$
declare
    filepath    text;
    query    text;
begin
    filepath := '''C:\fordbmsproject\filename.csv''';
    -- query := '
    --     COPY persons(first_name, last_name, dob, email)
    --     FROM 'C:\sampledb\persons.csv'
    --     DELIMITER ','
    --     CSV HEADER;
    -- ';

    query := 'COPY TimeSlot(timeSlotID, slotName, duration, monday, tuesday, wednesday, thursday, friday) 
              FROM ' || filepath || 
              ' DELIMITER '','' 
              CSV HEADER;';
    EXECUTE QUERY;
end; $$;

-- call upload_timetable_slots();
/* ******************************************************************************************** TRIGGER 1 - uploading_time-table slots ends ******************************************************************************************** */


-- -- Refer to PreRequisite Table to access the list of PreRequisite
CREATE TABLE Department(
    deptID INTEGER not NULL,
    deptName VARCHAR(20) not null,
    PRIMARY Key(deptID)
);

CREATE TABLE Student(
    studentID INTEGER NOT NULL,
    batch INTEGER NOT NULL,
    deptID INTEGER not NULL,
    entryNumber varchar(30) not null,
    Name VARCHAR(50) NOT NULL,
    PRIMARY KEY(studentID),
    FOREIGN key(deptID) REFERENCES Department(deptID) 
);

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


CREATE TABLE PreRequisite(
    courseID INTEGER NOT NULL,
    preReqCourseID INTEGER NOT NULL,
    PRIMARY KEY(courseID),
    FOREIGN KEY(preReqCourseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE
);


CREATE TABLE Instructor(
    insID INTEGER NOT NULL,
    deptID INTEGER not NULL,
    PRIMARY KEY(insID),
    FOREIGN key(deptID) REFERENCES Department(deptID), 
);

CREATE TABLE CourseOffering(
    courseID VARCHAR(10) NOT NULL,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    timeSlotID INTEGER NOT NULL,
    PRIMARY KEY(courseID,semester,year),
    FOREIGN key(courseID) REFERENCES CourseCatalogue(courseID),
    FOREIGN key(timeSlotID) REFERENCES TimeSlot(timeSlotID)
);

CREATE TABLE Teaches(
    insID INTEGER NOT NULL,
    courseID VARCHAR(10) NOT NULL,
    sectionID INTEGER NOT NULL,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    timeSlotID INTEGER NOT NULL,
    PRIMARY KEY(insID,courseID,sectionID,semester,year),
    FOREIGN KEY(insID) REFERENCES Instructor(insID),
    FOREIGN KEY(courseID,semester,year) REFERENCES CourseOffering(courseID,semester,year)
    FOREIGN key(timeSlotID) REFERENCES TimeSlot(timeSlotID)
);

/* 
A = 10
A- = 9 
B = 8
B- = 7
C = 6
C- = 5
F = 0
*/
CREATE TABLE GradeMapping(
    grade VARCHAR(2) NOT NULL,
    val   INTEGER   NOT NULL,
    PRIMARY KEY(grade)
);

/* ******************************TRIGGER 1 - generate_transcript_table*********************************************************************************************/
CREATE TRIGGER generate_transcript_table
after insert on Student 
For each STATEMENT 
EXECUTE PROCEDURE generate_transcript_table_trigger_function(studentID);

CREATE or replace FUNCTION generate_transcript_table_trigger_function(studentID INTEGER)
    returns TRIGGER
    language plpgsql
as $$
declare
    -- variable declaration
    tableName   text;
    query       text;
begin
    -- stored procedure body
    tableName := 'Transcript_' || studentID::text;
    query := 'CREATE Table ' || tableName;
    query := query || '
        (
            courseID VARCHAR(10) NOT NULL,
            semester INTEGER NOT NULL,
            year INTEGER NOT NULL,
            grade VARCHAR(2),
            PRIMARY KEY(courseID, semester, year),
            FOREIGN KEY(courseID, semester, year) REFERENCES CourseCatalogue(courseID, semester, year)
        );';
    
    EXECUTE query; -- transcript table created

    return new;
    -- handle permissions
    -- student(read only), dean(read & write), 
end; $$;   
/* ******************************************************************************************** TRIGGER 1 - generate_transcript_table ends ******************************************************************************************** */


/* ******************************TRIGGER 2 - Compute the current CGPA of any student*********************************************************************************************/
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
/* ******************************************************************************************** TRIGGER 2 - generate_transcript_table ends ******************************************************************************************** */

-- cgpa = (summation{no. of credits x grade_in_that_course})/totalCredits
















































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