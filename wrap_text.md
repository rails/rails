How to use Explain options to gain insights that could potentially further
improve PostgreSQL's query performance

Explain options to give deeper insight into Query Performance
--------------


### Buffer

The Buffer option that comes with PostgreSQL's `Explain` command gives one
insights with regard to the data it is reading or writing when performing a
query operation and which of that data comes from cache or another source like
disk.

The buffer option is intended to give you one or more hints into what
specifically within the query your executing could be a potential cause of
slowness and thereby has room for further improvement.


An example Active Record query that uses `explain` with the `buffers` option:

```ruby Company.where(id: owning_companies_ids).explain(:analyze, :buffers) ```

Output of above query:

```sql
=> EXPLAIN (ANALYZE, BUFFERS) SELECT "companies".* FROM "companies"
WHERE "companies"."id" IN ($1, $2, $3) [["id", 365], ["id", 364], ["id", 360]]
QUERY PLAN
-------------------------------------------------------------------------------
 Seq Scan on companies  (cost=0.00..2.21 rows=3 width=64)
 (actual time=0.009..0.012 rows=3 loops=1) Filter: (id = ANY ('
 {365,364,360}'::bigint[])) Rows Removed by Filter: 10 Buffers: shared hit=1
 Planning Time: 0.049 ms Execution Time: 0.023 ms(6 rows)
 ```
