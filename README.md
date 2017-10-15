# Arel

* http://github.com/rails/arel
* [API Documentation](http://www.rubydoc.info/github/rails/arel)

## DESCRIPTION

Arel Really Exasperates Logicians

Arel is a SQL AST manager for Ruby. It

1. simplifies the generation of complex SQL queries, and
2. adapts to various RDBMSes.

It is intended to be a framework framework; that is, you can build your own ORM
with it, focusing on innovative object and collection modeling as opposed to
database compatibility and query generation.

## Status

For the moment, Arel uses Active Record's connection adapters to connect to the various engines and perform connection pooling, quoting, and type conversion.

## A Gentle Introduction

Generating a query with Arel is simple. For example, in order to produce

```sql
SELECT * FROM users
```

you construct a table relation and convert it to SQL:

```ruby
users = Arel::Table.new(:users)
query = users.project(Arel.sql('*'))
query.to_sql
```

### More Sophisticated Queries

Here is a whirlwind tour through the most common SQL operators. These will probably cover 80% of all interaction with the database.

First is the 'restriction' operator, `where`:

```ruby
users.where(users[:name].eq('amy'))
# => SELECT * FROM users WHERE users.name = 'amy'
```

What would, in SQL, be part of the `SELECT` clause is called in Arel a `projection`:

```ruby
users.project(users[:id])
# => SELECT users.id FROM users
```

Comparison operators `=`, `!=`, `<`, `>`, `<=`, `>=`, `IN`:

```ruby
users.where(users[:age].eq(10)).project(Arel.sql('*'))
# => SELECT * FROM "users"  WHERE "users"."age" = 10

users.where(users[:age].not_eq(10)).project(Arel.sql('*'))
# => SELECT * FROM "users"  WHERE "users"."age" != 10

users.where(users[:age].lt(10)).project(Arel.sql('*'))
# => SELECT * FROM "users"  WHERE "users"."age" < 10

users.where(users[:age].gt(10)).project(Arel.sql('*'))
# => SELECT * FROM "users"  WHERE "users"."age" > 10

users.where(users[:age].lteq(10)).project(Arel.sql('*'))
# => SELECT * FROM "users"  WHERE "users"."age" <= 10

users.where(users[:age].gteq(10)).project(Arel.sql('*'))
# => SELECT * FROM "users"  WHERE "users"."age" >= 10

users.where(users[:age].in([20, 16, 17])).project(Arel.sql('*'))
# => SELECT * FROM "users"  WHERE "users"."age" IN (20, 16, 17)
```

Bitwise operators `&`, `|`, `^`, `<<`, `>>`:

```ruby
users.where((users[:bitmap] & 16).gt(0)).project(Arel.sql('*'))
# => SELECT * FROM "users"  WHERE ("users"."bitmap" & 16) > 0

users.where((users[:bitmap] | 16).gt(0)).project(Arel.sql('*'))
# => SELECT * FROM "users"  WHERE ("users"."bitmap" | 16) > 0

users.where((users[:bitmap] ^ 16).gt(0)).project(Arel.sql('*'))
# => SELECT * FROM "users"  WHERE ("users"."bitmap" ^ 16) > 0

users.where((users[:bitmap] << 1).gt(0)).project(Arel.sql('*'))
# => SELECT * FROM "users"  WHERE ("users"."bitmap" << 1) > 0

users.where((users[:bitmap] >> 1).gt(0)).project(Arel.sql('*'))
# => SELECT * FROM "users"  WHERE ("users"."bitmap" >> 1) > 0

users.where((~ users[:bitmap]).gt(0)).project(Arel.sql('*'))
# => SELECT * FROM "users" WHERE  ~ "users"."bitmap" > 0
```

Joins resemble SQL strongly:

```ruby
users.join(photos).on(users[:id].eq(photos[:user_id]))
# => SELECT * FROM users INNER JOIN photos ON users.id = photos.user_id
```

Left joins:

```ruby
users.join(photos, Arel::Nodes::OuterJoin).on(users[:id].eq(photos[:user_id]))
# => SELECT FROM users LEFT OUTER JOIN photos ON users.id = photos.user_id
```

What are called `LIMIT` and `OFFSET` in SQL are called `take` and `skip` in Arel:

```ruby
users.take(5) # => SELECT * FROM users LIMIT 5
users.skip(4) # => SELECT * FROM users OFFSET 4
```

`GROUP BY` is called `group`:

```ruby
users.project(users[:name]).group(users[:name])
# => SELECT users.name FROM users GROUP BY users.name
```

The best property of Arel is its "composability," or closure under all operations. For example, to restrict AND project, just "chain" the method invocations:

```ruby
users                                 \
  .where(users[:name].eq('amy'))      \
  .project(users[:id])                \
# => SELECT users.id FROM users WHERE users.name = 'amy'
```

All operators are chainable in this way, and they are chainable any number of times, in any order.

```ruby
users.where(users[:name].eq('bob')).where(users[:age].lt(25))
```

The `OR` operator works like this:

```ruby
users.where(users[:name].eq('bob').or(users[:age].lt(25)))
```

The `AND` operator behaves similarly. Here is an example of the `DISTINCT` operator:

```ruby
posts = Arel::Table.new(:posts)
posts.project(posts[:title])
posts.distinct
posts.to_sql # => 'SELECT DISTINCT "posts"."title" FROM "posts"'
```

Aggregate functions `AVG`, `SUM`, `COUNT`, `MIN`, `MAX`, `HAVING`:

```ruby
photos.group(photos[:user_id]).having(photos[:id].count.gt(5))
# => SELECT FROM photos GROUP BY photos.user_id HAVING COUNT(photos.id) > 5

users.project(users[:age].sum)
# => SELECT SUM(users.age) FROM users

users.project(users[:age].average)
# => SELECT AVG(users.age) FROM users

users.project(users[:age].maximum)
# => SELECT MAX(users.age) FROM users

users.project(users[:age].minimum)
# => SELECT MIN(users.age) FROM users

users.project(users[:age].count)
# => SELECT COUNT(users.age) FROM users
```

Aliasing Aggregate Functions:

```ruby
users.project(users[:age].average.as("mean_age"))
# => SELECT AVG(users.age) AS mean_age FROM users
```

### The Advanced Features

The examples above are fairly simple and other libraries match or come close to matching the expressiveness of Arel (e.g. `Sequel` in Ruby).

#### Inline math operations

Suppose we have a table `products` with prices in different currencies. And we have a table `currency_rates`, of constantly changing currency rates. In Arel:

```ruby
products = Arel::Table.new(:products)
# Attributes: [:id, :name, :price, :currency_id]

currency_rates = Arel::Table.new(:currency_rates)
# Attributes: [:from_id, :to_id, :date, :rate]
```

Now, to order products by price in user preferred currency simply call:

```ruby
products.
  join(:currency_rates).on(products[:currency_id].eq(currency_rates[:from_id])).
  where(currency_rates[:to_id].eq(user_preferred_currency), currency_rates[:date].eq(Date.today)).
  order(products[:price] * currency_rates[:rate])
```

#### Complex Joins

##### Alias
Where Arel really shines is in its ability to handle complex joins and aggregations. As a first example, let's consider an "adjacency list", a tree represented in a table. Suppose we have a table `comments`, representing a threaded discussion:

```ruby
comments = Arel::Table.new(:comments)
```

And this table has the following attributes:

```ruby
# [:id, :body, :parent_id]
```

The `parent_id` column is a foreign key from the `comments` table to itself.
Joining a table to itself requires aliasing in SQL. This aliasing can be handled from Arel as below:

```ruby
replies = comments.alias
comments_with_replies = \
  comments.join(replies).on(replies[:parent_id].eq(comments[:id])).where(comments[:id].eq(1))
# => SELECT * FROM comments INNER JOIN comments AS comments_2
#    WHERE comments_2.parent_id = comments.id AND comments.id = 1
```

This will return the reply for the first comment.

##### CTE
[Common Table Expressions (CTE)](https://en.wikipedia.org/wiki/Common_table_expressions#Common_table_expression) support via:

Create a `CTE`

```ruby
cte_table = Arel::Table.new(:cte_table)
composed_cte = Arel::Nodes::As.new(cte_table, photos.where(photos[:created_at].gt(Date.current)))
```

Use the created `CTE`:

```ruby
users.
  join(cte_table).on(users[:id].eq(cte_table[:user_id])).
  project(users[:id], cte_table[:click].sum).
  with(composed_cte)

# => WITH cte_table AS (SELECT FROM photos  WHERE photos.created_at > '2014-05-02')
#    SELECT users.id, SUM(cte_table.click)
#    FROM users INNER JOIN cte_table ON users.id = cte_table.user_id
```

#### Write SQL strings
When your query is too complex for `Arel`, you can use `Arel::SqlLiteral`:

```ruby
photo_clicks = Arel::Nodes::SqlLiteral.new(<<-SQL
    CASE WHEN condition1 THEN calculation1
    WHEN condition2 THEN calculation2
    WHEN condition3 THEN calculation3
    ELSE default_calculation END
SQL
)

photos.project(photo_clicks.as("photo_clicks"))
# => SELECT CASE WHEN condition1 THEN calculation1
#    WHEN condition2 THEN calculation2
#    WHEN condition3 THEN calculation3
#    ELSE default_calculation END
#    FROM "photos"
```

## Contributing to Arel

Arel is the work of many contributors. You're encouraged to submit pull requests, propose
features and discuss issues.

See [CONTRIBUTING](CONTRIBUTING.md).

## License
Arel is released under the [MIT License](http://www.opensource.org/licenses/MIT).
