#define seq_page_cost 1.0
#define cpu_tuple_cost 0.01 
#define cpu_operator_cost  0.0025

-> Estimated total cost = (# disk pages read)*seq_page_cost + (# rows scanned)*cpu_tuple_cost -- + (# rows scanned)*cpu_operator_cost [if where clause is included]

-> If the percentage of the rows is smaller than 5-10% of all rows in the table the benefit of using the information stored in the index outweighs the additional intermediate step.

-> If the SELECT returns more than approximately 5-10% of all rows in the table, a sequential scan is much faster than an index scan.

-> This is because an index scan requires several IO operations for each row (look up the row in the index, then retrieve the row from the heap). Whereas a sequential scan only requires a single IO for each row - or even less because a block (page) on the disk contains more than one row, so more than one row can be fetched with a single IO operation.


*****************The Case(s) Of Postgres Not Using Index*************
Case 1: Table is very small
Case 2: Query is on one of the fields in multi index
Case 3: Query is returning almost all of the table
Case 4: When column data type and query data type don’t match
Case 5: When the query contains LIMIT
Case 6: Index is not present
*********************************************************************

-> INDEX ONLY SCAN  
-> Sequential SCAN
-> Bitmap SCAN


->> INDEX SCAN(very less # rows)  BITMAP(more rows than index but less than seq) SEQUENTIAL(large number of rows)




select sum(cnt) 
from (select imdbscore,count(*) as cnt
from movie 
group by imdbscore) as Res 
where imdbscore < 2;


select imdbscore,count(*) as cnt
from movie2 
group by imdbscore


(select imdbscore,count(*) as cnt
from movie 
group by imdbscore) as Res

select sum(cnt) 
from (select year,count(*) as cnt
from movie 
group by year) as res
where year between 1900 and 1990;


select pc_id
from (select pc_id, count(*) as cnt
from movie 
group by pc_id) as res
where cnt = 1;
-- group by pc_id;






