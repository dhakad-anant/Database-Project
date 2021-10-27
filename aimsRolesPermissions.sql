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


GRANT INSERT
ON Teaches 
TO Faculty;

GRANT INSERT, UPDATE, DELETE
ON Teaches 
TO Faculty, DeanAcademicsOffice;

GRANT SELECT
ON CourseOffering 
TO Faculty; 



