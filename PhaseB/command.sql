DELETE FROM Actor;
DELETE FROM ProductionCompany;
DELETE FROM Movie;
DELETE FROM Casting;

COPY Actor FROM 'C:\mediafordbms\actor.csv' DELIMITER ',' CSV HEADER;
COPY ProductionCompany FROM 'C:\mediafordbms\production_company.csv' DELIMITER ',' CSV HEADER;
COPY Movie FROM 'C:\mediafordbms\movie.csv' DELIMITER ',' CSV HEADER;
COPY Casting FROM 'C:\mediafordbms\casting.csv' DELIMITER ',' CSV HEADER;

/* creating indexes */
-- (a) a_id in the actor table
    -- already exists with Name 'actor_pkey'

-- (b) m_id in the movie table
    -- already exists with Name 'movie_pkey'

-- (c) imdb score in the movie table
CREATE INDEX movie_imdbscore 
ON movie USING btree(imdbscore);

-- (d) year in the movie
CREATE INDEX movie_year 
ON movie USING btree(year);

-- (e) m_id in the casting table
CREATE INDEX casting_m_id 
ON casting USING btree(m_id);

-- (f) a_id in the casting table
CREATE INDEX casting_a_id 
ON casting USING btree(a_id);

-- (g) pc_id in movie table
CREATE INDEX movie_fk_pc_id 
ON movie USING btree(pc_id);
/* -------------- -------------- -------------- -------------- -------------- --------------*/

EXPLAIN ANALYZE

/* Part A: Experimenting with Query Selectivity */
Query1: EXPLAIN ANALYZE SELECT name FROM movie WHERE imdbscore < 2;
Query2: EXPLAIN ANALYZE SELECT name FROM movie WHERE imdbscore between 1.5 and 4.5;
Query3: EXPLAIN ANALYZE SELECT name FROM movie WHERE year between 1900 and 1990;
Query4: EXPLAIN ANALYZE SELECT name FROM movie WHERE year between 1990 and 1995;
Query5: EXPLAIN ANALYZE SELECT * FROM movie WHERE pc_id < 50;
Query6: EXPLAIN ANALYZE SELECT * FROM movie WHERE pc_id > 20000;
/* -------------- -------------- -------------- -------------- -------------- --------------*/

-- Actor(a_id::int, name::varchar(15));
-- ProductionCompany(pc_id::int, name::varchar(10), address::varchar(10));
-- Movie(m_id::int, name::varchar(10), year::int, imdbscore::numeric, pc_id::int);
-- Casting(m_id::int, a_id::int);

/* Part B: Join Strategies */
-- Q1: Join Actor, Movie and Casting; Where a_id < 50; finally, the query outputs actor name and movie name ?
EXPLAIN ANALYZE 
select actor.name, movie.name
from actor, movie, casting 
where actor.a_id < 50 and 
    casting.a_id = actor.a_id and 
    casting.m_id = movie.m_id;

-- Q2: Join Actor and Casting; Where m_id < 50; finally, the query outputs actor name
EXPLAIN ANALYZE 
select actor.name
from actor, casting 
where casting.m_id < 50 and 
    casting.a_id = actor.a_id;
    
-- Q3: Join Movie and Production Company; where imdb score is less than 1.5. Finally, the query outputs the movie name and production company.
EXPLAIN ANALYZE 
select M.name, PC.name
from Movie as M, ProductionCompany as PC
where imdbscore < 1.5 and  
    M.pc_id = PC.pc_id;


-- Q4: Join Movie and Production Company; where year is between 1950 and 2000. Finally, the query outputs the movie name and production company.
EXPLAIN ANALYZE 
select M.name, PC.name
from Movie as M, ProductionCompany as PC 
where M.pc_id = PC.pc_id and 
    year between 1950 and 2000;
/* -------------- -------------- -------------- -------------- -------------- -------------- */


/* Command to list all indexes in a database */
SELECT
    tablename,indexname,indexdef
FROM
    pg_indexes
WHERE
    schemaname = 'public'
ORDER BY
    tablename,indexname;
/* -------------- -------------- -------------- -------------- -------------- -------------- */


/* Command for finding number of disk pages and # rows in a table*/
SELECT relname, relpages, reltuples FROM pg_class WHERE relname = 'tableName';
/* -------------- -------------- -------------- -------------- -------------- -------------- */


SELECT
    tablename,indexname,indexdef
FROM pg_indexes WHERE schemaname = 'public' ORDER BY tablename,indexname;