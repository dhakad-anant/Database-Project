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


INSERT INTO CourseOffering(courseOfferingID,courseID,semester,year,cgpaRequired,timeSlotID) VALUES (1,4,1,3,7.5,1);
INSERT INTO CourseOffering(courseOfferingID,courseID,semester,year,timeSlotID) VALUES (2,5,1,3,2);
INSERT INTO CourseOffering(courseOfferingID,courseID,semester,year,timeSlotID) VALUES (3,6,1,3,1);


INSERT INTO BatchesAllowed(CourseOfferingID,Batch) VALUES
    (1,2019), 
    (2,2019);

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