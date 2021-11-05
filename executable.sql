-- DROP DATABASE IF EXISTS aims;

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
GRANT SELECT ON CourseCatalogue TO Students, Faculty, BatchAdvisor,AcademicSection;

CREATE OR REPLACE PROCEDURE addCourseCatalogue(
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
        VALUES(_courseID, _courseCode, _L, _T, _P, _S, _C);
end; $$;
REVOKE ALL ON PROCEDURE addCourseCatalogue FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE addCourseCatalogue TO deanacademicsoffice;

CREATE OR REPLACE FUNCTION viewCourseCatalogue()
RETURNS TABLE(
        courseID INTEGER,
        courseCode VARCHAR(10),
        L INTEGER,
        T INTEGER,
        P INTEGER,
        S INTEGER,
        C Numeric(4,2)
    )
language plpgsql SECURITY DEFINER
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
-- To use this function, type the command:
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
GRANT SELECT ON PreRequisite TO Faculty, BatchAdvisor, Students,AcademicSection;
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
    roleName := 'batchadvisor_' || deptID::text;
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
GRANT SELECT ON Instructor to Students,Faculty,BatchAdvisor,AcademicSection;


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
GRANT EXECUTE ON PROCEDURE  viewInstructors TO deanacademicsoffice,AcademicSection,Students,Faculty,BatchAdvisor;

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
GRANT SELECT ON CourseOffering to Students,Faculty,BatchAdvisor,AcademicSection;
-- select * from courseOffering;

-- DROP TABLE IF EXISTS BatchesAllowed;
CREATE TABLE BatchesAllowed(
    CourseOfferingID INTEGER NOT NULL,
    Batch INTEGER NOT NULL,
    PRIMARY KEY(courseOfferingID,Batch),
    FOREIGN KEY(courseOfferingID) REFERENCES CourseOffering(courseOfferingID) 
);
GRANT ALL ON BatchesAllowed to DeanAcademicsOffice;
GRANT SELECT ON BatchesAllowed to Students, Faculty, BatchAdvisor,AcademicSection;

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
GRANT SELECT ON Teaches to BatchAdvisor,Students,Faculty, AcademicSection;

CREATE OR REPLACE PROCEDURE InsertIntoTeaches(
    IN _insID INTEGER,
    IN _courseID INTEGER, 
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _allotedTimeSlotID INTEGER,
    IN _sectionID INTEGER
)
language plpgsql SECURITY DEFINER
as $$   
declare
    tableName TEXT;
    query TEXT;
    roleName TEXT;
BEGIN   
    INSERT INTO Teaches(insID,courseID,semester,year,timeSlotID,sectionID) 
        VALUES(_insID,_courseID,_semester,_year,_allotedTimeSlotID,_sectionID);
    
    /* Creating a dynamic table for each section */
    tableName := 'FacultyGradeTable_' || _sectionID::text;
    query := 'CREATE TABLE ' || tableName;
    query := query || '
        (
            studentID INTEGER NOT NULL,
            grade VARCHAR(2),
            PRIMARY KEY(studentID)
        );';    
    EXECUTE query;

    roleName := 'faculty_' || _insID::text;
    query := 'GRANT SELECT ON '||tableName||' TO ' || roleName;
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

    CALL InsertIntoTeaches(_insID,_courseID,_semester,_year,allotedTimeSlotID,_sectionID);
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
GRANT ALL ON Student to DeanAcademicsOffice,academicsection;
GRANT SELECT ON Student to Students, Faculty, BatchAdvisor;


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
    roleName := 'student_' || studentID::text;
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
    query := 'GRANT SELECT ON '|| tableName ||' to '||roleName||',Faculty, BatchAdvisor, DeanAcademicsOffice,AcademicSection';
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
    query := 'GRANT SELECT ON '|| tableName ||' to '||roleName||',Faculty, BatchAdvisor, DeanAcademicsOffice,AcademicSection';
    EXECUTE query;

    return new;
end; $$;  
REVOKE ALL ON PROCEDURE postInsertingStudent_trigger_function FROM PUBLIC;

CREATE TRIGGER postInsertingStudent
AFTER INSERT ON Student 
FOR EACH ROW
EXECUTE PROCEDURE postInsertingStudent_trigger_function();

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
    

    totalClashes INTEGER;

    courseCredit NUMERIC(4,2);
    currentCredit NUMERIC(4,2);
    prevCredit NUMERIC(10,2);
    prevPrevCredit NUMERIC(10,2);
    studentTrancriptTableName TEXT;
    averageCredits NUMERIC(10,2);
    maxCreditsAllowed NUMERIC(10,2);
    currentCGPA NUMERIC(4,2);
    cgpaRequired NUMERIC(4,2);
    _courseOfferingID INTEGER;
    _batch INTEGER;
    _isBatchAllowed INTEGER;


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

    
    /* START */
    /*  Cannot raise a ticket if neither 1.25 rule is violated nor CGPA criteria is vioalted nor batches allowed is violated */
    studentTrancriptTableName := 'transcript_' || _studentID::text; 

    query := 'SELECT count(*) 
                FROM  ' || studentTrancriptTableName ||' 
                WHERE ' || studentTrancriptTableName ||'.year = '|| _year::text||' 
                AND ' || studentTrancriptTableName||'.semester='||_semester::text||'
                AND ' || studentTrancriptTableName||'.timeSlotID=' || _timeSlotID::text;
    for totalClashes in EXECUTE query loop 
        exit;
    end loop;
    if totalClashes <> 0 then 
        raise notice 'Course with same time slot already enrolled in this semester ... Cannot raise a ticket !!!';
        return;
    end if;

    query := 'SELECT sum(CourseCatalogue.C)
            FROM ' || studentTrancriptTableName || ', CourseCatalogue
            WHERE ' || studentTrancriptTableName ||'.courseID = CourseCatalogue.courseID 
            AND ' ||studentTrancriptTableName || '.semester = ' || _semester::text ||
            ' AND ' ||studentTrancriptTableName || '.year = ' || _year::text;
    FOR currentCredit in EXECUTE query LOOP 
        exit;
    END LOOP;
    
    if currentCredit IS NULL then
        currentCredit := 0.0;
    end if;
    
    SELECT CourseCatalogue.C INTO courseCredit
    from CourseCatalogue
    where CourseCatalogue.courseId = _courseID;

    currentCredit := currentCredit + courseCredit;

    prevCredit := -1;
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

    if prevCredit = 0 OR prevcredit IS NULL then
        maxCreditsAllowed := 4;
    elsif prevPrevCredit = 0 OR prevPrevCredit IS NULL then
        maxCreditsAllowed := 4;
    else 
        averageCredits := (prevCredit + prevPrevCredit)/2;
        maxCreditsAllowed := averageCredits * 1.25;
    end if;

    
    call calculate_current_CGPA(_studentID,currentCGPA);
    select CourseOffering.cgpaRequired into cgpaRequired
    from CourseOffering
    where CourseOffering.courseID = _courseID 
        AND CourseOffering.semester = _semester 
        AND CourseOffering.year = _year;
    if cgpaRequired is NULL then 
        cgpaRequired := 0.0;
    end if;


    SELECT Student.batch into _batch
    From Student
    where Student.studentID = _studentID;    
    
    SELECT courseOffering.courseOfferingID INTO _courseOfferingID
    FROM CourseOffering
    WHERE CourseOffering.courseID = _courseID
        AND CourseOffering.semester = _semester
        AND CourseOffering.year = _year
        AND CourseOffering.timeSlotID = _timeSlotID;    
    
    SELECT count(*) INTO _isBatchAllowed 
    FROM BatchesAllowed
    WHERE BatchesAllowed.courseOfferingID = _courseOfferingID AND BatchesAllowed.batch = _batch;

    if (currentCredit <= maxCreditsAllowed) AND (currentCGPA >= cgpaRequired) AND (_isBatchAllowed <> 0) then 
        raise notice  'Neither 1.25 rule is violated, neither CGPA criteria is violated, nor batches allowed is violated. So cannot raise a ticket !!!';
        return;
    end if;
    /* END */
    call raiseTicketUtil(_insID,_studentID,_studentTicketID,_semester,_year,_timeSlotID,_courseID);  
END; $$;
REVOKE ALL ON PROCEDURE raiseTicket FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE raiseTicket to Students;


/* stored procedure for the faculty to update its ticket table */
CREATE OR REPLACE PROCEDURE updateFacultyTicketTableUtil(
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

CREATE OR REPLACE PROCEDURE updateFacultyTicketTable(
    IN _insID INTEGER,
    IN _studentTicketID INTEGER,  
    IN _studentID INTEGER,  
    IN _facultyVerdict BOOLEAN
)
language plpgsql SECURITY INVOKER
as $$
declare
    current_user_name TEXT;
    roleName TEXT;
begin
    roleName := 'faculty_' || _insID::text;
    SELECT current_user INTO current_user_name;
    if current_user_name <> roleName then
        raise notice 'Illegal Access. Current Logged in User is % and Trying to raise ticket for User %', current_user_name, roleName;
        return;     
    end if;
    call updateFacultyTicketTableUtil(_insID,_studentTicketID,_studentID,_facultyVerdict);
end; $$;
REVOKE ALL ON PROCEDURE updateFacultyTicketTable FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE updateFacultyTicketTable TO Faculty;
-- call updateFacultyTicketTable(1,1,1,1::boolean);



/* Stored procedure to update the ticket table of the batch advisor */
create or replace procedure updateBatchAdvisorTicketTableUtil(
    IN _deptID INTEGER,
    IN _studentTicketID INTEGER,  
    IN _studentID INTEGER,  
    IN _batchAdvisorVerdict BOOLEAN    
)
language plpgsql SECURITY DEFINER
as $$
DECLARE
    tableName text;
    query text;
    _insID INTEGER;
    _studentDeptID INTEGER;
    _validStudentTicketID INTEGER;
    _validStudent INTEGER;
BEGIN    
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

create or replace procedure updateBatchAdvisorTicketTable(
    IN _deptID INTEGER,
    IN _studentTicketID INTEGER,  
    IN _studentID INTEGER,  
    IN _batchAdvisorVerdict BOOLEAN    
)
language plpgsql SECURITY INVOKER
as $$
declare
    current_user_name TEXT;
    roleName TEXT;
    doesDepartmentExists INTEGER;
begin
    select count(*) into doesDepartmentExists 
    from Department 
    where Department.deptID = _deptID; 
    if doesDepartmentExists = 0 then
        raise notice 'Incorrect Deparment Name entered!';
        return;
    end if;
    roleName := 'batchadvisor_' || _deptID::text;
    SELECT current_user INTO current_user_name;
    if current_user_name <> roleName then
        raise notice 'Illegal Access. Current Logged in User is % and Trying to raise ticket for User %', current_user_name, roleName;
        return;     
    end if;
    call updateBatchAdvisorTicketTableUtil(_deptID,_studentTicketID,_studentID,_batchAdvisorVerdict);
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

        for _courseID, _semester, _year, _timeSlotID IN EXECUTE query loop 
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
language plpgsql SECURITY DEFINER  
as $$
declare
    transcriptTable TEXT;
    totalCredits    NUMERIC(10,2) := 0;
    numerator       NUMERIC(10,2) := 0;
    rec             record;
    CGPA            NUMERIC(4,2) := 0.0;
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
    else
        CGPA:=0;
    end if;
    currentCGPA := CGPA;
end; $$;

create or replace procedure print_current_CGPA(
    IN _studentID INTEGER 
)
language plpgsql SECURITY INVOKER   
as $$
declare
    transcriptTable TEXT;
    totalCredits    NUMERIC(10,2) := 0;
    numerator       NUMERIC(10,2) := 0;
    rec             record;
    CGPA            NUMERIC(4,2) := 0.0;
    query           TEXT;
    credits         NUMERIC(4,2);
    val             INTEGER;
begin
    transcriptTable := 'Transcript_' || _studentID::text;

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
    else
        CGPA:=0;
    end if;
    raise notice 'CGPA for student ID % is %',_studentID, CGPA;
end; $$;

CREATE OR REPLACE PROCEDURE exportTableIntoCSV(
    tableName text,
    _fileName text
)
language plpgsql SECURITY DEFINER
as $$
declare
    query text;
begin
    query := 'COPY '||tableName||' to ''C:\media\'||_fileName||'.csv'' DELIMITER '','' CSV HEADER';
    EXECUTE query;
end; $$;

CREATE OR REPLACE PROCEDURE exportTranscript(
    _studentID INTEGER
)
language plpgsql SECURITY INVOKER
as $$
DECLARE
    tableName text;
    _fileName text;
    rec record;
    query TEXT;
    doesStudentExist INTEGER;
BEGIN
    SELECT count(*) INTO doesStudentExist
    FROM Student
    WHERE Student.studentID = _studentID;
    if doesStudentExist = 0 then
        raise notice 'Student with ID: % does not exists',_studentID;
        return;
    end if;
    tableName := 'transcript_' || _studentID::text;
    query := 'SELECT * FROM '||tableName;
    for rec in EXECUTE query loop
        exit;
    end loop;
    _fileName := 'ReportStudent_' || _studentID::text;
    call exportTableIntoCSV(tableName, _fileName);
end; $$;
REVOKE ALL ON PROCEDURE exportTranscript FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE exportTranscript TO Students, Faculty, BatchAdvisor, DeanAcademicsOffice, AcademicSection;

create or replace procedure registerStudentUtil( 
    IN _courseID  INTEGER,
    IN  _semester  INTEGER,
    IN  _year  INTEGER,
    IN  _timeSlotID  INTEGER,
    IN  _studentID  INTEGER,
    IN _sectionID INTEGER
)
language plpgsql SECURITY DEFINER
as $$
declare
    query TEXT;
    studentTrancriptTableName TEXT;
    facultyGradeTableName TEXT;
begin
-- stored procedure body
    studentTrancriptTableName:= 'Transcript_' || _studentID::text;
    query := 'INSERT INTO ' || studentTrancriptTableName ||'(courseID, semester, year, timeSlotID) 
    VALUES ('||_courseID::text||','||_semester::text||','||_year::text||','||_timeSlotID::text||')';    
    EXECUTE query;

    facultyGradeTableName := 'FacultyGradeTable_' || _sectionID::text;
    query := 'INSERT INTO ' || facultyGradeTableName ||'(studentID) VALUES ('||_studentID::text||')';
    EXECUTE query;
end; $$;

-- call RegisterStudent(7,1,1,2,5,3);
CREATE OR REPLACE PROCEDURE RegisterStudent(
    IN _studentID INTEGER,
    IN _courseID INTEGER,
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _insID INTEGER,
    IN _timeSlotID INTEGER
)
language plpgsql SECURITY INVOKER
as $$
declare 
    studentTrancriptTableName text;
    facultyGradeTableName text;
    prevCredit NUMERIC(10,2);
    prevPrevCredit NUMERIC(10,2);
    averageCredits NUMERIC(10,2);
    maxCreditsAllowed NUMERIC(10,2);
    currentCredit NUMERIC(4,2);
    courseCredit NUMERIC(4,2);
    totalPreRequisite INTEGER;
    totalPreRequisiteSatisfied INTEGER;
    clash INTEGER;
    -- insId INTEGER;
    ifslot INTEGER;
    -- _timeSlotID INTEGER;
    -- _insID INTEGER;
    totalClashes INTEGER;
    currentCGPA NUMERIC(4,2);
    cgpaRequired NUMERIC(4,2);
    _courseOfferingID INTEGER;
    _doesInstructorExists INTEGER;
    _doesTeachesExists INTEGER;
    _doesTimeSlotExists  INTEGER;
    _doesStudentExists  INTEGER;
    -- _courseID INTEGER;
    query text;
    _sectionID INTEGER;
    current_user_name TEXT;
    roleName TEXT;
    _batch INTEGER;
    _isBatchAllowed INTEGER;
    
begin
    SELECT count(*) INTO _doesStudentExists
    FROM Student
    WHERE Student.studentID = _studentID;
    if _doesStudentExists = 0 then
        raise notice 'Invalid Student Id';
        return;
    end if;
    
    roleName := 'student_' || _studentID::text;
    SELECT current_user INTO current_user_name;
    if current_user_name <> roleName then
        raise notice 'Illegal Access. Current Logged in User is % and Trying to register %', current_user_name, roleName;
        return;     
    end if;

    --  Checking whether the instructor ID is valid
    SELECT count(*) INTO _doesInstructorExists
    FROM Instructor
    WHERE Instructor.insID = _insID;
    IF _doesInstructorExists = 0 THEN
        raise notice 'Instructor with id: % does not exist!',_insID;
        return;
    END IF;

    -- Check whether the course exists in the course offering or not
    _courseOfferingID := -1;
    SELECT courseOffering.courseOfferingID INTO _courseOfferingID
    FROM CourseOffering
    WHERE CourseOffering.courseID = _courseID
        AND CourseOffering.semester = _semester
        AND CourseOffering.year = _year
        AND CourseOffering.timeSlotID = _timeSlotID;
    IF _courseOfferingID = -1  OR _courseOfferingID IS NULL THEN 
        raise notice 'Course Offering does not exist !!!';
        return;
    END IF;

    SELECT Student.batch into _batch
    From Student
    where Student.studentID = _studentID;
    
    SELECT count(*) INTO _isBatchAllowed 
    FROM BatchesAllowed
    WHERE BatchesAllowed.courseOfferingID = _courseOfferingID AND BatchesAllowed.batch = _batch;

    if _isBatchAllowed = 0 then
        raise notice 'Sorry but your batch % is not present in the list of allowed batches', _batch;
        return;
    end if;

    -- check whether the teaches table have the entry for the given attributes
    SELECT count(*) INTO _doesTeachesExists
    FROM Teaches
    WHERE Teaches.courseID = _courseID
        AND Teaches.semester = _semester
        AND Teaches.year = _year
        AND Teaches.timeSlotID = _timeSlotID
        AND Teaches.insID=_insID;
    
    IF _doesTeachesExists = 0 THEN 
        raise notice 'This instuctor is not taking this course offering!!';
        return;
    END IF;


    -- Fetching the transcript table for each student
    studentTrancriptTableName:= 'Transcript_' || _studentID::text;
    query := 'SELECT sum(CourseCatalogue.C)
            FROM ' || studentTrancriptTableName || ', CourseCatalogue
            WHERE ' || studentTrancriptTableName ||'.courseID = CourseCatalogue.courseID 
            AND ' ||studentTrancriptTableName || '.semester = ' || _semester::text ||
            ' AND ' ||studentTrancriptTableName || '.year = ' || _year::text;
    FOR currentCredit in EXECUTE query LOOP 
        exit;
    END LOOP;
    
    if currentCredit IS NULL then
        currentCredit:=0.0;
    end if;
    -- Credit of the course that we are currently enrolling in
    SELECT CourseCatalogue.C INTO courseCredit
    from CourseCatalogue
    where CourseCatalogue.courseId = _courseID;

    currentCredit := currentCredit+ courseCredit;

    prevCredit := -1;
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


    if prevCredit = 0 OR prevcredit IS NULL then
        maxCreditsAllowed := 4;
    elsif prevPrevCredit = 0 OR prevPrevCredit IS NULL then
        maxCreditsAllowed := 4;
    else 
        averageCredits := (prevCredit + prevPrevCredit)/2;
        maxCreditsAllowed := averageCredits * 1.25;
    end if;
    if currentCredit > maxCreditsAllowed then 
        raise notice  'Credit Limit Exceeding !!!';
        return;
    end if;


    -- checking if the student fullfills all the required pre requisites 
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
    SELECT count(*) INTO _doesTimeSlotExists 
    FROM TimeSlot
    WHERE TimeSlot.timeSlotID = _timeSlotID;
    if _doesTimeSlotExists = 0 then
        raise notice 'Entered Time SLot does not exist !!!';
        return;
    end if;
    -- Checking for clashes in timeSlot    
    -- query := 'SELECT count(*)
    --         FROM ' || studentTrancriptTableName || ', Teaches
    --         WHERE '||studentTrancriptTableName||'.courseID = Teaches.courseID 
    --         AND '||studentTrancriptTableName||'.year = Teaches.year 
    --         AND '||studentTrancriptTableName||'.semester = Teaches.semester 
    --         AND '||studentTrancriptTableName||'.semester = $1 
    --         AND '||studentTrancriptTableName||'.year = $2
    --         AND teaches.insID = $3 
    --         AND teaches.timeSlotID= $4';
    query:= 'SELECT count(*) 
                FROM  ' || studentTrancriptTableName ||' 
                WHERE ' || studentTrancriptTableName ||'.year='||_year::text||' 
                AND ' || studentTrancriptTableName||'.semester='||_semester::text||'
                AND ' || studentTrancriptTableName||'.timeSlotID=' || _timeSlotID::text;
    for totalClashes in EXECUTE query loop 
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

    
    if cgpaRequired is NULL then 
        cgpaRequired:=0.0;
    end if;
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
        AND Teaches.insID = _insID 
        AND Teaches.timeSlotID = _timeSlotID;

    call registerStudentUtil(_courseID,_semester,_year,_timeSlotID,_studentID,_sectionID);    
end; $$; 
REVOKE ALL ON PROCEDURE RegisterStudent FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE RegisterStudent TO Students;

create or replace procedure upload_grades_csv_util(
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
        if temp_grade != 'N' OR temp_grade IS NOT NULL THEN            
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


create or replace procedure upload_grades_csv(
    IN _sectionID INTEGER
)
language plpgsql SECURITY INVOKER
as $$
declare
    current_user_name TEXT;
    _insID INTEGER;
    roleName TEXT;
begin
    _insID := -1;
    SELECT Teaches.insID INTO _insID
    FROM Teaches
    WHERE Teaches.sectionID = _sectionID;

    IF _insID = -1 OR _insID IS NULL THEN 
        raise notice 'Entered Section ID : % does not exists in the data base', _sectionID;
        return;
    END IF;

    roleName := 'faculty_' || _insID::text; 
    SELECT current_user INTO current_user_name;
    if current_user_name <> roleName then
        raise notice 'Illegal Access, current logged in user: % and actual faculty as per records: %', current_user_name, roleName;
        return;
    end if;

    call upload_grades_csv_util(_sectionID);
end; $$;
REVOKE ALL ON PROCEDURE upload_grades_csv FROM PUBLIC;
GRANT ALL ON PROCEDURE upload_grades_csv TO Faculty;

create or replace procedure update_grade_util(
    IN _sectionID INTEGER,
    IN _studentID INTEGER,
    IN _grade VARCHAR(2)
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
    ' SET grade = '||''''||_grade::text||''''||
    ' WHERE '||studentTrancriptTableName||'.courseID = '||courseID::text||
        ' AND '||studentTrancriptTableName||'.semester = '||semester::text||
        ' AND '||studentTrancriptTableName||'.year = '||year::text||
        ' AND '||studentTrancriptTableName||'.timeSlotID = '||timeSlotID::text;            
    EXECUTE query;             
    
    query :=  'UPDATE '||facultygradeTableName||' 
                SET grade = '||''''||_grade::text||''''||
                ' WHERE '||facultygradeTableName||'.studentID = '||_studentID::text;
    EXECUTE query;        
end; $$;


create or replace procedure update_grade(
    IN _sectionID INTEGER,
    IN _studentID INTEGER,
    IN _grade VARCHAR(2)
)
language plpgsql SECURITY INVOKER
as $$
declare 
    current_user_name TEXT;  
    roleName TEXT;  
    _insID INTEGER;
begin
    _insID := -1;
    SELECT Teaches.insID INTO _insID
    FROM Teaches
    WHERE Teaches.sectionID = _sectionID;

    IF _insID = -1 OR _insID IS NULL THEN 
        raise notice 'Entered Section ID : % does not exists in the data base', _sectionID;
        return;
    END IF;
    
    roleName := 'faculty_' || _insID::text; 
    SELECT current_user INTO current_user_name;
    if current_user_name <> roleName then
        raise notice 'Illegal Access, current logged in user: % and actual faculty as per records: %', current_user_name, roleName;
        return;
    end if;
    call update_grade_util(_sectionID, _studentID, _grade);  
end; $$;
REVOKE ALL ON PROCEDURE update_grade FROM PUBLIC;
GRANT ALL ON PROCEDURE update_grade TO Faculty;


CREATE TABLE UGCurriculum(
    curriculumID SERIAL,
    batch INTEGER NOT NULL,
    deptID INTEGER NOT NULL,
    PRIMARY KEY(curriculumID),
    FOREIGN KEY(deptID) REFERENCES Department(deptID)
);
GRANT ALL ON UGCurriculum TO DeanAcademicsOffice,AcademicSection;
GRANT SELECT ON UGCurriculum TO Students, Faculty, BatchAdvisor;

/* procedure to add a new UGCurriculum */
CREATE OR REPLACE PROCEDURE addUGCurriculum(
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
    query := 'GRANT ALL ON '||tableName||' TO DeanAcademicsOffice,AcademicSection';
    EXECUTE query;
    query := 'GRANT SELECT ON '||tableName||' TO Students, Faculty, BatchAdvisor';
    EXECUTE query;

    /* Create a dynamic table for the Curriculum Requirements of the given curriculumID*/
    tableName := 'CurriculumRequirements_' || curriculumID::text;
    query := 'CREATE TABLE '|| tableName || '(
                numCreditsProgramCores INTEGER NOT NULL,
                numCreditsProgramElectives INTEGER NOT NULL,
                numCreditsScienceCores INTEGER NOT NULL,
                numCreditsOpenElectives INTEGER NOT NULL,
                minCGPA NUMERIC(4,2) NOT NULL
                );';
    EXECUTE query;
    query := 'GRANT ALL ON '||tableName||' TO DeanAcademicsOffice,AcademicSection';
    EXECUTE query;
    query := 'GRANT SELECT ON '||tableName||' TO Students, Faculty, BatchAdvisor';
    EXECUTE query;
end; $$;
REVOKE ALL ON PROCEDURE addUGCurriculum FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE addUGCurriculum TO DeanAcademicsOffice, AcademicSection;

/* 
* procedure to add to CurriculumList 
*  List of Course Categories: (Case Sensative)
    1. Program Core
    2. Science Core
    3. Program Elective
    4. Open Elective
*/
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
    _doesCourseExists INTEGER;
begin
    curriculumID := -1;
    SELECT UGCurriculum.curriculumID INTO curriculumID
    FROM UGCurriculum
    WHERE UGCurriculum.batch = _batch and UGCurriculum.deptID = _deptID; 

    IF curriculumID = -1 OR curriculumID is NULL THEN
        raise notice 'UG Curriculum of entered batch and deptID not created';
        return;
    END IF;

    IF _courseCategory <> 'Program Core' AND _courseCategory <> 'Science Core' 
        AND _courseCategory <> 'Program Elective' AND _courseCategory <> 'Open Elective' THEN
        raise notice 'Invalid Course Category entered ... Please try again !!!';
        return;
    END IF;

    SELECT count(*) INTO _doesCourseExists 
    FROM CourseCatalogue
    WHERE CourseCatalogue.courseID = _courseID;
    if _doesCourseExists = 0 then 
        raise notice 'Course ID : % does not exists in the Course Catalogue', _courseID;
        return;
    end if;

    /* Create a dynamic table for the Curriculum List of the given curriculumID*/
    tableName := 'CurriculumList_' || curriculumID::text;
    query := 'INSERT INTO '|| tableName || '(courseCategory,courseID) 
                VALUES('||''''||_courseCategory::text||''' '||','|| _courseID::text||')';
    EXECUTE query; 
end; $$;
REVOKE ALL ON PROCEDURE addCurriculumList FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE addCurriculumList TO DeanAcademicsOffice, AcademicSection;
-- call addCurriculumList(2019, 1, 'Program Core', 1);
-- call addCurriculumList(2019, 1, 'Science Core', 4);


/* procedure to add to CurriculumList */
CREATE OR REPLACE PROCEDURE addCurriculumRequirements(
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

    IF curriculumID = -1 OR curriculumID is NULL THEN
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
REVOKE ALL ON PROCEDURE addCurriculumRequirements FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE addCurriculumRequirements TO DeanAcademicsOffice,AcademicSection;
-- call addCurriculumRequirements(2019,1,25,15,10,10,5.0);
-- call addCurriculumRequirements(2019, 2,25,15,10,10, 5);

-- call calculate_current_cgpa(2);
CREATE OR REPLACE PROCEDURE canGraduate(
    IN _studentID  INTEGER
)
language plpgsql SECURITY INVOKER
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
    rec record;
begin
    -- first find the deptId and batch of the student
    _deptID := -1;
    SELECT Student.deptID, Student.batch INTO _deptID, _batch
    FROM Student
    WHERE Student.studentID = _studentID;

    IF _deptID = -1 OR _deptID IS NULL THEN
        raise notice 'Student with ID: % does not exists !!!', _studentID;
        return;
    END IF;

    -- transcript table of the student
    transcriptTable := 'transcript_' || _studentID::text;
    query := 'SELECT *
            FROM '||transcriptTable;
    for rec in EXECUTE query loop
        exit;
    end loop;
    
    curriculumID := -1;
    select UGCurriculum.curriculumID into curriculumID
    from UGCurriculum
    where UGCurriculum.batch = _batch and UGCurriculum.deptID = _deptID;
    
    IF curriculumID = -1 OR curriculumID IS NULL THEN
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
        raise notice 'CGPA criteria of % not satisfied as per the UG Curriculum!!!', minCGPA;
        return;
    END IF;

    -- Curriculum List for currcilumID
    curriculumList := 'CurriculumList_' || curriculumID::text;

    -- Check if the student has done all the courses mentioned in its program core
    query:= 'SELECT count(*) 
            FROM ' || curriculumList ||
            ' WHERE ' || curriculumList || '.courseCategory = ''Program Core'' 
                AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || ' 
                WHERE grade IS NOT NULL AND grade<>''F'')';
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
                                ' WHERE grade IS NOT NULL AND grade<>''F'')';

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
    ' WHERE grade IS NOT NULL AND grade<>''F'')';

    for undoneScienceCore IN EXECUTE query LOOP
        exit;
    END LOOP;

    IF undoneScienceCore <> 0 THEN 
        raise notice 'All Science Cores have not been completed!!!';
        return;
    END IF;

    -- Check if the student has done all the courses mentioned in its open electives
    query:= 'SELECT count(*) FROM ' || curriculumList ||
    ' WHERE ' || curriculumList|| '.courseCategory = ''Open Elective'' 
    AND courseID NOT IN (SELECT courseID FROM ' || transcriptTable || 
    ' WHERE grade IS NOT NULL AND grade<>''F'')';
    for undoneOpenElective IN EXECUTE query LOOP
        exit;
    END LOOP;
    IF undoneOpenElective <> 0 THEN 
        raise notice 'All Open Electives have not been completed!!!';
        return;
    END IF;

    raise notice 'Congratulations! You are eligible to graduate !!!';
end; $$;
REVOKE ALL ON PROCEDURE canGraduate FROM PUBLIC;
GRANT EXECUTE ON PROCEDURE canGraduate TO Students, Faculty, BatchAdvisor, DeanAcademicsOffice, AcademicSection;
-- call canGraduate(2);

/* Giving sequence permission to deanacademicsoffice */
-- GRANT USAGE, SELECT 
-- ON ALL SEQUENCES IN SCHEMA public 
-- TO DeanAcademicsOffice;



