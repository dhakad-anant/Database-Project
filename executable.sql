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
/* Creating BatchAdvisor through Trigger on insert in Department */
CREATE or replace FUNCTION postInsertingDepartment_trigger_function(
)
returns TRIGGER
language plpgsql SECURITY DEFINER
as $$
declare
    tableName   text;
    query       text;
    deptID      INTEGER;
begin
    deptID:= NEW.deptID;
    raise notice 'deptId : %', deptID;
    tableName := 'BatchAdvisor_' || deptID::text;
    query := 'CREATE TABLE ' || tableName || '
        (
            insID INTEGER,
            deptID INTEGER NOT NULL,
            PRIMARY KEY(deptID)
        );';
    EXECUTE query; 

    query := 'INSERT INTO ' || tableName || '(deptID) values(' ||deptID::text|| ')';
    raise notice '%',query;
    EXECUTE query;

    tableName := 'BatchAdvisorTicketTable_' || deptID::text;
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

CREATE TRIGGER postInsertingDepartment
AFTER INSERT ON Department 
For each ROW
EXECUTE PROCEDURE postInsertingDepartment_trigger_function();

INSERT INTO Department(deptID, deptName) values (1, 'CSE'),(2, 'EE'),(3, 'ME'),(4, 'MNC');

-- drop trigger postInsertingDepartment on department;
-- drop function postInsertingDepartment_trigger_function;
-- drop table Department;
-- select * from department;
/* ************************************************************************ */

-- DROP TABLE IF EXISTS Instructor;
CREATE TABLE Instructor(
    insID INTEGER PRIMARY KEY,
    insName VARCHAR(50) NOT NULL,
    deptID INTEGER not NULL,
    FOREIGN key(deptID) REFERENCES Department(deptID)
);

/* On adding a new instructor to the instructor table, we create a seperate ticket table for each faculty */
CREATE or replace FUNCTION postInsertingInstructor_trigger_function(
)
returns TRIGGER
language plpgsql SECURITY DEFINER
as $$
declare
    -- variable declaration
    tableName   text;
    query       text;
    insID       INTEGER;
begin
    insID:=NEW.insID;
    tableName := 'FacultyTicketTable_' || insID::text;
    query := 'CREATE TABLE ' || tableName;
    query := query || '
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

CREATE TRIGGER postInsertingInstructor
after insert on Instructor 
For each ROW
EXECUTE PROCEDURE postInsertingInstructor_trigger_function();

-- drop trigger postInsertingInstructor on instructor;
-- drop function postInsertingInstructor_trigger_function;
-- drop table Instructor;
/* ************************************************************************ */
/* procedure to make a view Instructor Table */
-- create or replace procedure viewInstructors()
-- language plpgsql
-- as $$
-- declare
--     query text;
-- begin
--     query := 'SELECT * FROM Instructor';
--     EXECUTE query;
-- end; $$;
-- call viewInstructors();

/* procedure to make a new Instructor */
create or replace procedure addInstructor(
    IN _insID INTEGER,
    IN _insName TEXT,
    IN _deptID INTEGER
)
language plpgsql
as $$
declare
    tableName TEXT;
    alreadyExists INTEGER;
begin
-- stored procedure body
    SELECT count(*) INTO alreadyExists
    FROM Instructor
    WHERE Instructor.insID = _insID; 

    IF alreadyExists != 0 THEN
        raise notice 'Instructor with given ID already exists';
        return;
    END IF;

    INSERT INTO instructor(insId,insName,deptID) VALUES(_insID,_insName,_deptID);
end; $$;

call addInstructor(5,'Puneet Goyal',1);


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

-- drop trigger postInsertingStudent on student;
-- drop function postInsertingStudent_trigger_function();
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
          ('A-', 9),
          ('B', 8),
          ('B-', 7),
          ('C', 6),
          ('C-', 5),
          ('F', 0);
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

-- drop role DeanAcademicsOffice;
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
CREATE ROLE student_1 with  
    LOGIN 
    PASSWORD 'student_1'
    IN ROLE Students;

/* Creating dummy faculty */
CREATE ROLE instructor_1 with 
    LOGIN 
    PASSWORD 'instructor_1'
    IN ROLE Faculty;

-- Raise ticket procedure for a student..give student a permission to view his/her tickettable
create or replace procedure raiseTicket(
    IN _studentID INTEGER,
    IN _insID INTEGER,
    IN _courseID INTEGER,
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _timeSlotID INTEGER
)
language plpgsql SECURITY DEFINER
as $$
declare
    tableName text;
    facultyTableName text;
    batchAdvisorTableName text;
    query text;
    cnt INTEGER := 0;
    _studentTicketID INTEGER;
    _deptID INTEGER;
BEGIN
    tableName := 'StudentTicketTable_' || _studentID::text;
    
    query :=  'select count(*) 
                from '|| tableName ||'
                    where insID = $1 and
                    courseID = $2 and
                    semester = $3 and
                    year = $4 and
                    timeSlotID = $5';

    for cnt in EXECUTE query using _insID, _courseID, _semester, _year, _timeSlotID loop 
        exit;
    end loop;
    if cnt != 0 then 
        raise notice 'Ticket is already raised !!!';
        return;
    end if;


    /* inserting into Student Ticket Table */
    query := 'INSERT INTO ' || tableName || '(insID,courseID,semester,year,timeSlotID,facultyVerdict,batchAdvisorVerdict,deanAcademicsOfficeVerdict) values('||_insID||','||_courseID||','||_semester||','||_year||','||_timeSlotID||',NULL,NULL,NULL)';

    EXECUTE query;

    query :=  'select ticketID
                from '|| tableName ||'
                    where insID = $1 and
                    courseID = $2 and
                    semester = $3 and
                    year = $4 and
                    timeSlotID = $5';

    for _studentTicketID in EXECUTE query using _insID, _courseID, _semester, _year, _timeSlotID loop 
        exit;
    end loop;

    /* inserting into Faculty Ticket Table */
    facultyTableName := 'FacultyTicketTable_' || _insID::text;
    query := 'INSERT INTO ' || facultyTableName || '(studentID, studentTicketID,facultyVerdict,batchAdvisorVerdict,deanAcademicsOfficeVerdict) VALUES('||_studentID||','||_studentTicketID||',NULL,NULL,NULL)';
    EXECUTE query;

    /* inserting into Batch Advisor Ticket Table */
    -- getting student's department ID
    select Student.deptID into _deptID from Student where Student.studentID = _studentID;    
    
    batchAdvisorTableName := 'BatchAdvisorTicketTable_' || _deptID::text;
    query := 'INSERT INTO ' || batchAdvisorTableName || '(studentID, studentTicketID,facultyVerdict,batchAdvisorVerdict,deanAcademicsOfficeVerdict) VALUES('||_studentID||','||_studentTicketID||',NULL,NULL,NULL)';
    EXECUTE query;


    /* inserting into Dean Ticket Table */
    query := 'INSERT INTO DeanAcademicsOfficeTicketTable(studentID, studentTicketID,facultyVerdict,batchAdvisorVerdict,deanAcademicsOfficeVerdict) VALUES('||_studentID||','||_studentTicketID||',NULL,NULL,NULL)';
    EXECUTE query;
    
END; $$;

/* stored procedure for the faculty to update its ticket table */
create or replace procedure updateFacultyTicketTable(
    IN _insID INTEGER,
    IN _studentTicketID INTEGER,  
    IN _studentID INTEGER,  
    IN _facultyVerdict BOOLEAN
)
language plpgsql SECURITY DEFINER
as $$
declare
-- variable declaration
    tableName TEXT;
    query TEXT;
    _deptID INTEGER;
    _validInsID INTEGER;
    _validStudentTicketID INTEGER;
    _validStudent INTEGER;
begin
    /* check for valid instructorID */
    select count(*) into _validInsID
    from Instructor
    where Instructor.insID = _insID;
    if _validInsID = 0 then
        raise notice 'Invalid Instructor ID entered !!!';
        return;
    end if;
    
    /* add checks for valid studentID */
    SELECT count(*) INTO _validStudent
    FROM Student 
    WHERE Student.studentID = _studentID;
    if _validStudent = 0 then
        raise notice 'No such student with the entered student ID exists!';
        return;
    end if;
    
    /* add checks for valid student ticket ID */
    tableName:= 'FacultyTicketTable_' || _insID::text;
    query:= 'select count(*) FROM ' || tableName ||
        ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID::text ||
        ' AND ' || tableName|| '.studentID = ' || _studentID::text;
    
    for _validStudentTicketID in EXECUTE query loop 
        exit;
    end loop;
    if _validStudentTicketID = 0 then
        raise notice 'Student Ticket ID does not exist.';
        return;
    end if;
    
    if _facultyVerdict <> 0::boolean and _facultyVerdict <> 1::boolean then 
        raise notice 'Invalid faculty verdict as input !!!';
        return;
    end if;

    tableName := 'FacultyTicketTable_' || _insID::text;

    query := 'UPDATE '|| tableName||'
    SET facultyVerdict = ' || _facultyVerdict::text ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID::text;

    EXECUTE query;
    
    
    /* Update the verdict of the faculty in the Student Ticket Table */
    tableName:= 'StudentTicketTable_'|| _studentID::text;
    query := 'UPDATE '|| tableName||'
    SET facultyVerdict = ' || _facultyVerdict::text ||
    ' WHERE '|| tableName||'.TicketID = ' || _studentTicketID::text;
    EXECUTE query;

    -- Finding the department of the student
    select Student.deptID into _deptID
    from Student
    where Student.studentID = _studentID;
    /* Update the verdict of the faculty in the BatchAdvisor Ticket Table */
    tableName:= 'BatchAdvisorTicketTable_' || _deptID::text;
    query := 'UPDATE '|| tableName ||'
    SET facultyVerdict = ' || _facultyVerdict::text ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID::text ||
    ' AND ' || tableName|| '.studentID = ' || _studentID::text;
    EXECUTE query;

    /* Update the verdict of the faculty in the DeanAcademicsOffice Ticket Table */
    tableName:= 'DeanAcademicsOfficeTicketTable';
    query := 'UPDATE '|| tableName||'
    SET facultyVerdict = ' || _facultyVerdict::text ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID::text ||
    ' AND ' || tableName|| '.studentID = ' || _studentID::text;
    EXECUTE query;
 
end; $$;
-- call updateFacultyTicketTable(1,1,1,0::boolean);
-- drop procedure updateFacultyTicketTable;
call registerstudent(1,'CS301',1,3,'Viswanath Gunturi','PCE1');
call registerstudent(2,'CS201',1,2,'Puneet Goyal','PCE3');
drop procedure registerstudent;

-- need faculty grade table before running this

create or replace procedure RegisterStudent(
    IN _studentID INTEGER,
    IN _courseCode VARCHAR(10),
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _insName VARCHAR(50),
    IN _slotName VARCHAR(20)
)
language plpgsql SECURITY DEFINER
as $$
declare 
    studentTrancriptTableName text;
    facultyGradeTableName text;
    prevCredit NUMERIC(4,2);
    prevPrevCredit NUMERIC(4,2);
    averageCredits NUMERIC(10,2);
    maxCreditsAllowed NUMERIC(10,2);
    currentCredit NUMERIC(4,2);
    courseCredit NUMERIC(4,2);
    totalPreRequisite INTEGER;
    totalPreRequisiteSatisfied INTEGER;
    clash INTEGER;
    insId INTEGER;
    ifslot INTEGER;
    _timeSlotID INTEGER;
    _insId INTEGER;
    totalClashes INTEGER;
    currentCGPA NUMERIC(4,2);
    cgpaRequired NUMERIC(4,2);
    _courseID INTEGER;
    query text;
    _sectionID INTEGER;
begin
    -- Computing the Course Id
    _courseID := -1;
    select CourseCatalogue.courseID into _courseID
    from CourseCatalogue
    where CourseCatalogue.courseCode = _courseCode;

    if _courseID = -1 then 
        raise notice 'Course Does not Exist!';
        return;
    end if;

    --  Computing the Instructor Id
    _insId := -1;
    select Instructor.insId into _insId
    from Instructor
    where Instructor.insName=_insName;

    if _insId = -1 then
        raise notice 'Instructor does not exist!';
        return;
    end if;


    -- Fetching the transcript table for each student
    studentTrancriptTableName:= 'Transcript_' || _studentID::text;

    query := 'SELECT sum(CourseCatalogue.C)
            FROM ' || studentTrancriptTableName || ', CourseCatalogue
            WHERE ' || studentTrancriptTableName ||'.courseID = CourseCatalogue.courseID 
            AND ' ||studentTrancriptTableName || '.semester = ' || _semester::text;

    FOR currentCredit in EXECUTE query loop 
        exit;
    end loop;
    

    -- Credit of the course that we are currently enrolling in
    SELECT CourseCatalogue.C INTO courseCredit
    from CourseCatalogue
    where CourseCatalogue.courseId = _courseID;

    currentCredit := currentCredit+ courseCredit;

    -- check 1.25 rule
    prevCredit:=-1;
    query := 'SELECT sum(CourseCatalogue.C)
            FROM ' || studentTrancriptTableName || ', CourseCatalogue
            WHERE ' || studentTrancriptTableName ||'.courseID = CourseCatalogue.courseID 
            AND (
                ('||studentTrancriptTableName||'.year = $1 and '||studentTrancriptTableName||'.semester = 2 and $2 = 1)
                                            OR 
                ('||studentTrancriptTableName||'.year = $3 and '||studentTrancriptTableName||'.semester = 1 and $4 = 2) 
            )';

    FOR prevCredit IN EXECUTE query using _year - 1, _semester, _year, _semester  loop 
        exit;
    end loop;


    prevPrevCredit:=-1;
    query := 'SELECT SUM(CourseCatalogue.C)
            FROM ' || studentTrancriptTableName || ', CourseCatalogue
            WHERE ' || studentTrancriptTableName ||'.courseID = CourseCatalogue.courseID 
            AND '||studentTrancriptTableName||'.year = $1 AND '||studentTrancriptTableName||'.semester = $2';

    for prevPrevCredit in EXECUTE query using _year - 1, _semester  loop 
        exit;
    end loop;

    if prevCredit = -1 then
        maxCreditsAllowed := 18;
    elsif prevPrevCredit = -1 then
        maxCreditsAllowed := 18.5;
    else 
        averageCredits := (prevCredit + prevPrevCredit)/2;
        maxCreditsAllowed := averageCredits * 1.25;
    end if;

    if currentCredit > maxCreditsAllowed then 
        raise notice  'Credit Limit Exceeding !!!';
        return;
    end if;


    -- check if he/she fullfills all preReqs 
    SELECT count(*) INTO totalPreRequisite
    FROM PreRequisite
    WHERE PreRequisite.courseId = _courseID;

    query := 'SELECT count(*)
            FROM ' || studentTrancriptTableName || ', PreRequisite
            WHERE PreRequisite.courseID = $1 
            AND PreRequisite.preReqCourseID = ' ||studentTrancriptTableName||'.courseId 
            AND grade<>''F'' and grade IS NOT NULL 
            AND '||studentTrancriptTableName||'.semester <> $2 
            AND '||studentTrancriptTableName||'.year <> $3';

    for totalPreRequisiteSatisfied in EXECUTE query using _courseID, _semester, _year loop 
        exit;
    end loop;

    if totalPreRequisite <> totalPreRequisiteSatisfied then
        raise notice 'All PreRequisite not Satisfied!';
        return;
    end if;

    -- If time slot exists or not
    _timeSlotID := -1;
    select TimeSlot.timeSlotID into _timeSlotID 
    from TimeSlot
    where TimeSlot.slotName = _slotName;
    if _timeSlotID = -1 then
        raise notice 'Entered Time SLot does not exist !!!';
        return;
    end if;
    -- Checking for clashes in timeSlot    
    query := 'SELECT count(*)
            FROM ' || studentTrancriptTableName || ', Teaches
            WHERE '||studentTrancriptTableName||'.courseID = Teaches.courseID 
            AND '||studentTrancriptTableName||'.year = Teaches.year 
            AND '||studentTrancriptTableName||'.semester = Teaches.semester 
            AND '||studentTrancriptTableName||'.semester = $1 
            AND '||studentTrancriptTableName||'.year = $2
            AND teaches.insID = $3 
            AND teaches.timeSlotID= $4';

    for totalClashes in EXECUTE query using _semester, _year, _insId, _timeSlotID loop 
        exit;
    end loop;
    
    if totalClashes <> 0 then 
        raise notice 'Course with same time slot already enrolled in this semester';
        return;
    end if;


    -- check course cgpa requirement
    -- call function to calculate Current CGPA
    -- declare this function above this one
    -- currentCGPA:= calculate_current_CGPA(_studentID);
    select CourseOffering.cgpaRequired into cgpaRequired
    from CourseOffering
    where CourseOffering.courseID = _courseID 
        AND CourseOffering.semester = _semester 
        AND CourseOffering.year=_year;

    if currentCGPA < cgpaRequired then
        raise notice 'CGPA Criteria not Satisfied!';
        return;
    end if;
    
    /* All checks completed */
    SELECT Teaches.sectionID into _sectionID
    FROM Teaches
    WHERE Teaches.courseID = _courseID 
        AND Teaches.semester = _semester 
        AND Teaches.year = _year 
        AND Teaches.insID = _insId 
        AND Teaches.timeSlotID = _timeSlotID;

    raise notice 'section Id: %',_sectionID;
    
    facultyGradeTableName := 'FacultyGradeTable_' || _sectionID::text;

    query := 'INSERT INTO ' || facultyGradeTableName ||'(studentID) VALUES ('||_studentID::text||')';

    EXECUTE query;

    query := 'INSERT INTO ' || studentTrancriptTableName ||'(courseID, semester, year, timeSlotID) 
    VALUES ('||_courseID::text||','||_semester::text||','||_year::text||','||_timeSlotID::text||')';
    
    EXECUTE query;


end; $$; 

-- REVOKE ALL 
-- ON PROCEDURE RegisterStudent
-- FROM PUBLIC;

-- GRANT EXECUTE 
-- ON PROCEDURE RegisterStudent 
-- TO students;

CREATE OR REPLACE PROCEDURE InsertIntoTeaches(
    IN _insID INTEGER,
    IN _courseID INTEGER, 
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _allotedTimeSlotID INTEGER
)
language plpgsql SECURITY DEFINER
as $$
declare
    tableName TEXT;
    query TEXT;
BEGIN   
    INSERT INTO Teaches(insID,courseID,semester,year,timeSlotID) 
        VALUES(_insID,_courseID,_semester,_year,_allotedTimeSlotID);
    
    /* Creating a dynamic table for each section */
    tableName := 'FacultyGradeTable_' || sectionID::text;
    query := 'CREATE TABLE ' || tableName;
    query := query || '
        (
            studentID INTEGER NOT NULL,
            grade VARCHAR(2),
            PRIMARY KEY(studentID)
        );';
    
    EXECUTE query;

END; $$;


/* API for faculty to float course */
-- @login -- with deanacademics WHILE CREATING 
-- @login -- with faculty WHILE EXECUTING

-- drop procedure offerCourse;
CREATE OR REPLACE procedure offerCourse(
    IN _courseOfferingID INTEGER,
    IN _courseID INTEGER, 
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _cgpa NUMERIC(4, 2),
    -- IN _sectionID INTEGER,
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
    courseOfferingID=_courseOfferingID;
    SELECT count(*) INTO cnt 
    FROM CourseCatalogue 
    WHERE CourseCatalogue.courseID = _courseID;

    IF cnt = 0 THEN 
        raise notice 'Course not in CourseCatalogue!!!';
        return;
    END IF;

    IF _cgpa IS NOT NULL AND (_cgpa > 10.0 OR _cgpa < 0.0) THEN
        raise notice 'Invalid CGPA value!!!';
        return;
    END IF;

    -- Finding the timeslotId
    SELECT TimeSlot.timeSlotID INTO allotedTimeSlotID
    FROM TimeSlot 
    WHERE TimeSlot.slotName = _slotName;

    IF allotedTimeSlotID = -1 THEN 
        raise notice 'TimeSlot does not exist!!!';
        return;
    END IF;

    -- check if this course offering already exists or not
    SELECT count(*) INTO courseOfferingExists
    FROM CourseOffering
    WHERE CourseOffering.courseID = _courseID 
        AND CourseOffering.semester = _semester 
        AND CourseOffering.year = _year 
        AND CourseOffering.cgpaRequired = _cgpa 
        AND CourseOffering.timeSlotID = allotedTimeSlotID;

    IF courseOfferingExists = 0 THEN 
        -- INSERT INTO CourseOffering(courseID, semester, year, cgpaRequired,timeSlotID) VALUES(_courseID, _semester, _year, _cgpa,allotedTimeSlotID);
        INSERT INTO CourseOffering(courseOfferingID, courseID, semester, year, cgpaRequired,timeSlotID) VALUES(courseOfferingID,_courseID, _semester, _year, _cgpa,allotedTimeSlotID);

        -- if _cgpa IS NULL THEN 
        --     SELECT CourseOffering.courseOfferingID INTO courseOfferingID
        --     FROM CourseOffering
        --     WHERE CourseOffering.courseID = _courseID 
        --         AND CourseOffering.semester = _semester 
        --         AND CourseOffering.year = _year 
        --         AND CourseOffering.cgpaRequired IS NULL
        --         AND CourseOffering.timeSlotID = allotedTimeSlotID;

        -- else
        --     -- Finding the courseOffering ID
        --     SELECT CourseOffering.courseOfferingID INTO courseOfferingID
        --     FROM CourseOffering
        --     WHERE CourseOffering.courseID = _courseID 
        --         AND CourseOffering.semester = _semester 
        --         AND CourseOffering.year = _year 
        --         AND CourseOffering.cgpaRequired = _cgpa 
        --         AND CourseOffering.timeSlotID = allotedTimeSlotID;
        -- END IF;

        FOREACH batch IN ARRAY _list_batches LOOP
            INSERT INTO BatchesAllowed(CourseOfferingID,batch) VALUES(courseOfferingID,batch);
        END LOOP;

    END IF;

    -- Check if there is a similar entry into the teaches table or not
    SELECT count(*) INTO teachesExists
    FROM Teaches
    WHERE Teaches.courseID = _courseID 
        AND Teaches.semester = _semester 
        AND Teaches.year = _year 
        AND Teaches.insID = _insID 
        AND Teaches.timeSlotID = allotedTimeSlotID;

    IF teachesExists <> 0 THEN
        raise notice 'Course offering already exists!!!';
        return;
    END IF;

    CALL InsertIntoTeaches(_insID,_courseID,_semester,_year,allotedTimeSlotID);
END; $$;
-- call offerCourse(4,1,1,2,NULL,5,'PCE3','{2019,2018}'::integer[]);

-- Checked till here-----------------------------------------------------------------------------------------------------------------------------

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
-- call upload_timetable_slots();

\c - postgres; 
-- SELECT grantee, privilege_type 
-- FROM information_schema.role_table_grants 
-- WHERE grantee<>'postgres' and grantee<>'PUBLIC' and table_name<>'timeslottable';

/* giving all permission on Coursecatalogue to deanacademicsoffice */
GRANT ALL 
ON CourseCatalogue 
TO deanacademicsoffice;

/* Giving sequence permission to deanacademicsoffice */
GRANT USAGE, SELECT 
ON ALL SEQUENCES IN SCHEMA public 
TO DeanAcademicsOffice;

/* Trigger which generates batchAdvisor table its ticket table */
-- @login -- with "ADMIN" WHILE CREATING 


/* Nobody will have permission to call this procedure directly */
-- @login -- with deanacademics WHILE CREATING 
-- @login -- with faculty WHILE EXECUTING
