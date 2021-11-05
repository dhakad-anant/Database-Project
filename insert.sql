call upload_timetable_slots();
/* CREATE TABLE TimeSlot(
    timeSlotID INTEGER NOT NULL,
    slotName VARCHAR(20) UNIQUE NOT NULL,
    duration INTEGER NOT NULL, -- in minutes
    monday VARCHAR(20),
    tuesday VARCHAR(20),
    wednesday VARCHAR(20),
    thursday VARCHAR(20),
    friday VARCHAR(20),
    
    PRIMARY KEY(timeSlotID)
);*/
/* 
    TimeslotId,TimeSlotName,Duration (mins),Monday,Tuesday,Wednesday,Thrusday,Friday
    1,PCE1,50,9:00 AM,10:00 AM,11:00 AM,12:00 PM,1:00 PM
    2,PCE2,50,2:00 PM,3:00 PM,4:00 PM,5:00 PM,6:00 PM
    3,PCE3,50,10:00 AM,11:00 AM,12:00 PM,1:00 AM,2:00 PM
    4,PCE4,50,3:00 PM,4:00 PM,5:00 PM,6:00 PM,7:00 PM 
*/

INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (7,'CS101',3,1,2,6,4);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (8,'CS102',3,1,2,6,4);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (9,'CS103',3,1,3,6,4);

INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (10,'CS104',3,1,3,6,0.5);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (11,'MA101',3,1,3,6,3);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (12,'MA202',3,1,3,6,3);

INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (1,'CS201',3,1,2,6,3);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (2,'CS202',3,1,2,6,4);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (3,'CS203',3,1,3,6,4);

INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (4,'CS301',3,1,2,6,4);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (5,'CS302',3,1,0,5,3);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (6,'CS303',3,1,2,6,4);
  
INSERT INTO PreRequisite(courseID,preReqCourseID) VALUES (4,1); -- CS301 -> CS201
INSERT INTO PreRequisite(courseID,preReqCourseID) VALUES (4,2); -- CS301 -> CS202
INSERT INTO PreRequisite(courseID,preReqCourseID) VALUES (5,2); -- CS302 -> CS202
INSERT INTO PreRequisite(courseID,preReqCourseID) VALUES (6,3); -- CS303 -> CS203

INSERT INTO Department(deptID, deptName) VALUES (1, 'COMPUTER SCIENCE');
INSERT INTO Department(deptID, deptName) VALUES (2, 'ELECTRICAL');
INSERT INTO Department(deptID, deptName) VALUES (3, 'MECHANICAL');
INSERT INTO Department(deptID, deptName) VALUES (4, 'CHEMICAL');
INSERT INTO Department(deptID, deptName) VALUES (5, 'CIVIL');
     
INSERT INTO Instructor(insID,insName, deptID) VALUES (1, 'Viswanath Gunturi',1);
INSERT INTO Instructor(insID,insName, deptID) VALUES (2, 'Brijesh Kumbhani',2);
INSERT INTO Instructor(insID,insName, deptID) VALUES (3, 'Apurva Mudgal',1);
INSERT INTO Instructor(insID,insName, deptID) VALUES (4, 'Balwinder Sodhi',1);


INSERT INTO DeanAcademicsOfficeTable(insID) VALUES(3);


/* 2019 batch */
INSERT INTO Student(studentID, batch, deptID, entryNumber,Name) VALUES(1, 2019, 1, '2019CSB1061', 'student1');
INSERT INTO Student(studentID, batch, deptID, entryNumber,Name) VALUES(2, 2019, 2, '2019EEB1062', 'student2');
/* 2018 batch */
INSERT INTO Student(studentID, batch, deptID, entryNumber,Name) VALUES(3, 2018, 1, '2018CSB1063', 'student3');
INSERT INTO Student(studentID, batch, deptID, entryNumber,Name) VALUES(4, 2018, 3, '2018MEB1064', 'student4');

-- offerCourse(_courseOfferingID,_courseID,_semester,_year,_cgpa,_sectionID,_insID,allotedTimeSlotID,_list_batches); 

set role faculty_1;
call offerCourse(1,1,1,2,8,1,1,1,'{2019,2018}'::integer[]); /* CS201 criteria */
set role faculty_2;
call offerCourse(2,2,2,2,7,2,2,1,'{2019,2018}'::integer[]); /* CS202 criteria */
set role faculty_3;
call offerCourse(3,3,1,2,6,3,3,2,'{2019,2018}'::integer[]); /* CS203 criteria */

set role faculty_3;
call offerCourse(12,10,1,2,6,12,3,1,'{2019,2018}'::integer[]); /* CS101 criteria */

set role faculty_4;
call offerCourse(4,4,1,3,7.5,4,4,1,'{2019}'::integer[]); /* CS301 Criteria */
set role faculty_1;
call offerCourse(5,5,1,3,6.5,5,1,2,'{2019}'::integer[]); /* CS302 criteria */
set role faculty_2;
call offerCourse(6,6,1,3,4.5,6,2,3,'{2019}'::integer[]); /* CS303 criteria */

set role faculty_1;
call offerCourse(7,7,1,1,0,7,1,1,'{2019,2018}'::integer[]); /* CS101 criteria */
set role faculty_2;
call offerCourse(8,8,2,1,0,8,2,1,'{2019,2018}'::integer[]); /* CS102 criteria */
set role faculty_3;
call offerCourse(9,9,1,1,0,9,3,2,'{2019,2018}'::integer[]); /* CS103 criteria */
reset role;
INSERT INTO GradeMapping(grade, val)
    values('A', 10),
          ('A-', 9),
          ('B', 8),
          ('B-', 7),
          ('C', 6),
          ('C-', 5),
          ('F', 0);

-- CREATE OR REPLACE PROCEDURE RegisterStudent(
--     IN _studentID INTEGER,
--     IN _courseID INTEGER,
--     IN _semester INTEGER,
--     IN _year INTEGER,
--     IN _insID INTEGER,
--     IN _timeSlotID INTEGER
-- )

-- RegisterStudent(_studentID,_courseID,_semester,_year,_insID,_timeSlotID)
SET ROLE student_1;
call RegisterStudent(1,7,1,1,1,1);
SET ROLE student_1;
call RegisterStudent(1,8,2,1,2,1);
SET ROLE student_1;
call RegisterStudent(1,9,1,1,3,2);
RESET ROLE;

SET ROLE student_1;
call RegisterStudent(1,1,1,2,1,1);
call RegisterStudent(1,10,1,2,3,1); -- To check timeslot clash

SET ROLE student_2;
call RegisterStudent(2,7,1,1,1,1);
RESET ROLE;
SET ROLE student_2;
call RegisterStudent(2,8,2,1,2,1);
RESET ROLE;
SET ROLE student_2;
call RegisterStudent(2,9,1,1,3,2);
call registerstudent(2,10,1,2,3,1);
RESET ROLE;

SET ROLE student_3;
call RegisterStudent(3,7,1,1,1,1);
RESET ROLE;
SET ROLE student_3;
call RegisterStudent(3,8,2,1,2,1);
RESET ROLE;
SET ROLE student_3;
call RegisterStudent(3,9,1,1,3,2);
RESET ROLE;

SET ROLE faculty_1;
CALL upload_grades_csv(7);
SET ROLE faculty_2;
CALL upload_grades_csv(8);
RESET ROLE;

-- 13, 32
set role student1;
call raiseticket(1,4,4,1,3,1);
reset role;

call addUGCurriculum(2019,1); 
call addCurriculumList(2019, 1, 'Program Core', 7);
call addCurriculumRequirements(2019, 1, 10, 10, 10, 10, 7.50);