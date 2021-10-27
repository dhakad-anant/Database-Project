CREATE TABLE CourseCatalogue(
    -- courseID INTEGER NOT NULL,
    courseID SERIAL PRIMARY KEY,
    courseCode VARCHAR(10) NOT NULL,
    L INTEGER NOT NULL,
    T INTEGER NOT NULL,
    P INTEGER NOT NULL,
    S INTEGER NOT NULL,
    C Numeric(4,2) NOT NULL
    -- semester INTEGER NOT NULL,
    -- year INTEGER NOT NULL,
    -- PRIMARY KEY(courseID, semester, year)
    -- PRIMARY KEY(courseID)
);

CREATE TABLE PreRequisite(
    courseID INTEGER NOT NULL,
    preReqCourseID INTEGER NOT NULL,
    FOREIGN KEY(courseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE,
    FOREIGN KEY(preReqCourseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE
);

CREATE TABLE Department(
    deptID SERIAL PRIMARY KEY,
    deptName VARCHAR(20) not null,
    -- PRIMARY Key(deptID)
);

CREATE TABLE Instructor(
    insID SERIAL PRIMARY KEY,
    insName VARCHAR(50) NOT NULL,
    deptID INTEGER not NULL,
    FOREIGN key(deptID) REFERENCES Department(deptID), 
);

CREATE TABLE TimeSlot(
    timeSlotID INTEGER NOT NULL,
    slotName varchar(20) not null,
    duration integer NOT NULL, -- in minutes

    monday varchar(20) not null,
    tuesday varchar(20) not null,
    wednesday varchar(20) not null,
    thursday varchar(20) not null,
    friday varchar(20) not null,
    
    PRIMARY KEY(timeSlotID, slotName)
);

CREATE TABLE CourseOffering(
    courseID INTEGER NOT NULL,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    cgpaRequired NUMERIC(4, 2),
    PRIMARY KEY(courseID,semester,year),
    FOREIGN key(courseID) REFERENCES CourseCatalogue(courseID),
);

CREATE TABLE Student(
    -- studentID INTEGER NOT NULL,
    studentID serial PRIMARY KEY,
    batch INTEGER NOT NULL,
    deptID INTEGER not NULL,
    entryNumber varchar(30) not null,
    Name VARCHAR(50) NOT NULL,
    -- PRIMARY KEY(studentID),
    FOREIGN key(deptID) REFERENCES Department(deptID) 
);

CREATE TABLE Teaches(
    insID INTEGER NOT NULL,
    courseID INTEGER NOT NULL,
    sectionID SERIAL,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    timeSlotID INTEGER NOT NULL,
    PRIMARY KEY(insID,courseID,semester,year,timeSlotID),
    FOREIGN KEY(insID) REFERENCES Instructor(insID),
    FOREIGN KEY(courseID,semester,year) REFERENCES CourseOffering(courseID,semester,year)
    FOREIGN key(timeSlotID) REFERENCES TimeSlot(timeSlotID)
);  
/* A = 10,A- = 9,B = 8,B- = 7,C = 6,C- = 5,F = 0 */
CREATE TABLE GradeMapping(
    grade VARCHAR(2) NOT NULL,
    val   INTEGER   NOT NULL,
    PRIMARY KEY(grade)
);
/* @Dynamic Table */
CREATE TABLE FacultyGradeTable_{sectionID}(
    studentID integer not null,
    grade VARCHAR(2)
);
/* @Dynamic Table */
CREATE TABLE Transcript_{studentID}(
    courseID INTEGER NOT NULL, 
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    grade VARCHAR(2),
    PRIMARY KEY(courseID, semester, year),
    FOREIGN KEY(courseID,semester,year) REFERENCES CourseOffering(courseID,semester,year)
);
/* @Dynamic Table */
CREATE TABLE StudentTicketTable_{studentID}(
    insID INTEGER NOT NULL,
    courseID INTEGER NOT NULL,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    timeSlotID INTEGER NOT NULL,
    ticketID SERIAL, 
    facultyVerdict BOOLEAN,
    batchAdvisorVerdict BOOLEAN,
    deanAcademicsOfficeTicketTableVerdict BOOLEAN,
    PRIMARY KEY(insID,courseID,semester,year,timeSlotID)
);
/* @Dynamic Table */
CREATE TABLE FacultyTicketTable_{insID}(
    studentID INTEGER NOT NULL,
    studentTicketID INTEGER NOT NULL,
    facultyVerdict BOOLEAN,
    BatchAdvisorVerdict BOOLEAN,
    DeanAcademicsOfficeVerdict BOOLEAN,
    PRIMARY KEY(studentID, studentTicketID)
);
/* @Dynamic Table */
CREATE TABLE BatchAdvisorTicketTable_{insID}(
    studentID INTEGER NOT NULL,
    studentTicketID INTEGER NOT NULL,
    facultyVerdict BOOLEAN,
    BatchAdvisorVerdict BOOLEAN,
    DeanAcademicsOfficeVerdict BOOLEAN,
    PRIMARY KEY(studentID, studentTicketID)
);
CREATE TABLE DeanAcademicsOfficeTicketTable(
    studentID INTEGER NOT NULL,
    studentTicketID INTEGER NOT NULL,
    facultyVerdict BOOLEAN,
    BatchAdvisorVerdict BOOLEAN,
    DeanAcademicsOfficeVerdict BOOLEAN,
    PRIMARY KEY(studentID, studentTicketID)
);