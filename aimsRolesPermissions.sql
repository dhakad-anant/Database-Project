1. Students
2. Faculty
3. BatchAdvisor 
4. DeanAcademicsOffice

/* *Major Stakeholders*
    -- now other roles can simply inherit all privileges from these major stakeholders.
*/
CREATE ROLE Students;
CREATE ROLE Faculty;
CREATE ROLE BatchAdvisor;
CREATE ROLE DeanAcademicsOffice;

/* optional */
CREATE ROLE academicsection with 
    LOGIN PASSWORD 'academicsection'
    IN ROLE pg_read_server_files;

GRANT INSERT
ON Teaches 
TO Faculty;

GRANT INSERT, UPDATE, DELETE
ON Teaches 
TO Faculty, DeanAcademicsOffice;

GRANT SELECT
ON CourseOffering 
TO Faculty; 

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