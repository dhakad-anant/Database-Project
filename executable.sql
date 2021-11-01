CREATE DATABASE aims;


DROP TABLE IF EXISTS CourseCatalogue;
CREATE TABLE CourseCatalogue(
    courseID SERIAL PRIMARY KEY,
    courseCode VARCHAR(10) NOT NULL,
    L INTEGER NOT NULL,
    T INTEGER NOT NULL,
    P INTEGER NOT NULL,
    S INTEGER NOT NULL,
    C Numeric(4,2) NOT NULL
);


DROP TABLE IF EXISTS PreRequisite;
CREATE TABLE PreRequisite(
    courseID INTEGER NOT NULL,
    preReqCourseID INTEGER NOT NULL,
    FOREIGN KEY(courseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE,
    FOREIGN KEY(preReqCourseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE
);


DROP TABLE IF EXISTS Department;
CREATE TABLE Department(
    deptID SERIAL PRIMARY KEY,
    deptName VARCHAR(20) not null
);


DROP TABLE IF EXISTS Instructor;
CREATE TABLE Instructor(
    insID SERIAL PRIMARY KEY,
    insName VARCHAR(50) NOT NULL,
    deptID INTEGER not NULL,
    FOREIGN key(deptID) REFERENCES Department(deptID)
);


DROP TABLE IF EXISTS TimeSlot;
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


DROP TABLE IF EXISTS CourseOffering;
CREATE TABLE CourseOffering(
    courseID INTEGER NOT NULL,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    cgpaRequired NUMERIC(4, 2),
    PRIMARY KEY(courseID,semester,year),
    FOREIGN key(courseID) REFERENCES CourseCatalogue(courseID)
);


DROP TABLE IF EXISTS Student;
CREATE TABLE Student(
    studentID serial PRIMARY KEY,
    batch INTEGER NOT NULL,
    deptID INTEGER not NULL,
    entryNumber varchar(30) not null,
    Name VARCHAR(50) NOT NULL,
    FOREIGN key(deptID) REFERENCES Department(deptID) 
);


DROP TABLE IF EXISTS Teaches;
CREATE TABLE Teaches(
    insID INTEGER NOT NULL,
    courseID INTEGER NOT NULL,
    sectionID SERIAL,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    timeSlotID INTEGER NOT NULL,
    PRIMARY KEY(insID,courseID,semester,year,timeSlotID),
    FOREIGN KEY(insID) REFERENCES Instructor(insID),
    FOREIGN KEY(courseID,semester,year) REFERENCES CourseOffering(courseID,semester,year),
    FOREIGN key(timeSlotID) REFERENCES TimeSlot(timeSlotID)
);  


/* A = 10,A- = 9,B = 8,B- = 7,C = 6,C- = 5,F = 0 */
DROP TABLE IF EXISTS GradeMapping;
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

DROP TABLE IF EXISTS DeanAcademicsOfficeTicketTable;
CREATE TABLE DeanAcademicsOfficeTicketTable(
    studentID INTEGER NOT NULL,
    studentTicketID INTEGER NOT NULL,
    facultyVerdict BOOLEAN,
    BatchAdvisorVerdict BOOLEAN,
    DeanAcademicsOfficeVerdict BOOLEAN,
    PRIMARY KEY(studentID, studentTicketID)
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


/* CREATING MAJOR STAKEHOLDER ROLES */
CREATE ROLE Students;
CREATE ROLE Faculty;
CREATE ROLE BatchAdvisor;
CREATE ROLE DeanAcademicsOffice;


/* creating academic section (optional) */
CREATE ROLE academicsection with 
    LOGIN PASSWORD 'academicsection'
    IN ROLE pg_read_server_files;


/* giving SELECT permission on TimeSlot table to everyone */
GRANT SELECT 
ON TimeSlot    
TO Students, Faculty, BatchAdvisor, DeanAcademicsOffice;

/* giving all permissions on TimeSlot table to academicsection */
GRANT ALL 
ON TimeSlot 
TO academicsection;

/* Creating dummy student */
CREATE ROLE rahul with  
    LOGIN 
    PASSWORD 'rahul'
    IN ROLE Students;

/* uploading timetableslot */
-- @login with academicsection
call upload_timetable_slots();

