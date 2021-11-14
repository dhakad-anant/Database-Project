1. 5 umbrella categories of roles are created
        * Students
        * Faculty
        * BatchAdvisor
        * DeanAcademicsOffice
        * AcademicSection
        Under each of these roles, the persons are added DYNAMICALLY to each role 
        rather than giving permissions seperately for each new person 
                For example student with ID 5 needs to be added, it is added as student_5 under the category students
                For example faculty with ID 4 needs to be added, it is added as faculty_4 under the category faculty


2. Course Catalogue 
        The course catalogue can only be edited by DeanAcademicsOffice, although the other roles can view the course catalogue.
        Use the following APIs for this
        --> select * from viewCoursecatalogue();
        --> call addCourseCatalogue(@params);

3. Offering a course
        A seperate procedure call offerCourse is created for this purpose
        Only the faculty can call this procedure
        * call offerCourse(_courseOfferingID,_courseID, _semester,_year,_cgpa,_sectionID,_insID,allotedTimeSlotID,_list_batches[])
        
        Security Checks 
        * course should exist in the course catalogue since a course that does not exists in the course catalogue cannot be offered
        * CGPA requirements should be valid i.e. it should be in the range [0,10]
        * We check if this courseoffering already exist

2. @DYNAMIC Transcript Table for each student
        * With permissions such that no student can view transcript table of any other student.
        * Faculty_s, Batch Advisors, DeanAcademicsOffice, AcademicSection can view the Transcript of any student but not edit
        * Edit can be made by calling only some special APIs provided for the purpose. Note the security feature that even if instructor account is compromised he cannot destroy the entire transcript of that student. It can atmax affect the grade of the course which he was teching and student was enrolled in. 
        * Seperate procedure to export the transcript into a csv file. Again secuirty features handled.
        * Seperate procedure to print current CGPA of the student. No other student can print the CGPA of any other student.


3. Time Table uploaded
        /*  Stored Procedure for uploading timeTable slots through csv file */
        * call upload_timetable_slots()
        This Academic section is given the permission to use this procedure.
        This takes a csv file as input from the location C:\media\timetable and imports the data in the database. 


3. Security with respect to Grades
        * upload grades using csv
                call upload_grades_csv()
        * if we dont want to import all the grades together from a csv, and instead we want to update grade for a particular student only we can use another API named 
                update_grade(_sectionID, _studentID, _grade);
        Again it will check the security logins such that only the faculty who is teaching the course can update the grade and no other faculty can interfere with the grade.  


3. Tickets
        * Dynamic Table for each entity.
                For example student_1 has its own ticket table and cannot view the ticket table of student_2.
                Similarly each faculty, batchadvisor, dean has its own ticket table.

        * Who can raise a Ticket?
                Only the student itself can raise a ticket for itself no one else on his behalf can raise a ticket for him.
                
        * When can a Ticket be raised?
                * If the students batch is not allowed in the list of allowed batches
                * If he has not already called raised a ticket for the same cause before. Note that this is an important security feature as this avoids spamming the database and prevents its from actual hacking.
                * If the 1.25 rule is violated
                * If the CGPA criteria is not satisfied
                * If there is not a clash of time slot with existing course in the current semester and year.

        * View rights:
                Only the owner can see his/her table.

        * Write rights:
                Although one user can not directly write to the ticket table of the other, but ticket propogation is achieved with the help updateTicketTable stored procedurs and trigger functions which work with admin previliges. 

        * What happens when the DeanAcademicsOffice approve or reject the ticket?
                If the ticket is approved by the DeanAcademicsOffice, then the student is successfully registered in that course.
                If rejected then the notification regarding the same is sent to the student.


4. UG Curriculum
        * ug curriculum table
        We have provided an API to create UG Curiculum corresponding for each batch and department DYNAMICALLY.
        Note that we are not doing doing any hardcoding by making the tables static. Instead tables are created dynamically as per the input.
        
        For example if we want to add UG Curiculum corresponding to CSE department of 2018 batch 
        then we can first call the following 3 APIs in the same order
        with _batch = 2018 and _deptID = 1 (Assuming 1 for 'CSE')
        
        * call addUGCurriculum(_batch, _deptID);
        
        The are 4 possible course categories 
                1. Program Core
                2. Science Core
                3. Program Elective
                4. Open Elective
        * call addCurriculumList(_batch, _deptID, _courseCategory, _courseID);
        
        This function is self explanatory
        * call addCurriculumRequirements(_batch, _deptID, numCreditsProgramCores, numCreditsProgramElectives, numCreditsScienceCores, numCreditsOpenElectives, minCGPA)

        Finally this function is the core of the UG CUGCurriculum, this function will check whether the student can graduate or not as per the UG Curcilum defined above. 
                * call canGraduate(_studentID)
        Security Features:
        * No other student can check whether some other student can graduate or not. But the Facultys, BatchAdvisors, DeanAcademicsOffice, Academics Section can check whether the student can graduate or not. 










