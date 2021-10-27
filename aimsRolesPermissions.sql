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

REVOKE ALL 
ON PROCEDURE transfer 
FROM joe;

REVOKE ALL 
ON accounts
FROM joe;

Grant UPDATE 
ON accounts
to joe;