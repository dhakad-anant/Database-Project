CREATE TABLE CourseCatalogue(
    -- courseID INTEGER NOT NULL,
    courseID SERIAL PRIMARY KEY,
    courseCode VARCHAR(10) NOT NULL,
    L INTEGER NOT NULL,
    T INTEGER NOT NULL,
    P INTEGER NOT NULL,
    S INTEGER NOT NULL,
    C INTEGER NOT NULL,
    -- semester INTEGER NOT NULL,
    -- year INTEGER NOT NULL,
    -- PRIMARY KEY(courseID, semester, year)
    -- PRIMARY KEY(courseID)
);

CREATE TABLE PreRequisite(
    courseID INTEGER NOT NULL,
    preReqCourseID INTEGER NOT NULL,
    FOREIGN KEY(courseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE,
    FOREIGN KEY(preReqCourseID) REFERENCES CourseCatalogue(courseID) ON DELETE CASCADE
);

CREATE TABLE Department(
    deptID SERIAL PRIMARY KEY,
    deptName VARCHAR(20) not null,
    -- PRIMARY Key(deptID)
);

CREATE TABLE Instructor(
    insID SERIAL PRIMARY KEY,
    deptID INTEGER not NULL,
    -- PRIMARY KEY(insID),
    FOREIGN key(deptID) REFERENCES Department(deptID), 
);