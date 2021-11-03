-- DROP DATABASE IF EXISTS aims;
CREATE DATABASE aims;

\c aims;

-- DROP TABLE IF EXISTS CourseCatalogue;
CREATE TABLE CourseCatalogue(
    courseID INTEGER PRIMARY KEY,
    courseCode VARCHAR(10) NOT NULL,
    L INTEGER NOT NULL,
    T INTEGER NOT NULL,
    P INTEGER NOT NULL,
    S INTEGER NOT NULL,
    C Numeric(4,2) NOT NULL
);

INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES
    (1,'CS201',3,1,2,6,4),
    (2,'CS202',3,1,2,6,4),
    (3,'CS203',3,1,3,6,4),

    (4,'CS301',3,1,2,6,4),
    (5,'CS302',3,1,0,5,3),
    (6,'CS303',3,1,2,6,4);

-- select * from CourseCatalogue;
-- DROP TABLE IF EXISTS PreRequisite;
CREATE TABLE PreRequisite(
    courseID INTEGER NOT NULL,
    preReqCourseID INTEGER NOT NULL,
    FOREIGN KEY(courseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE,
    FOREIGN KEY(preReqCourseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE
);

INSERT INTO PreRequisite(courseID,preReqCourseID) VALUES
    (4,1),
    (5,2),
    (6,3);

-- select * from PreRequisite;

-- DROP TABLE IF EXISTS Department;
CREATE TABLE Department(
    deptID INTEGER PRIMARY KEY,
    deptName VARCHAR(20) NOT NULL UNIQUE
);
INSERT INTO Department(deptID, deptName) values (1, 'CSE'),(2, 'EE'),(3, 'ME'),(4, 'MNC');

-- DROP TABLE IF EXISTS Instructor;
CREATE TABLE Instructor(
    insID INTEGER PRIMARY KEY,
    insName VARCHAR(50) NOT NULL,
    deptID INTEGER not NULL,
    FOREIGN key(deptID) REFERENCES Department(deptID)
);

INSERT INTO Instructor(insID,insName, deptID) VALUES 
    (1, 'Viswanath Gunturi',1), 
    (2, 'Brijesh Kumbhani',2), 
    (3, 'Apurva Mudgal',1),
    (4, 'Balwinder Sodhi',1);
-- select * from Instructor;

-- DROP TABLE IF EXISTS TimeSlot;
CREATE TABLE TimeSlot(
    timeSlotID INTEGER NOT NULL,
    slotName varchar(20) UNIQUE,
    duration integer NOT NULL, -- in minutes

    monday varchar(20) not null,
    tuesday varchar(20) not null,
    wednesday varchar(20) not null,
    thursday varchar(20) not null,
    friday varchar(20) not null,
    
    PRIMARY KEY(timeSlotID)
);

/* CREATING STORED FOR uploading TimeTable for a semester */
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

call upload_timetable_slots();
-- select * from TimeSlot;

-- DROP TABLE IF EXISTS CourseOffering;
CREATE TABLE CourseOffering(
    courseOfferingID INTEGER,
    courseID INTEGER NOT NULL,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    cgpaRequired NUMERIC(4, 2),
    timeSlotID INTEGER NOT NULL,
    PRIMARY KEY(courseID,semester,year,timeSlotID),
    FOREIGN key(courseID) REFERENCES CourseCatalogue(courseID)
);

INSERT INTO CourseOffering(courseOfferingID,courseID,semester,year,cgpaRequired,timeSlotID) VALUES (1,4,1,3,7.5,1);
INSERT INTO CourseOffering(courseOfferingID,courseID,semester,year,timeSlotID) VALUES (2,5,1,3,2);
INSERT INTO CourseOffering(courseOfferingID,courseID,semester,year,timeSlotID) VALUES (3,6,1,3,1);
-- select * from courseOffering;

-- DROP TABLE IF EXISTS BatchesAllowed;
CREATE TABLE BatchesAllowed(
    CourseOfferingID INTEGER NOT NULL,
    Batch INTEGER NOT NULL
    /* FOREIGN KEY(courseOfferingID) REFERENCES CourseOffering(courseOfferingID) */
);

INSERT INTO BatchesAllowed(CourseOfferingID,Batch) VALUES
    (1,2019), 
    (2,2019);

-- select * from BatchesAllowed;

-- DROP TABLE IF EXISTS Student;
CREATE TABLE Student(
    studentID INTEGER PRIMARY KEY,
    batch INTEGER NOT NULL,
    deptID INTEGER not NULL,
    entryNumber varchar(30) not null,
    Name VARCHAR(50) NOT NULL,
    FOREIGN key(deptID) REFERENCES Department(deptID) 
);

/* *************   TRIGGER - on inserting an entry in student table ********************************************/
CREATE or replace FUNCTION postInsertingStudent_trigger_function(
)
returns TRIGGER
language plpgsql
as $$
declare
    tableName   text;
    query       text;
    studentID INTEGER;
begin
    studentID:= NEW.studentID;
    raise notice 'Current student Id : %',studentID;
    /* Create transcript table for each student */
    tableName := 'Transcript_' || studentID::text;
    query := 'CREATE TABLE ' || tableName;
    query := query || '
        (
            courseID INTEGER NOT NULL,
            semester INTEGER NOT NULL,
            year INTEGER NOT NULL,
            grade VARCHAR(2),
            timeSlotID INTEGER NOT NULL,
            PRIMARY KEY(courseID, semester, year),
            FOREIGN KEY(courseID, semester, year,timeSlotID) REFERENCES CourseOffering(courseID, semester, year,timeslotID)
        );';
    
    EXECUTE query;

    /* Create seperate ticket table for each student */
    tableName := 'StudentTicketTable_' || new.studentID::text;
    query := 'CREATE TABLE ' || tableName;
    query := query || '
        (
            insID INTEGER NOT NULL,
            courseID INTEGER NOT NULL,
            semester INTEGER NOT NULL,
            year INTEGER NOT NULL,
            timeSlotID INTEGER NOT NULL,
            ticketID SERIAL, 
            facultyVerdict BOOLEAN,
            batchAdvisorVerdict BOOLEAN,
            deanAcademicsOfficeVerdict BOOLEAN,
            PRIMARY KEY(insID,courseID,semester,year,timeSlotID)
        );';
    
    EXECUTE query; -- transcript table created

    return new;
    -- handle permissions
    -- student(read only), dean(read & write), 
end; $$;  

CREATE TRIGGER postInsertingStudent
after insert on Student 
FOR EACH ROW
EXECUTE PROCEDURE postInsertingStudent_trigger_function();

drop trigger postInsertingStudent on student;
drop function postInsertingStudent_trigger_function();
-- drop table student;
/* ********************************************************************************************************** */

INSERT INTO Student(studentID,batch,deptID,entryNumber,Name) VALUES
    (1,2019,1,'2019CSB1070','A'),
    (2,2019,2,'2019EEB1107','B'),
    (3,2019,3,'2019MEB1130','C'),
    (4,2018,1,'2018CSB1070','AA'),
    (5,2018,2,'2018EEB1107','BB'),
    (6,2018,3,'2018MEB1130','CC');

--  need to make their transcript and add courses also
-- select * from student;

-- DROP TABLE IF EXISTS Teaches;
CREATE TABLE Teaches(
    insID INTEGER NOT NULL,
    courseID INTEGER NOT NULL,
    sectionID INTEGER UNIQUE,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    timeSlotID INTEGER NOT NULL,
    PRIMARY KEY(insID,courseID,semester,year,timeSlotID),
    FOREIGN KEY(insID) REFERENCES Instructor(insID),
    FOREIGN KEY(courseID,semester,year,timeSlotID) REFERENCES CourseOffering(courseID,semester,year,timeSlotID),
    FOREIGN key(timeSlotID) REFERENCES TimeSlot(timeSlotID)
);  

INSERT INTO Teaches(insID,CourseID,sectionID,semester,year,timeSlotID) VALUES
    (1,4,1,1,3,1),
    (2,5,2,1,3,2),
    (4,6,3,1,3,1);
-- select * from teaches;
/* A = 10,A- = 9,B = 8,B- = 7,C = 6,C- = 5,F = 0 */
-- DROP TABLE IF EXISTS GradeMapping;
CREATE TABLE GradeMapping(
    grade VARCHAR(2) NOT NULL,
    val   INTEGER   NOT NULL,
    PRIMARY KEY(grade)
);


/* INSERTING GradeMapping ROWS */
INSERT INTO GradeMapping(grade, val)
    values('A', 10),
          ('B', 9),
          ('C', 8),
          ('D', 7),
          ('E', 6),
          ('F', 5);
/**/
-- select * from GradeMapping;
-- DROP TABLE IF EXISTS DeanAcademicsOfficeTicketTable;
CREATE TABLE DeanAcademicsOfficeTicketTable(
    studentID INTEGER NOT NULL,
    studentTicketID INTEGER NOT NULL,
    facultyVerdict BOOLEAN,
    BatchAdvisorVerdict BOOLEAN,
    DeanAcademicsOfficeVerdict BOOLEAN,
    PRIMARY KEY(studentID, studentTicketID)
);




/* CREATING MAJOR STAKEHOLDER ROLES */
CREATE ROLE Students;
CREATE ROLE Faculty;
CREATE ROLE BatchAdvisor;

drop role DeanAcademicsOffice;
CREATE ROLE DeanAcademicsOffice with 
    login password 'deanacademicsoffice';


/* Giving permission to DeanAcademicsOffice to read file */
grant pg_read_server_files to DeanAcademicsOffice;


/* giving SELECT permission on TimeSlot table to everyone */
GRANT SELECT 
ON TimeSlot    
TO Students, Faculty, BatchAdvisor;


/* giving all permissions on TimeSlot table to academicsection & DeanAcademicsOffice */
GRANT ALL 
ON TimeSlot 
TO DeanAcademicsOffice;


/* Creating dummy student */
CREATE ROLE rahul with  
    LOGIN 
    PASSWORD 'rahul'
    IN ROLE Students;

/* Creating dummy faculty */
CREATE ROLE puneetgoyal with 
    LOGIN 
    PASSWORD 'puneetgoyal'
    IN ROLE Faculty;

/* revoking all permissions on procedure from public */
REVOKE ALL 
ON PROCEDURE upload_timetable_slots 
FROM PUBLIC;

/* Now only academic section can use this procedure */
GRANT EXECUTE 
ON PROCEDURE upload_timetable_slots 
TO DeanAcademicsOffice;

-- @login
\c - deanacademicsoffice;

/* uploading timetableslot */
-- @login with DeanAcademicsOffice
call upload_timetable_slots();

\c - postgres; 

/* giving all permission on Coursecatalogue to deanacademicsoffice */
GRANT ALL 
ON CourseCatalogue 
TO deanacademicsoffice;

/* Giving sequence permission to deanacademicsoffice */
GRANT USAGE, SELECT 
ON ALL SEQUENCES IN SCHEMA public 
TO DeanAcademicsOffice;


/* inserting dummy courses */
-- @login --with DeanAcademicsOffice
INSERT INTO CourseCatalogue(courseCode, L, T, P, S, C) 
    VALUES('CS201', 3, 2, 1, 5, 4),('CS202', 3, 2, 1, 5, 3),
          ('CS203', 3, 2, 1, 5, 4),('CS301', 3, 2, 1, 5, 4),
          ('CS302', 3, 2, 1, 5, 3),('CS303', 3, 2, 1, 5, 4);


/* Trigger which generates batchAdvisor table its ticket table */
-- @login -- with "ADMIN" WHILE CREATING 
CREATE TRIGGER postInsertingDepartment
AFTER INSERT ON Department 
For each STATEMENT 
EXECUTE PROCEDURE postInsertingDepartment_trigger_function();

CREATE or replace FUNCTION postInsertingDepartment_trigger_function(
)
returns TRIGGER
language plpgsql SECURITY DEFINER
as $$
declare
    tableName   text;
    query       text;
begin
    tableName := 'BatchAdvisor_' || new.deptID::text;
    query := 'CREATE TABLE ' || tableName || '
        (
            insID INTEGER,
            deptID INTEGER NOT NULL,
            PRIMARY KEY(deptID)
        );';
    EXECUTE query; 

    query := 'INSERT INTO ' || tableName || '(insID, deptID) values('||NULL||','||new.deptID||')';
    EXECUTE query;

    tableName := 'BatchAdvisorTicketTable_' || new.deptID::text;
    query := 'CREATE TABLE ' || tableName || '
        (
            studentID INTEGER NOT NULL,
            studentTicketID INTEGER NOT NULL,
            facultyVerdict BOOLEAN,
            BatchAdvisorVerdict BOOLEAN,
            DeanAcademicsOfficeVerdict BOOLEAN,
            PRIMARY KEY(studentID, studentTicketID)
        );';
    EXECUTE query; 

    return new;
end; $$; 




-- @login -- with DeanAcademicsOffice
INSERT INTO Department(deptID, deptName)
    values (1, 'CSE'),(2, 'EE'),(3, 'ME'),(4, 'MNC');





/* Nobody will have permission to call this procedure directly */
-- @login -- with deanacademics WHILE CREATING 
-- @login -- with faculty WHILE EXECUTING
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


/* API for faculty to float course */
-- @login -- with deanacademics WHILE CREATING 
-- @login -- with faculty WHILE EXECUTING
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
