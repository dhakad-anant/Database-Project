CREATE TABLE CourseCatalogue(
    courseID SERIAL PRIMARY KEY,
    courseCode VARCHAR(10) NOT NULL,
    L INTEGER NOT NULL,
    T INTEGER NOT NULL,
    P INTEGER NOT NULL,
    S INTEGER NOT NULL,
    C Numeric(4,2) NOT NULL
);

CREATE TABLE PreRequisite(
    courseID INTEGER NOT NULL,
    preReqCourseID INTEGER NOT NULL,
    FOREIGN KEY(courseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE,
    FOREIGN KEY(preReqCourseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE
);

CREATE TABLE Department(
    deptID SERIAL PRIMARY KEY,
    deptName VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE Instructor(
    insID SERIAL PRIMARY KEY,
    insName VARCHAR(50) NOT NULL,
    deptID INTEGER not NULL,
    FOREIGN key(deptID) REFERENCES Department(deptID)
);

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

CREATE TABLE CourseOffering(
    courseOfferingID SERIAL,
    courseID INTEGER NOT NULL,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    cgpaRequired NUMERIC(4, 2),
    timeSlotID INTEGER NOT NULL,
    PRIMARY KEY(courseID,semester,year,timeSlotID),
    FOREIGN key(courseID) REFERENCES CourseCatalogue(courseID)
);

create table BatchesAllowed(
    CourseOfferingID INTEGER NOT NULL,
    Batch INTEGER NOT NULL,
    FOREIGN KEY(courseOfferingID) REFERENCES CourseOffering(courseOfferingID)
);

CREATE TABLE Student(
    studentID serial PRIMARY KEY,
    batch INTEGER NOT NULL,
    deptID INTEGER not NULL,
    entryNumber varchar(30) not null,
    Name VARCHAR(50) NOT NULL,
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
    FOREIGN KEY(courseID,semester,year) REFERENCES CourseOffering(courseID,semester,year),
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
    grade VARCHAR(2),
    PRIMARY KEY(studentID)
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
    studentTicketID SERIAL, 
    facultyVerdict BOOLEAN,
    batchAdvisorVerdict BOOLEAN,
    deanAcademicsOfficeVerdict BOOLEAN,
    PRIMARY KEY(insID,courseID,semester,year,timeSlotID)
);
/* @Dynamic Table */
CREATE TABLE FacultyTicketTable_{insID}(
    studentID INTEGER NOT NULL,
    studentTicketID INTEGER NOT NULL,
    facultyVerdict BOOLEAN,
    batchAdvisorVerdict BOOLEAN,
    deanAcademicsOfficeVerdict BOOLEAN, 
    PRIMARY KEY(studentID, studentTicketID)
);
/* @Dynamic Table */
CREATE TABLE BatchAdvisorTicketTable_{deptID}(
    studentID INTEGER NOT NULL,
    studentTicketID INTEGER NOT NULL,
    facultyVerdict BOOLEAN,
    batchAdvisorVerdict BOOLEAN,
    deanAcademicsOfficeVerdict BOOLEAN,
    PRIMARY KEY(studentID, studentTicketID)
);
CREATE TABLE DeanAcademicsOfficeTicketTable(
    studentID INTEGER NOT NULL,
    studentTicketID INTEGER NOT NULL,
    facultyVerdict BOOLEAN,
    batchAdvisorVerdict BOOLEAN,
    deanAcademicsOfficeVerdict BOOLEAN,
    PRIMARY KEY(studentID, studentTicketID)
);
/* @Dynamic Table */
CREATE TABLE BatchAdvisor_{deptID}(
    insID INTEGER,
    deptID INTEGER NOT NULL,
    PRIMARY KEY(deptID)
    FOREIGN KEY(deptID) REFERENCES Department(deptID)
);

create Table UGCurriculum(
    curriculumID SERIAL PRIMARY KEY,
    batch INTEGER NOT NULL,
    deptID INTEGER NOT NULL,
    FOREIGN KEY(deptID) REFERENCES Department(deptID)
);

-- @Dynamic Table
create table CurriculumList_{curriculumID}(
    courseCategory VARCHAR(20) NOT NULL,
    courseID integer not null,
    FOREIGN key(courseID) REFERENCES CourseCatalogue(courseID)
);

-- @Dynamic Table
create table CurriculumRequirements_{curriculumID}(
    numCreditsProgramCores INTEGER NOT NULL,
    numCreditsProgramElectives INTEGER NOT NULL,
    numCreditsScienceCores INTEGER NOT NULL,
    numCreditsOpenElectives INTEGER NOT NULL,
    minCGPA INTEGER NOT NULL
);