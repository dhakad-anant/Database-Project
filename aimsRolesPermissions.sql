/* *Major Stakeholders*
-- now other roles can simply inherit all privileges from these major stakeholders.
*/
CREATE ROLE Students;
CREATE ROLE Faculty;
CREATE ROLE BatchAdvisor;

CREATE ROLE DeanAcademicsOffice with 
    login password 'deanacademicsoffice';


/* Giving permission to DeanAcademicsOffice to read file */
grant pg_read_server_files to DeanAcademicsOffice;

/* optional */
CREATE ROLE academicsection with 
    LOGIN PASSWORD 'academicsection'
    IN ROLE pg_read_server_files;

GRANT SELECT 
ON TimeSlot 
TO Students, Faculty, BatchAdvisor, DeanAcademicsOffice;

/* giving all permissions on TimeSlot table to academicsection & DeanAcademicsOffice */
GRANT ALL 
ON TimeSlot 
TO academicsection, DeanAcademicsOffice;

/* revoking all permissions on procedure from public */
REVOKE ALL 
ON PROCEDURE upload_timetable_slots 
FROM PUBLIC;

/* Now only academic section can use this procedure */
GRANT EXECUTE 
ON PROCEDURE upload_timetable_slots 
TO academicsection, DeanAcademicsOffice;

/* Only deanacademicsoffice can edit the coursecatalogue */
GRANT ALL 
ON CourseCatalogue 
TO deanacademicsoffice;

/* Giving sequence permission to deanacademicsoffice */
GRANT USAGE, SELECT 
ON ALL SEQUENCES IN SCHEMA public 
TO DeanAcademicsOffice;
