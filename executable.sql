DROP DATABASE IF EXISTS aims;

CREATE DATABASE aims;

\c aims;

CREATE ROLE Students;
CREATE ROLE Faculty;
CREATE ROLE BatchAdvisor;
CREATE ROLE DeanAcademicsOffice WITH LOGIN PASSWORD 'test';
CREATE ROLE AcademicSection WITH LOGIN PASSWORD 'test';

/* Giving permission to DeanAcademicsOffice to read file */
GRANT pg_read_server_files TO DeanAcademicsOffice,AcademicSection;   
-- GRANT pg_write_server_files TO Students;   

-- DROP TABLE IF EXISTS CourseCatalogue;
CREATE TABLE CourseCatalogue(
    courseID INTEGER,
    courseCode VARCHAR(10) NOT NULL,
    L INTEGER NOT NULL,
    T INTEGER NOT NULL,
    P INTEGER NOT NULL,
    S INTEGER NOT NULL,
    C Numeric(4,2) NOT NULL,
    PRIMARY KEY(courseID)
);
-- select * from CourseCatalogue;
GRANT ALL ON CourseCatalogue TO DeanAcademicsOffice;
GRANT SELECT ON CourseCatalogue TO Faculty, BatchAdvisor;

create or replace procedure updateCourseCatalogue(
    IN _courseID INTEGER,
    IN _courseCode VARCHAR(10),
    IN _L INTEGER,
    IN _T INTEGER,
    IN _P INTEGER,
    IN _S INTEGER,
    IN _C Numeric(4,2)
)
language plpgsql SECURITY DEFINER
as $$
declare
begin
    INSERT INTO CourseCatalogue(courseID, courseCode, L, T, P, S, C)
        values(_courseID, _courseCode, _L, _T, _P, _S, _C);
end; $$;
REVOKE ALL ON PROCEDURE updateCourseCatalogue FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE updateCourseCatalogue TO deanacademicsoffice;

create or replace function viewCourseCatalogue()
returns table(
        courseID INTEGER,
        courseCode VARCHAR(10),
        L INTEGER,
        T INTEGER,
        P INTEGER,
        S INTEGER,
        C Numeric(4,2)
    )
language plpgsql
as $$
declare
    rec record;
begin
    for rec in (select * from CourseCatalogue) loop 
        courseID := rec.courseID;
        courseCode := rec.courseCode;
        L := rec.L;
        T := rec.T;
        P := rec.P;
        S := rec.S;
        C := rec.C;
        return next;    
    end loop;
end; $$;
-- select * from viewCourseCatalogue();

-- DROP TABLE IF EXISTS PreRequisite;
CREATE TABLE PreRequisite(
    courseID INTEGER NOT NULL,
    preReqCourseID INTEGER NOT NULL,
    FOREIGN KEY(courseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE,
    FOREIGN KEY(preReqCourseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE,
    PRIMARY KEY(courseID, preReqCourseID)
);
GRANT ALL ON PreRequisite TO DeanAcademicsOffice;
GRANT SELECT ON PreRequisite TO Faculty, BatchAdvisor, Students;
-- select * from PreRequisite;

-- DROP TABLE IF EXISTS Department;
CREATE TABLE Department(
    deptID INTEGER NOT NULL,
    deptName VARCHAR(20) NOT NULL UNIQUE,
    PRIMARY KEY(deptID)
);
GRANT ALL ON Department TO DeanAcademicsOffice, AcademicSection;
GRANT SELECT ON Department TO Faculty, BatchAdvisor, Students;

/* procedure to make a faculty a BatchAdvisor */
CREATE OR REPLACE FUNCTION postInsertingDepartment_trigger_function()
returns TRIGGER
language plpgsql SECURITY DEFINER
as $$
declare
    tableName   TEXT;
    roleName    TEXT;
    query       TEXT;
    deptID      INTEGER;
begin
    deptID := NEW.deptID;

    /* Assign a role to each newly created batch advisor and add it under the general role of batch advisor */
    roleName := 'BatchAdvisor_' || deptID::text;
    query := 'CREATE ROLE ' || roleName || 
                ' WITH LOGIN 
                PASSWORD ''test''
                IN ROLE BatchAdvisor';

    EXECUTE query; 
    
    /* Create a dynamic table for each department's batch advisor */
    /* It will store the ID of the instructor who is the batch advisor of that department */
    tableName := 'BatchAdvisor_' || deptID::text;
    query := 'CREATE TABLE ' || tableName || '
        (
            insID INTEGER,
            deptID INTEGER NOT NULL,
            PRIMARY KEY(deptID)
        );';
    EXECUTE query; 
    
    /* Granting permissions on the Batch Advisor Table */
    /* Dean AcademicsOffice granted all permissions for this table */
    query := 'GRANT ALL ON ' ||tableName|| ' to DeanAcademicsOffice';
    EXECUTE query;
    /* Batch Advisor granted access to view its corresponding table */
    query := 'GRANT SELECT ON '||tableName||' to '||roleName;
    EXECUTE query;

    /* Add a dummy entry, this can be modified later by makeBatchAdvisor function */
    query := 'INSERT INTO ' || tableName || '(deptID) values(' ||deptID::text|| ')';
    -- raise notice '%',query;
    EXECUTE query;

    /* Create a ticket table corresponding to each batch advisor */
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
    
    /* Note that here we are granting only view access to the batch advisor to see his/her ticket table */
    /* In case the verdict needs to be updated it can be done only through the updateBatchAdvisorTicketTable stored procedure */
    query := 'GRANT SELECT ON '|| tableName ||' to '|| roleName;
    EXECUTE query; 
    return new;

end; $$; 
/* Revoking all permissions from public, therefore this function can not be called directly but only through the trigger function */
REVOKE ALL ON FUNCTION postInsertingDepartment_trigger_function FROM PUBLIC;

/* Trigger for Department Table */
CREATE TRIGGER postInsertingDepartment
AFTER INSERT ON Department 
For each ROW
EXECUTE PROCEDURE postInsertingDepartment_trigger_function();

/* 
 * Appointing a faculty as Batch Advisor of a Department
 * Only Dean Academics Office can call this procedure
 * Takes two arguments, the ID of the instructor and the department ID for which you the batch advisor needs to be appointed
*/
create or replace procedure makeBatchAdvisor(
    IN _insID INTEGER,
    IN _deptID INTEGER
)
language plpgsql SECURITY INVOKER
as $$
declare
    tableName TEXT;
    query TEXT;
    doesInstructorExists INTEGER;
    doesDepartmentExists INTEGER;
begin
    SELECT count(*) INTO doesInstructorExists 
    FROM Instructor
    WHERE Instructor.insID = _insID;
    if doesInstructorExists = 0 THEN
        raise notice 'Instructor with entered ID does not exists';
        return;
    end if;

    SELECT count(*) INTO doesDepartmentExists 
    FROM Department
    WHERE Department.deptID = _deptID;
    if doesDepartmentExists = 0 THEN
        raise notice 'Department with entered ID does not exists';
        return;
    end if;
    
    /* Update the Batch Advisor in its table */
    tableName := 'BatchAdvisor_' || _deptID::text;
    query := 'UPDATE '|| tableName ||' SET insID = '|| _insID::text ||' WHERE '|| tableName||'.deptID = '||_deptID::text;
    EXECUTE query;
end; $$;

/* Revoking the permissions to call this procedure from public, only the Dean Academics Office can appoint a new Batch Advisor */
REVOKE ALL ON PROCEDURE makeBatchAdvisor FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE makeBatchAdvisor TO DeanAcademicsOffice;

-- DROP TRIGGER postInsertingDepartment ON department;
-- drop FUNCTION postInsertingDepartment_trigger_function;
-- DROP TABLE Department;
-- SELECT * FROM department;

-- DROP TABLE IF EXISTS Instructor;
CREATE TABLE Instructor(
    insID INTEGER NOT NULL,
    insName VARCHAR(50) NOT NULL,
    deptID INTEGER NOT NULL,
    FOREIGN key(deptID) REFERENCES Department(deptID),
    PRIMARY KEY(insID)
);
/* Only the DeanAcademicsOffice can modify the Instructor table, no one else can */
GRANT ALL ON Instructor to DeanAcademicsOffice;


/* On adding a new instructor to the instructor table, we create a seperate ticket table for each faculty */
CREATE or replace FUNCTION postInsertingInstructor_trigger_function()
returns TRIGGER
language plpgsql SECURITY DEFINER
as $$
declare
    tableName   TEXT;
    roleName    TEXT;
    query       TEXT;
    insID       INTEGER;
begin
    insID := NEW.insID;

    /* Assign a role to each newly added instructor */
    roleName := 'Faculty_' || insID::text;
    query := 'CREATE ROLE ' || roleName || 
                ' WITH LOGIN 
                PASSWORD ''test''
                IN ROLE Faculty';
    EXECUTE query;

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

    query := 'GRANT SELECT ON '|| tableName ||' to '||roleName;
    EXECUTE query;

    return new;

end; $$; 
REVOKE ALL ON FUNCTION postInsertingInstructor_trigger_function FROM PUBLIC;

CREATE TRIGGER postInsertingInstructor
after insert on Instructor 
For each ROW
EXECUTE PROCEDURE postInsertingInstructor_trigger_function();

-- DROP TRIGGER postInsertingInstructor ON instructor;
-- DROP FUNCTION postInsertingInstructor_trigger_function;
-- DROP TABLE Instructor;

/* procedure to make a view Instructor Table */
create or replace procedure viewInstructors()
language plpgsql SECURITY INVOKER
as $$
declare
    query text;
    rec   record;    
begin
    query := 'SELECT * FROM Instructor';
    for rec in EXECUTE query loop
            raise notice 'Instructor ID: % , Name of the Instructor: %', rec.insID, rec.insName;
    end loop;
end; $$;
REVOKE ALL ON PROCEDURE viewInstructors FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE  viewInstructors TO deanacademicsoffice;

/* procedure to make a new Instructor */
create or replace procedure addInstructor(
    IN _insID INTEGER,
    IN _insName TEXT,
    IN _deptID INTEGER
)
language plpgsql SECURITY INVOKER
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
REVOKE ALL ON PROCEDURE addInstructor FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE addInstructor TO deanacademicsoffice;



-- DROP TABLE IF EXISTS TimeSlot;
CREATE TABLE TimeSlot(
    timeSlotID INTEGER NOT NULL,
    slotName VARCHAR(20) UNIQUE NOT NULL,
    duration INTEGER NOT NULL, -- in minutes
    monday VARCHAR(20),
    tuesday VARCHAR(20),
    wednesday VARCHAR(20),
    thursday VARCHAR(20),
    friday VARCHAR(20),
    
    PRIMARY KEY(timeSlotID)
);
GRANT ALL ON TimeSlot to academicsection,DeanAcademicsOffice;
GRANT SELECT ON TimeSlot to Faculty,BatchAdvisor,Students;

/* Stored Procedure for uploading timeTable slots through csv file */
create or replace procedure upload_timetable_slots()
language plpgsql SECURITY INVOKER
as $$
declare
    filepath    text;
    query    text;
begin
    filepath := '''C:\media\timetable.csv''';

    query := 'COPY TimeSlot(timeSlotID, slotName, duration, monday, tuesday, wednesday, thursday, friday) 
              FROM ' || filepath || 
              ' DELIMITER '','' 
              CSV HEADER;';
    EXECUTE query;
end; $$;
REVOKE ALL ON PROCEDURE upload_timetable_slots FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE upload_timetable_slots TO academicsection, DeanAcademicsOffice;
-- call upload_timetable_slots();
-- select * from TimeSlot;


-- DROP TABLE IF EXISTS CourseOffering;
CREATE TABLE CourseOffering(
    courseOfferingID INTEGER NOT NULL UNIQUE,
    courseID INTEGER NOT NULL,
    semester INTEGER NOT NULL,
    year INTEGER NOT NULL,
    cgpaRequired NUMERIC(4, 2),
    timeSlotID INTEGER NOT NULL,
    PRIMARY KEY(courseID,semester,year,timeSlotID),
    FOREIGN key(courseID) REFERENCES CourseCatalogue(courseID)
);
GRANT ALL ON CourseOffering to DeanAcademicsOffice;
GRANT SELECT ON CourseOffering to Students,Faculty,BatchAdvisor;
-- select * from courseOffering;


-- DROP TABLE IF EXISTS BatchesAllowed;
CREATE TABLE BatchesAllowed(
    CourseOfferingID INTEGER NOT NULL,
    Batch INTEGER NOT NULL,
    PRIMARY KEY(courseOfferingID),
    FOREIGN KEY(courseOfferingID) REFERENCES CourseOffering(courseOfferingID) 
);
GRANT ALL ON BatchesAllowed to DeanAcademicsOffice;
GRANT SELECT ON BatchesAllowed to Students, Faculty, BatchAdvisor;

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
GRANT ALL ON Teaches to DeanAcademicsOffice;
GRANT SELECT ON Teaches to BatchAdvisor;

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
REVOKE ALL ON PROCEDURE InsertIntoTeaches FROM PUBLIC;

/* API for faculty to float course */
-- drop procedure offerCourse;
CREATE OR REPLACE procedure offerCourse(
    IN _courseOfferingID INTEGER,
    IN _courseID INTEGER, 
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _cgpa NUMERIC(4, 2),
    IN _sectionID INTEGER,
    IN _insID INTEGER,
    -- IN _slotName VARCHAR(20),
    IN allotedTimeSlotID INTEGER,
    IN _list_batches INTEGER[]
) 
language plpgsql SECURITY DEFINER
as $$
declare
    cnt INTEGER = 0;
    courseOfferingExists INTEGER;
    teachesExists INTEGER;
    -- allotedTimeSlotID INTEGER = -1;
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

    -- Finding the TimeSlotID
    -- SELECT TimeSlot.timeSlotID INTO allotedTimeSlotID
    -- FROM TimeSlot 
    -- WHERE TimeSlot.slotName = _slotName;

    -- IF allotedTimeSlotID = -1 THEN 
    --     raise notice 'TimeSlot does not exist!!!';
    --     return;
    -- END IF;

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
REVOKE ALL ON PROCEDURE offerCourse FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE offerCourse to Faculty;


-- DROP TABLE IF EXISTS Student;
CREATE TABLE Student(
    studentID INTEGER,
    batch INTEGER NOT NULL,
    deptID INTEGER NOT NULL,
    entryNumber VARCHAR(30) NOT NULL UNIQUE,
    Name VARCHAR(50) NOT NULL,
    primary key(studentID),
    FOREIGN key(deptID) REFERENCES Department(deptID) 
);
GRANT ALL ON PROCEDURE Student to DeanAcademicsOffice,academicsection;
GRANT SELECT ON PROCEDURE Student to Faculty, BatchAdvisor;


CREATE or replace FUNCTION postInsertingStudent_trigger_function()
returns TRIGGER
language plpgsql SECURITY DEFINER
as $$
declare
    tableName   TEXT;
    roleName    TEXT;
    query       TEXT;
    studentID INTEGER;
begin
    studentID := NEW.studentID;

    /* Assign a role to each newly added student */
    roleName := 'Student_' || studentID::text;
    query := 'CREATE ROLE ' || roleName || 
                ' WITH LOGIN 
                PASSWORD ''test''
                IN ROLE Students';
    EXECUTE query;
    
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
    /* Security Feature: Only the student itself can view his transcript table. NO other student can view the transcript table of any other student. Additionally the faculty's, batch advisors, dean office can view his/her transcript */
    query := 'GRANT SELECT ON '|| tableName ||' to '||roleName||',Faculty, BatchAdvisor, DeanAcademicsOffice';
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
    
    EXECUTE query; 
    /* Secuirty Feature */
    query := 'GRANT SELECT ON '|| tableName ||' to '||roleName||',Faculty, BatchAdvisor, DeanAcademicsOffice';
    EXECUTE query;

    return new;
end; $$;  
REVOKE ALL ON PROCEDURE postInsertingStudent_trigger_function FROM PUBLIC;

CREATE TRIGGER postInsertingStudent
AFTER INSERT ON Student 
FOR EACH ROW
EXECUTE PROCEDURE postInsertingStudent_trigger_function();

-- drop trigger postInsertingStudent on student;
-- drop function postInsertingStudent_trigger_function();
-- drop table student;


/* 
 * A = 10
 * A- = 9
 * B = 8
 * B- = 7
 * C = 6
 * C- = 5
 * F = 0 
*/
-- DROP TABLE IF EXISTS GradeMapping;
CREATE TABLE GradeMapping(
    grade VARCHAR(2) NOT NULL,
    val   INTEGER   NOT NULL,
    PRIMARY KEY(grade)
);
GRANT ALL ON GradeMapping to DeanAcademicsOffice;
GRANT SELECT ON GradeMapping to Students, Faculty, BatchAdvisor, AcademicSection;

CREATE TABLE DeanAcademicsOfficeTable(
    insID INTEGER PRIMARY KEY,
    FOREIGN KEY(insID) REFERENCES Instructor(insID)
);
GRANT ALL ON DeanAcademicsOfficeTable to deanacademicsoffice;
GRANT SELECT ON DeanAcademicsOfficeTable to Students, Faculty,BatchAdvisor,AcademicSection;

-- DROP TABLE IF EXISTS DeanAcademicsOfficeTicketTable;
CREATE TABLE DeanAcademicsOfficeTicketTable(
    studentID INTEGER NOT NULL,
    studentTicketID INTEGER NOT NULL,
    facultyVerdict BOOLEAN,
    BatchAdvisorVerdict BOOLEAN,
    DeanAcademicsOfficeVerdict BOOLEAN,
    PRIMARY KEY(studentID, studentTicketID)
);
GRANT SELECT ON DeanAcademicsOfficeTicketTable to deanacademicsoffice;



-- Utility function supporting raiseTicket
CREATE OR REPLACE PROCEDURE raiseTicketUtil(
    IN _insID INTEGER,
    IN _studentID INTEGER,
    IN _studentTicketID INTEGER,
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _timeSlotID INTEGER,
    IN _courseID INTEGER
)
language plpgsql SECURITY DEFINER
as $$
declare
    facultyTableName TEXT;
    tableName TEXT;
    batchAdvisorTableName TEXT;
    query TEXT;
    _deptID INTEGER;
BEGIN
    /* Inserting into Student Ticket Table */
    tableName := 'StudentTickettable_'||_studentID::text;
    query := 'INSERT INTO ' || tableName || '(insID,courseID,semester,year,timeSlotID,facultyVerdict,batchAdvisorVerdict,deanAcademicsOfficeVerdict) VALUES('||_insID::text||','||_courseID::text||','||_semester::text||','||_year::text||','||_timeSlotID::text||',NULL,NULL,NULL)';
    EXECUTE query;

    query :=  'SELECT ticketID
                FROM '|| tableName ||'
                    WHERE insID = $1 and
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

    /* Inserting into Batch Advisor Ticket Table */
    -- getting student's department ID
    select Student.deptID into _deptID from Student where Student.studentID = _studentID;    
    
    batchAdvisorTableName := 'BatchAdvisorTicketTable_' || _deptID::text;
    query := 'INSERT INTO ' || batchAdvisorTableName || '(studentID, studentTicketID,facultyVerdict,batchAdvisorVerdict,deanAcademicsOfficeVerdict) VALUES('||_studentID||','||_studentTicketID||',NULL,NULL,NULL)';
    EXECUTE query;

    /* Inserting into Dean Ticket Table */
    query := 'INSERT INTO DeanAcademicsOfficeTicketTable(studentID, studentTicketID,facultyVerdict,batchAdvisorVerdict,deanAcademicsOfficeVerdict) VALUES('||_studentID||','||_studentTicketID||',NULL,NULL,NULL)';
    EXECUTE query;
    
END; $$;


-- Raise ticket procedure for a student..give student a permission to view his/her tickettable
-- call raiseTicket(7,4,6,1,3,1);
create or replace procedure raiseTicket(
    IN _studentID INTEGER,
    IN _insID INTEGER,
    IN _courseID INTEGER,
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _timeSlotID INTEGER
)
language plpgsql SECURITY INVOKER
as $$
declare
    tableName TEXT;
    roleName TEXT;
    current_user_name TEXT;
    facultyTableName TEXT;
    batchAdvisorTableName TEXT;
    query TEXT;
    cnt INTEGER := 0;
    _studentTicketID INTEGER;
    _deptID INTEGER;
    _doesCourseExists INTEGER;
BEGIN
    SELECT current_user INTO current_user_name;
    roleName := 'student_' || _studentID::text;

    if current_user_name <> roleName then
        raise notice 'Illegal Access. Current Logged in User is % and Trying to raise ticket for User %', current_user_name, roleName;
        return;     
    end if;

    SELECT count(*) into _doesCourseExists
            FROM CourseOffering
            WHERE CourseOffering.courseID = _courseID
                    AND CourseOffering.semester = _semester 
                    AND CourseOffering.year = _year
                    AND CourseOffering.timeSlotID = _timeSlotID;
    IF _doesCourseExists = 0 THEN 
        raise notice 'Course does not exist in Course Offering ... Cannot raise ticket';
        return;
    END IF;

    /* Checking whether the course already exists in the Transcript table of the student. 
    Raise a ticket only in the case where the course is never taken before or if it is taken then the grade should be NULL */
    tableName := 'Transcript_' || _studentID::text;
    query := 'SELECT count(*) 
             FROM '||tableName||'
             WHERE '||tableName||'.courseID = '||_courseID::text||'
                AND '||tableName||'.semester = '||_semester::text||'
                AND '||tableName||'.year = '||_year::text||'
                AND '||tableName||'.timeSlotID = '||_timeSlotID::text||'
                AND ('||tableName||'.grade is NULL 
                            OR 
                    ('||tableName||'.grade is NOT NULL AND '||tableName||'.grade <> ''F'')
                )';
    for _doesCourseExists in EXECUTE query loop
        exit;
    end loop;
    if _doesCourseExists <> 0 then 
        raise notice 'Course already exists in the Transcript Table .. Cannot raise ticket';
        return;
    end if;

    tableName := 'StudentTicketTable_' || _studentID::text;
    query :=  'SELECT count(*) 
                FROM '|| tableName ||'
                    WHERE insID = $1 and
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

    -- query := 'GRANT EXECUTE ON PROCEDURE raiseTicketUtil to '||roleName;
    -- EXECUTE query;
    call raiseTicketUtil(_insID,_studentID,_studentTicketID,_semester,_year,_timeSlotID,_courseID);  
    -- query := 'REVOKE EXECUTE ON PROCEDURE raiseTicketUtil FROM '||roleName; 
    -- EXECUTE query; 
END; $$;
REVOKE ALL ON PROCEDURE raiseTicket FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE raiseTicket to Students;


/* stored procedure for the faculty to update its ticket table */
CREATE OR REPLACE PROCEDURE updateFacultyTicketTable(
    IN _insID INTEGER,
    IN _studentTicketID INTEGER,  
    IN _studentID INTEGER,  
    IN _facultyVerdict BOOLEAN
)
language plpgsql SECURITY DEFINER
as $$
declare
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
    tableName := 'FacultyTicketTable_' || _insID::text;
    query:= 'SELECT count(*) FROM ' || tableName ||
        ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID::text ||
        ' AND ' || tableName|| '.studentID = ' || _studentID::text;
    
    for _validStudentTicketID in EXECUTE query loop 
        exit;
    end loop;
    if _validStudentTicketID = 0 then
        raise notice 'Student Ticket ID does not exist.';
        return;
    end if;
    
    IF _facultyVerdict <> 0::boolean AND _facultyVerdict <> 1::boolean THEN 
        raise notice 'Invalid faculty verdict as input !!!';
        return;
    END IF;



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
REVOKE ALL ON PROCEDURE updateFacultyTicketTable FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE updateFacultyTicketTable TO Faculty;
-- call updateFacultyTicketTable(1,1,1,1::boolean);

/* Stored procedure to update the ticket table of the batch advisor */
create or replace procedure updateBatchAdvisorTicketTable(
    IN _deptName VARCHAR(20),
    IN _studentTicketID INTEGER,  
    IN _studentID INTEGER,  
    IN _batchAdvisorVerdict BOOLEAN    
)
language plpgsql SECURITY DEFINER
as $$
declare
    tableName text;
    query text;
    _insID INTEGER;
    _studentDeptID INTEGER;
    _deptID INTEGER;
    _validStudentTicketID INTEGER;
    _validStudent INTEGER;
begin
    /* find the department ID from the deptName. Checks added for invalid department names */
    _deptID := -1;
    select Department.deptID into _deptID 
    from Department 
    where Department.deptName = _deptName; 
    if _deptID = -1 then
        raise notice 'Incorrect Deparment Name entered!';
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
    tableName:= 'BatchAdvisorTicketTable_' || _deptID::text;
    query:= 'SELECT count(*) FROM ' || tableName ||
        ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID::text ||
        ' AND ' || tableName|| '.studentID = ' || _studentID::text;
    
    for _validStudentTicketID in EXECUTE query loop 
        exit;
    end loop;

    if _validStudentTicketID = 0 then
        raise notice 'Student Ticket ID does not exist.';
        return;
    end if;
    
    /* check whether the student department is same as the batch advisor's department */
    select Student.DeptID into _studentDeptID
    from Student
    where Student.studentID = _studentID;
    if _studentDeptID <> _deptID then 
        raise notice 'The student department does not match with the faculty advisor department !!!';
        return;
    end if;

    /* The batch advisor verdict should either be 0 or 1 as it is of boolean type */
    if _batchAdvisorVerdict <> 0::boolean and _batchAdvisorVerdict <> 1::boolean then 
        raise notice 'Invalid Batch Advisor verdict as input !!!';
        return;
    end if;

    /* Update the verdict of the faculty in the BatchAdvisor Ticket Table */
    tableName:= 'BatchAdvisorTicketTable_' || _deptID::text;
    query := 'UPDATE '|| tableName ||'
    SET batchAdvisorVerdict = ' || _batchAdvisorVerdict::text ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID::text ||
    ' AND ' || tableName|| '.studentID = ' || _studentID::text;
    EXECUTE query;
    

    /* Update the verdict of the batch advisor in the Faculty Ticket Table */
    -- Finding the instructor ID first
    tableName := 'StudentTicketTable_' || _studentID::text;
    query := 'SELECT '||tableName||  '.insID FROM '|| tableName ||
    ' WHERE '||tableName||'.TicketID = '||_studentTicketID::text;

    for _insID in EXECUTE query loop 
        exit;
    end loop;
    

    tableName := 'FacultyTicketTable_' || _insID::text;
    query := 'UPDATE '|| tableName||'
    SET batchAdvisorVerdict = ' || _batchAdvisorVerdict::text ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID::text ||
    ' AND ' || tableName|| '.studentID = ' || _studentID::text;
    EXECUTE query;


    /* Update the verdict of the batch advisor in the DeanAcademicsOffice Ticket Table */
    tableName:= 'DeanAcademicsOfficeTicketTable';
    query := 'UPDATE '|| tableName ||'
    SET batchAdvisorVerdict = ' || _batchAdvisorVerdict::text ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID::text ||
    ' AND ' || tableName|| '.studentID = ' || _studentID::text;
    EXECUTE query;
    

    /* Update the verdict of the batch advisor in the Student Ticket Table */
    tableName:= 'StudentTicketTable_'|| _studentID::text;
    query := 'UPDATE '|| tableName||'
    SET batchAdvisorVerdict = ' || _batchAdvisorVerdict::text ||
    ' wHERE '|| tableName||'.TicketID = ' || _studentTicketID::text;
    EXECUTE query; 

end; $$;
REVOKE ALL ON PROCEDURE updateBatchAdvisorTicketTable FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE updateBatchAdvisorTicketTable TO BatchAdvisor;


create or replace procedure updateDeanAcademicsOfficeTicketTable(
    IN _studentTicketID INTEGER,    
    IN _studentID INTEGER,    
    IN _deanAcademicsOfficeVerdict BOOLEAN
)
language plpgsql SECURITY DEFINER
as $$
declare
    tableName text;
    query text;
    _deptID INTEGER;
    _insID INTEGER;
    _validStudent INTEGER;
    _validStudentTicketID INTEGER;

    facultyGradeTableName text;
    studentTrancriptTableName text;
    _courseID integer; /* to find */
    _sectionID integer; /* to find */
    _semester integer; /* to find */
    _year integer; /* to find */
    _timeSlotID integer; /* to find */
begin
    /* Checks for valid studentID */
    SELECT count(*) INTO _validStudent
    FROM Student 
    WHERE Student.studentID = _studentID;
    if _validStudent = 0 then
        raise notice 'No such student with the entered student ID exists!';
        return;
    end if;

     /* find the department ID from the student Table */
    select Student.deptID into _deptID 
    from Student 
    where Student.studentID = _studentID; 

    /* add checks for valid student ticket ID */
    select count(*) into _validStudentTicketID
    from DeanAcademicsOfficeTicketTable
    where DeanAcademicsOfficeTicketTable.studentTicketID = _studentTicketID
    and DeanAcademicsOfficeTicketTable.studentID = _studentID;
    if _validStudentTicketID = 0 then
        raise notice 'Student Ticket ID does not exist in the Deans Ticket Table !!!';
        return;
    end if;
    /* The DeanAcademicsOffice verdict should either be 0 or 1 as it is of boolean type */
    if _deanAcademicsOfficeVerdict <> 0::boolean and _deanAcademicsOfficeVerdict <> 1::boolean then 
        raise notice 'Invalid DeanAcademicsOffice verdict as input !!!';
        return;
    end if;

    /* Updating the verdict in the DeanAcademicsOfficeTicketTable */
    tableName := 'DeanAcademicsOfficeTicketTable';
    query := 'UPDATE '|| tableName||'
    SET deanAcademicsOfficeVerdict = ' || _deanAcademicsOfficeVerdict::text ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID::text ||
    ' AND ' || tableName|| '.studentID = ' || _studentID::text;
    EXECUTE query;


    /* Update the verdict in the Student Ticket Table */
    tableName:= 'StudentTicketTable_'|| _studentID::text;
    query := 'UPDATE '|| tableName||'
    SET deanAcademicsOfficeVerdict = ' || _deanAcademicsOfficeVerdict::text ||
    ' WHERE '|| tableName||'.TicketID = ' || _studentTicketID::text;
    EXECUTE query; 

    /* Update the verdict in the Faculty Ticket Table */
    -- Finding the instructor ID first
    tableName := 'StudentTicketTable_' || _studentID::text;
    query := 'SELECT '||tableName||'.insID  
    FROM '|| tableName ||
    ' WHERE '||tableName||'.TicketID = '||_studentTicketID::text;
    for _insID in EXECUTE query loop 
        exit;
    end loop;
    
    tableName := 'FacultyTicketTable_' || _insID::text;
    query := 'UPDATE '|| tableName||'
    SET deanAcademicsOfficeVerdict = ' || _deanAcademicsOfficeVerdict::text ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID::text ||
    ' AND ' || tableName|| '.studentID = ' || _studentID::text;
    EXECUTE query;


    /* Update the verdict in the BatchAdvisor Ticket Table */
    tableName := 'BatchAdvisorTicketTable_' || _deptID::text;
    query := 'UPDATE '|| tableName ||'
    SET deanAcademicsOfficeVerdict = ' || _deanAcademicsOfficeVerdict::text ||
    ' WHERE '|| tableName||'.studentTicketID = ' || _studentTicketID::text  ||
    ' AND ' || tableName|| '.studentID = ' || _studentID::text;
    EXECUTE query;


    -- If the verdict of Dean Academics office is yes, register the student for that given course
    IF _deanAcademicsOfficeVerdict = 1::boolean THEN 

        tableName := 'StudentTicketTable_' || _studentID::text;

        query := 'SELECT '||tableName||'.courseID, '||tableName||'.semester, '||tableName||'.year, '||tableName||'.timeSlotID   
                  FROM '||tableName||' 
                  WHERE '||tableName||'.ticketID = '||_studentTicketID::text;

        for (_courseID, _semester, _year, _timeSlotID) IN EXECUTE query loop 
            exit;
        end loop;

        /* inserting into Student Transcript Table */
        studentTrancriptTableName := 'Transcript_' || _studentID::text;
        query := 'INSERT INTO ' || studentTrancriptTableName ||'(courseID, semester, year, timeSlotID) 
        VALUES ('||_courseID::text||','||_semester::text||','||_year::text||','||_timeSlotID::text||')';
        EXECUTE query;

        select Teaches.sectionID into _sectionID
        from Teaches 
        where Teaches.insID = _insID and
            Teaches.courseID = _courseID and
            Teaches.semester = _semester and
            Teaches.year = _year and
            Teaches.timeSlotID = _timeSlotID;

        /* inserting into FacultyGradeTable_{_sectionID} */
        facultyGradeTableName := 'FacultyGradeTable_' || _sectionID::text;
        query := 'INSERT INTO ' || facultyGradeTableName ||'(studentID) VALUES ('||_studentID::text||')';
        EXECUTE query;
    else 
        raise notice 'Dean Academics Office rejected the ticket of student ID: % and ticket ID: %', _studentID, _studentTicketID;
    end if;
end; $$;
REVOKE ALL ON PROCEDURE updateDeanAcademicsOfficeTicketTable FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE updateDeanAcademicsOfficeTicketTable TO deanacademicsoffice;
-- call updateDeanAcademicsOfficeTicketTable(1,1,0::boolean);

create or replace procedure calculate_current_CGPA(
    IN studentID INTEGER, 
    INOUT currentCGPA NUMERIC(4,2) 
)
language plpgsql SECURITY INVOKER  
as $$
declare
    transcriptTable text;
    totalCredits    INTEGER := 0;
    numerator       INTEGER := 0;
    rec             record;
    CGPA            NUMERIC := 0.0;
    query           TEXT;
    credits         NUMERIC(4,2);
    val             INTEGER;
begin
    transcriptTable := 'Transcript_' || studentID::text;

    query := 'SELECT CourseCatalogue.C, GradeMapping.val
            FROM '||transcriptTable||', CourseOffering, GradeMapping, CourseCatalogue
            WHERE '||transcriptTable||'.courseID = CourseOffering.courseID AND 
            '||transcriptTable||'.year = CourseOffering.year AND 
            '||transcriptTable||'.semester = CourseOffering.semester AND 
            '||transcriptTable||'.grade <> ''F'' AND '||transcriptTable||'.grade IS NOT NULL AND 
            '||transcriptTable||'.grade = GradeMapping.grade AND 
            '||transcriptTable||'.timeSlotID =  CourseOffering.timeSlotID AND 
            CourseCatalogue.courseID = CourseOffering.courseID';

    for credits, val in EXECUTE query loop
        totalCredits := totalCredits + credits;
        numerator := numerator + (val * credits);
    end loop;
    
    if totalCredits<>0 then
        CGPA := (numerator/totalCredits)::NUMERIC(4, 2);
    elsif 
        CGPA:=0
    end if;
    currentCGPA := CGPA;
    -- raise notice 'CGPA for studentID % is %',studentID,CGPA;
end; $$;
REVOKE ALL ON PROCEDURE calculate_current_CGPA FROM PUBLIC;

create or replace procedure print_current_CGPA(
    IN studentID INTEGER 
)
language plpgsql SECURITY INVOKER   
as $$
declare
    currentCGPA NUMERIC(4, 2) := 0;
    query TEXT;
    roleName TEXT;
begin
    roleName := 'Student_' || studentID::text;
    query := 'GRANT EXECUTE ON PROCEDURE calculate_current_CGPA TO '||roleName;
    EXECUTE query;
    call calculate_current_CGPA(studentID, currentCGPA);
    query := 'REVOKE EXECUTE ON PROCEDURE calculate_current_CGPA FROM '||roleName;
    EXECUTE query;
    raise notice 'CGPA for studentID % is %',studentID,currentCGPA;
end; $$;


----------------------------------- Checked till here --------------------------

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
    SELECT CourseCatalogue.courseID INTO _courseID
    FROM CourseCatalogue
    WHERE CourseCatalogue.courseCode = _courseCode;
    IF _courseID = -1 THEN 
        raise notice 'Course Does not Exist!';
        return;
    END IF;


    --  Computing the Instructor Id
    _insId := -1;
    SELECT Instructor.insId INTO _insId
    FROM Instructor
    WHERE Instructor.insName=_insName;

    IF _insId = -1 THEN
        raise notice 'Instructor does not exist!';
        return;
    END IF;


    -- Fetching the transcript table for each student
    studentTrancriptTableName:= 'Transcript_' || _studentID::text;

    query := 'SELECT sum(CourseCatalogue.C)
            FROM ' || studentTrancriptTableName || ', CourseCatalogue
            WHERE ' || studentTrancriptTableName ||'.courseID = CourseCatalogue.courseID 
            AND ' ||studentTrancriptTableName || '.semester = ' || _semester::text;

    FOR currentCredit in EXECUTE query LOOP 
        exit;
    END LOOP;
    

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


    prevPrevCredit := -1;
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
    call calculate_current_CGPA(_studentID,currentCGPA);
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

REVOKE ALL ON PROCEDURE RegisterStudent FROM PUBLIC;

GRANT EXECUTE ON PROCEDURE RegisterStudent TO students;


create or replace procedure upload_grades_csv(
    IN _sectionID INTEGER
)
language plpgsql SECURITY DEFINER
as $$
declare
    filepath    TEXT;
    query    TEXT;
    query_2    TEXT;
    tableName    TEXT;
    studentTrancriptTableName TEXT;
    facultygradeTableName TEXT;
    temp_studentID INTEGER;
    temp_grade varchar(2);
    courseID INTEGER;
    semester INTEGER;
    year INTEGER;
    timeSlotID INTEGER;
    
begin
    filepath := '''C:\media\grades_'|| _sectionID::text ||'.csv''';
    tableName := 'temp_' || _sectionID::text; -- concatinating section Id so multiple proffs can call this procedure at the same time and they won't face any issue since the temp table is different for everyone    
    query := 'CREATE TABLE ' || tableName || '(
            studentID INTEGER NOT NULL,
            grade VARCHAR(2),
            PRIMARY KEY(studentID)
        )';
    EXECUTE query;

    query := 'COPY '|| tableName || '(studentID, grade) 
              FROM ' || filepath || 
              ' DELIMITER '','' 
              CSV HEADER;';
    EXECUTE query;

    facultygradeTableName:= 'FacultyGradeTable_' || _sectionID::text;    
    query := 'SELECT ' || facultygradeTableName||'.studentID from ' || facultygradeTableName;
    for temp_studentID in EXECUTE query loop        
        temp_grade := 'N';        
        query_2 := 'SELECT '||tableName||'.grade 
                    FROM '||tableName||'
                    WHERE '||tableName||'.studentID = '||temp_studentID::text;
        for temp_grade in EXECUTE query_2 loop
            exit;
        end loop;
        if temp_grade != 'N' THEN            
            SELECT Teaches.courseID, Teaches.semester, Teaches.year, Teaches.timeSlotID 
                INTO courseID, semester, year, timeSlotID
            FROM Teaches
            WHERE Teaches.sectionID = _sectionID;
            studentTrancriptTableName := 'Transcript_' || temp_studentID::text;
            query_2 := 'UPDATE '||studentTrancriptTableName||
            ' SET grade = '||''''||temp_grade::text||''''||
            ' WHERE '||studentTrancriptTableName||'.courseID = '||courseID::text||
                ' AND '||studentTrancriptTableName||'.semester = '||semester::text||
                ' AND '||studentTrancriptTableName||'.year = '||year::text||
                ' AND '||studentTrancriptTableName||'.timeSlotID = '||timeSlotID::text;            
            EXECUTE query_2;             
            query_2 :=  'UPDATE '||facultygradeTableName||' 
                        SET grade = '||''''||temp_grade::text||''''||
                        ' WHERE '||facultygradeTableName||'.studentID = '||temp_studentID::text;
            EXECUTE query_2;        
        end if;
    end loop;
    query := 'DROP TABLE ' || tableName; 
    EXECUTE query;
end; $$;
-- call upload_grades_csv(4);


create or replace procedure update_grade(
    IN _sectionID INTEGER,
    IN _studentID INTEGER,
    IN _temp_grade VARCHAR(2)
)
language plpgsql SECURITY DEFINER
as $$
declare
    courseID INTEGER;
    semester INTEGER;
    year INTEGER;
    timeSlotID INTEGER;
    studentTrancriptTableName TEXT;
    facultygradeTableName TEXT;    
    query TEXT;    
begin
    facultygradeTableName:= 'FacultyGradeTable_' || _sectionID::text;  
    studentTrancriptTableName := 'Transcript_' || _studentID::text; 
    
    SELECT Teaches.courseID, Teaches.semester, Teaches.year, Teaches.timeSlotID 
        INTO courseID, semester, year, timeSlotID
    FROM Teaches
    WHERE Teaches.sectionID = _sectionID;
    
    query := 'UPDATE '||studentTrancriptTableName||
    ' SET grade = '||''''||_temp_grade::text||''''||
    ' WHERE '||studentTrancriptTableName||'.courseID = '||courseID::text||
        ' AND '||studentTrancriptTableName||'.semester = '||semester::text||
        ' AND '||studentTrancriptTableName||'.year = '||year::text||
        ' AND '||studentTrancriptTableName||'.timeSlotID = '||timeSlotID::text;            
    EXECUTE query;             
    

    query :=  'UPDATE '||facultygradeTableName||' 
                SET grade = '||''''||_temp_grade::text||''''||
                ' WHERE '||facultygradeTableName||'.studentID = '||_studentID::text;
    EXECUTE query;        
end; $$;
-- call update_grade(4,2,'B');

create Table UGCurriculum(
    curriculumID SERIAL PRIMARY KEY,
    batch INTEGER NOT NULL,
    deptID INTEGER NOT NULL,
    FOREIGN KEY(deptID) REFERENCES Department(deptID)
);

/* procedure to add a new UGCurriculum */
create or replace procedure addUGCurriculum(
    IN _batch INTEGER,
    IN _deptID INTEGER
)
language plpgsql SECURITY DEFINER
as $$
declare
    tableName TEXT;
    alreadyExists INTEGER;
    curriculumID INTEGER;
    query TEXT;
begin
-- stored procedure body
    SELECT count(*) INTO alreadyExists
    FROM UGCurriculum
    WHERE UGCurriculum.batch = _batch and UGCurriculum.deptID = _deptID; 

    IF alreadyExists != 0 THEN
        raise notice 'UG Curriculum of entered batch and deptID already exists';
        return;
    END IF;

    INSERT INTO UGCurriculum(batch,deptID) VALUES(_batch,_deptID);

    /* After inserting get the curriculumID */
    SELECT UGCurriculum.curriculumID INTO curriculumID
    FROM UGCurriculum
    WHERE UGCurriculum.batch = _batch AND UGCurriculum.deptID = _deptID;

    /* Create a dynamic table for the Curriculum List of the given curriculumID*/
    tableName := 'CurriculumList_' || curriculumID::text;
    query := 'CREATE TABLE '|| tableName || '(
                courseCategory VARCHAR(20) NOT NULL,
                courseID integer not null,
                FOREIGN key(courseID) REFERENCES CourseCatalogue(courseID)
                );';
    EXECUTE query;

    /* Create a dynamic table for the Curriculum Requirements of the given curriculumID*/
    tableName := 'CurriculumRequirements_' || curriculumID::text;
    query := 'CREATE TABLE '|| tableName || '(
                numCreditsProgramCores INTEGER NOT NULL,
                numCreditsProgramElectives INTEGER NOT NULL,
                numCreditsScienceCores INTEGER NOT NULL,
                numCreditsOpenElectives INTEGER NOT NULL,
                minCGPA INTEGER NOT NULL
                );';
    EXECUTE query; 
end; $$;
-- call addUGCurriculum(2019, 1);

-- @Dynamic Table
create table CurriculumList_{curriculumID}(
    courseCategory VARCHAR(20) NOT NULL,
    courseID integer NOT NULL,
    FOREIGN key(courseID) REFERENCES CourseCatalogue(courseID)
);

-- @Dynamic Table

/* procedure to add to CurriculumList */
create or replace procedure addCurriculumList(
    IN _batch INTEGER,
    IN _deptID INTEGER,
    IN _courseCategory VARCHAR(20),
    IN _courseID INTEGER
)
language plpgsql SECURITY DEFINER
as $$
declare
    tableName TEXT;
    alreadyExists INTEGER;
    curriculumID INTEGER;
    query TEXT;
begin
-- stored procedure body
    curriculumID := -1;
    SELECT UGCurriculum.curriculumID INTO curriculumID
    FROM UGCurriculum
    WHERE UGCurriculum.batch = _batch and UGCurriculum.deptID = _deptID; 

    IF curriculumID = -1 THEN
        raise notice 'UG Curriculum of entered batch and deptID not created';
        return;
    END IF;

    /* Create a dynamic table for the Curriculum List of the given curriculumID*/
    tableName := 'CurriculumList_' || curriculumID::text;
    query := 'INSERT INTO '|| tableName || '(courseCategory,courseID) 
                VALUES('||''''||_courseCategory::text||''' '||','|| _courseID::text||')';
    EXECUTE query; 
end; $$;

-- call addCurriculumList(2019, 1, 'Program Core', 1);
-- call addCurriculumList(2019, 1, 'Science Core', 4);


create table CurriculumRequirements_{curriculumID}(
    numCreditsProgramCores INTEGER NOT NULL,
    numCreditsProgramElectives INTEGER NOT NULL,
    numCreditsScienceCores INTEGER NOT NULL,
    numCreditsOpenElectives INTEGER NOT NULL,
    minCGPA NUMERIC(4,2) NOT NULL
);


/* procedure to add to CurriculumList */
create or replace procedure addCurriculumRequirements(
    IN _batch INTEGER,
    IN _deptID INTEGER,
    IN numCreditsProgramCores INTEGER,
    IN numCreditsProgramElectives INTEGER,
    IN numCreditsScienceCores INTEGER,
    IN numCreditsOpenElectives INTEGER,
    IN minCGPA NUMERIC(4,2) 
)
language plpgsql SECURITY DEFINER
as $$
declare
    tableName TEXT;
    alreadyExists INTEGER;
    curriculumID INTEGER;
    query TEXT;
begin
    curriculumID := -1;
    SELECT UGCurriculum.curriculumID INTO curriculumID
    FROM UGCurriculum
    WHERE UGCurriculum.batch = _batch and UGCurriculum.deptID = _deptID; 

    IF curriculumID = -1 THEN
        raise notice 'UG Curriculum of entered batch and deptID not created';
        return;
    END IF;

    /* Create a dynamic table for the Curriculum List of the given curriculumID*/
    tableName := 'CurriculumRequirements_' || curriculumID::text;
    query := 'INSERT INTO '|| tableName || '(numCreditsProgramCores,
            numCreditsProgramElectives,numCreditsScienceCores,numCreditsOpenElectives,minCGPA) 
            VALUES('||numCreditsProgramCores||','||
            numCreditsProgramElectives||','||
            numCreditsScienceCores||','||
            numCreditsOpenElectives||','||
            minCGPA::text||')';
    EXECUTE query; 
end; $$;

-- call addCurriculumRequirements(2019,1,25,15,10,10,5.0);
-- call addCurriculumRequirements(2019, 2,25,15,10,10, 5);


-- call calculate_current_cgpa(2);

create or replace procedure canGraduate(
    IN _studentID  INTEGER
)
language plpgsql  
as $$
declare
    currentCGPA Numeric(4,2);
    minCGPA Numeric(4,2);
    _deptID INTEGER;
    curriculumID INTEGER;
    _batch INTEGER;
    transcriptTable TEXT;
    curriculumList TEXT;
    undoneProgramCore INTEGER;
    undoneProgramElective INTEGER;
    undoneScienceCore INTEGER;
    undoneOpenElective INTEGER;
    CurriculumRequirementsTableName TEXT;
    query TEXT;
begin
    -- first find the deptId and batch of the student
    _deptID := -1;
    SELECT Student.deptID INTO _deptID
    FROM Student
    WHERE Student.studentID=_studentID;

    IF _deptID = -1 THEN
        raise notice 'Incorrect Department ID !!!';
        return;
    END IF;

    SELECT Student.batch INTO _batch
    FROM Student
    WHERE Student.studentID = _studentID;
    
    curriculumID := -1;
    select UGCurriculum.curriculumID into curriculumID
    from UGCurriculum
    where UGCurriculum.batch = _batch and UGCurriculum.deptID = _deptID;
    
    IF curriculumID = -1 THEN
        raise notice 'UG Curiculum for % batch and % department ID does not exists',_batch,_deptID;
        return;
    END IF;
    
    
    CurriculumRequirementsTableName := 'CurriculumRequirements_' || curriculumID::text;
    query:= 'SELECT minCGPA FROM '|| CurriculumRequirementsTableName;
    FOR minCGPA in EXECUTE query loop
        exit;
    end loop;


    -- Check if the student has a minimum of 5 CGPA or not
    CALL calculate_current_CGPA(_studentID, currentCGPA);
    raise notice 'Current CGPA is: %', currentCGPA;


    IF currentCGPA < minCGPA THEN
        raise notice 'CGPA criteria not satisfied as per the UG Curriculum!!!';
        return;
    END IF;

    -- find the curriculum id of the UG curriculum that the student is enrolled in
    SELECT UGCurriculum.curriculumID INTO curriculumID
    FROM UGCurriculum
    WHERE UGCurriculum.deptID = _deptID AND UGCurriculum.batch = _batch;

    -- Curriculum List for currcilumID
    curriculumList := 'CurriculumList_' || curriculumID::text;

    -- transcript table of the student
    transcriptTable := 'Transcript_' || _studentID::text;
    
    -- Check if the student has done all the courses mentioned in its program core

    query:= 'SELECT count(*) 
            FROM ' || curriculumList ||
            ' WHERE ' || curriculumList || '.courseCategory = ''Program Core'' 
                AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || ' 
                WHERE grade<>''F'' AND grade IS NOT NULL)';

    for undoneProgramCore IN EXECUTE query LOOP
        exit;
    END LOOP;

    IF undoneProgramCore <> 0 THEN 
        raise notice 'All Program Cores have not been completed!!!';
        return;
    END IF;

    -- Check if the student has done all the courses mentioned in its program electives

    query:= 'SELECT count(*) 
            FROM ' || curriculumList ||
            ' WHERE ' || curriculumList|| '.courseCategory=''Program Elective'' 
            AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || 
                                ' WHERE grade <>''F'' AND grade IS NOT NULL)';

    for undoneProgramElective IN EXECUTE query LOOP
        exit;
    END LOOP;

    IF undoneProgramElective <> 0 THEN 
        raise notice 'All Program Electives have not been completed!!!';
        return;
    END IF;

    -- Check if the student has done all the courses mentioned in its science core
    query:= 'SELECT count(*) FROM ' || curriculumList ||
    ' WHERE ' || curriculumList|| '.courseCategory=''Science Core'' 
    AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || 
    ' WHERE grade<>''F'' AND grade IS NOT NULL)';

    for undoneScienceCore IN EXECUTE query LOOP
        exit;
    END LOOP;

    IF undoneScienceCore<>0 THEN 
        raise notice 'All Science Cores have not been completed!!!';
        return;
    END IF;

    -- Check if the student has done all the courses mentioned in its open electives

    query:= 'SELECT count(*) FROM ' || curriculumList ||
    ' WHERE ' || curriculumList|| '.courseCategory = ''Open Elective'' 
    AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || 
    ' WHERE grade<>''F'' AND grade IS NOT NULL)';

    for undoneOpenElective IN EXECUTE query LOOP
        exit;
    END LOOP;

    IF undoneOpenElective <> 0 THEN 
        raise notice 'All Open Electives have not been completed!!!';
        return;
    END IF;

    raise notice 'Congratulations! You are eligible to graduate.';
end; $$;
call canGraduate(2);

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
