CREATE TABLE Actor(
    a_id INTEGER NOT NULL,
    name VARCHAR(15) NOT NULL,
    Primary Key(a_id)
);


CREATE TABLE ProductionCompany(
    pc_id INTEGER NOT NULL,
    name  VARCHAR(10) NOT NULL,
    address VARCHAR(30) NOT NULL,
    PRIMARY KEY(pc_id)
);


CREATE TABLE Movie(
    m_id INTEGER NOT NULL,
    name VARCHAR(10) NOT NULL,
    year INTEGER NOT NULL,
    imdbScore NUMERIC(2,1) NOT NULL,
    pc_id INTEGER NOT NULL,
    Primary KEY(m_id),
    FOREIGN KEY(pc_id) REFERENCES ProductionCompany(pc_id) 
);

CREATE TABLE Movie2(
    m_id INTEGER NOT NULL,
    name VARCHAR(10) NOT NULL,
    year INTEGER NOT NULL,
    imdbScore NUMERIC(10,9) NOT NULL,
    pc_id INTEGER NOT NULL,
    Primary KEY(m_id),
    FOREIGN KEY(pc_id) REFERENCES ProductionCompany(pc_id) 
);

ALTER TABLE Movie RENAME COLUMN productioncompany TO pc_id;

CREATE TABLE Casting(
    m_id INTEGER NOT NULL,
    a_id INTEGER NOT NULL,
    PRIMARY KEY(m_id,a_id),
    FOREIGN KEY(m_id) REFERENCES Movie(m_id),
    FOREIGN KEY(a_id) REFERENCES Actor(a_id)
);