INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (1,'CS201',3,1,2,6,4);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (2,'CS202',3,1,2,6,4);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (3,'CS203',3,1,3,6,4);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (4,'CS301',3,1,2,6,4);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (5,'CS302',3,1,0,5,3);
INSERT INTO CourseCatalogue(CourseID,courseCode,L,T,P,S,C) VALUES (6,'CS303',3,1,2,6,4);
  

INSERT INTO PreRequisite(courseID,preReqCourseID) VALUES (4,1); -- CS301 -> CS201
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
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(1, 2019, 1, '2019CSB1060', 'student1');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(2, 2019, 1, '2019CSB1061', 'student2');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(3, 2019, 2, '2019EEB1062', 'student3');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(4, 2019, 2, '2019EEB1063', 'student4');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(5, 2019, 3, '2019MEB1064', 'student5');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(6, 2019, 3, '2019MEB1065', 'student6');
/* 2018 batch */
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(7, 2018, 1, '2018CSB1060', 'student7');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(8, 2018, 1, '2018CSB1061', 'student8');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(9, 2018, 2, '2018EEB1062', 'student9');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(10, 2018, 2, '2018EEB1063', 'student10');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(11, 2018, 3, '2018MEB1064', 'student11');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(12, 2018, 3, '2018MEB1065', 'student12');
/* 2017 batch */
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(13, 2017, 1, '2017CSB1060', 'student13');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(14, 2017, 1, '2017CSB1061', 'student14');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(15, 2017, 2, '2017EEB1062', 'student15');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(16, 2017, 2, '2017EEB1063', 'student16');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(17, 2017, 3, '2017MEB1064', 'student17');
INSERT INTO Student(studentID, batch, deptID, entryNumber) VALUES(18, 2017, 3, '2017MEB1065', 'student18');


call offerCourse(1,1,1,2,8,1,1,1,'{2019,2018}'); /* CS201 criteria */
call offerCourse(2,2,2,2,7,2,2,1,'{2019,2018}'); /* CS202 criteria */
call offerCourse(3,3,1,2,6,3,3,2,'{2019,2018}'); /* CS203 criteria */
call offerCourse(4,4,1,3,7.5,4,4,1,'{2019}'); /* CS301 Criteria */
call offerCourse(5,5,1,3,6.5,5,5,2,'{2019}'); /* CS302 criteria */
call offerCourse(6,6,1,3,4.5,6,6,3,'{2019}'); /* CS303 criteria */


INSERT INTO BatchesAllowed(CourseOfferingID,Batch) VALUES (1,2019); 
INSERT INTO BatchesAllowed(CourseOfferingID,Batch) VALUES (2,2019); 
INSERT INTO BatchesAllowed(CourseOfferingID,Batch) VALUES (3,2019); 
INSERT INTO BatchesAllowed(CourseOfferingID,Batch) VALUES (4,2019); 
INSERT INTO BatchesAllowed(CourseOfferingID,Batch) VALUES (5,2019); 
INSERT INTO BatchesAllowed(CourseOfferingID,Batch) VALUES (6,2019); 


INSERT INTO Teaches(insID,CourseID,sectionID,semester,year,timeSlotID) VALUES
    (1,4,1,1,3,1),
    (2,5,2,1,3,2),
    (4,6,3,1,3,1);

INSERT INTO Student(studentID,batch,deptID,entryNumber,Name) VALUES
    (1,2019,1,'2019CSB1070','A'),
    (2,2019,2,'2019EEB1107','B'),
    (3,2019,3,'2019MEB1130','C'),
    (4,2018,1,'2018CSB1070','AA'),
    (5,2018,2,'2018EEB1107','BB'),
    (6,2018,3,'2018MEB1130','CC');

INSERT INTO GradeMapping(grade, val)
    values('A', 10),
          ('A-', 9),
          ('B', 8),
          ('B-', 7),
          ('C', 6),
          ('C-', 5),
          ('F', 0);

CREATE OR REPLACE PROCEDURE RegisterStudent(
    IN _studentID INTEGER,
    IN _courseID INTEGER,
    IN _semester INTEGER,
    IN _year INTEGER,
    IN _insID INTEGER,
    IN _timeSlotID INTEGER
)




/* **************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************************** */
insert into course_catalogue(course_id, name, L, T, P) values ('CS303', 'Operating System', 5, 5, 5); 
insert into course_catalogue(course_id, name, L, T, P) values ('CS203', 'Pta nahi System', 5, 5, 5); 
insert into course_catalogue(course_id, name, L, T, P) values ('CS201', 'Data sturcture', 5, 5, 5); 
insert into course_catalogue(course_id, name, L, T, P) values ('CS202', 'Dekh lo', 5, 5, 5); 
insert into prerequisites(course_id, prerequisite_course_id) values ('CS303', 'CS203'); 
insert into prerequisites(course_id, prerequisite_course_id) values ('CS303', 'CS202'); 
insert into prerequisites(course_id, prerequisite_course_id) values ('CS303', 'CS201'); 
insert into course_offering(course_id, year, semester, section_id, instructor_id, classroom, cgpa_requirement, slot_number) 
values ('CS301', 2000, 2, 'two', 'VSCS301', 'dekh lo', 8.2, 3); 
insert into time_slots(monday_start, monday_end, tuesday_start, tuesday_end, wednesday_start, wednesday_end, thursday_start, thursday_end, friday_start, friday_end) values ('16:00', '17:00', '10:20', '11:20', '9:00', '10:00', '14:45', '15:20', '8:00', '8:30'); 
insert into taken(offering_id, student_id) values (3, '2019CS1067'); 
  
CREATE TABLE program_elective_2021( 
course_id varchar(20) not null, 
department varchar(20) not null, 
PRIMARY KEY(course_id)  
); 
insert into program_elective_2021(course_id, department) values    ('CS302','cse'); 

CREATE TABLE program_core_elective_2021( 
course_id varchar(20) not null, 
department varchar(20) not null, 
PRIMARY KEY(course_id)  
); 
insert into program_core_elective_2021(course_id, department) values    ('CS302','cse'); 

CREATE TABLE science_core_elective_2021( 
course_id varchar(20) not null, 
department varchar(20) not null, 
PRIMARY KEY(course_id)  
); 
insert into science_core_elective_2021(course_id, department) values    ('CS302','cse'); 

CREATE TABLE open_elective_2021( 
course_id varchar(20) not null, 
department varchar(20) not null, 
PRIMARY KEY(course_id)  
); 
insert into open_elective_2021(course_id, department) values    ('CS302','cse'); 

insert into credit_requirement_to_graduate(batch,program_core_credit,science_core_credit,open_elective_credit,program_elective_credit) values(2019,1,1,1,1);