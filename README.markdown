## Abstract ##

Arel is a Relational Algebra for Ruby. It 1) simplifies the generation complex of SQL queries and it 2) adapts to various RDBMS systems. It is intended to be a framework framework; that is, you can build your own ORM with it, focusing on innovative object and collection modeling as opposed to database compatibility and query generation.

## Status ##

For the moment, Arel uses ActiveRecord's connection adapters to connect to the various engines, connection pooling, perform quoting, and do type conversion. On the horizon is the use of DataObjects instead.

The long term goal, following both LINQ and DataMapper, is to have Arel adapt to engines beyond RDBMS, including XML, IMAP, YAML, etc.

## A Gentle Introduction ##

Generating a query with ARel is simple. For example, in order to produce

    SELECT * FROM users

you construct a table relation and convert it to sql:

    users = Table(:users)
    users.to_sql

In fact, you will probably never call `#to_sql`. Rather, you'll work with data from the table directly. You can iterate through all rows in the `users` table like this:

    users.each { |user| ... }

In other words, Arel relations implement Ruby's Enumerable interface. Let's have a look at a concrete example:

    users.first # => { users[:id] => 1, users[:name] => 'bob' }

As you can see, Arel converts the rows from the database into a hash, the values of which are sublimated to the appropriate Ruby primitive (integers, strings, and so forth).

### More Sophisticated <strike>Queries</strike> Relations ###

Here is a whirlwind tour through the most common relational operators. These will probably cover 80% of all interaction with the database.

First is the 'restriction' operator, `where`:

    users.where(users[:name].eq('amy'))
    # => SELECT * FROM users WHERE users.name = 'amy'

What would, in SQL, be part of the `SELECT` clause is called in Arel a `projection`:

    users.project(users[:id]) # => SELECT users.id FROM users

Joins resemble SQL strongly:

    users.join(photos).on(users[:id].eq(photos[:user_id]))
    # => SELECT * FROM users INNER JOIN photos ON users.id = photos.user_id

What are called `LIMIT` and `OFFSET` in SQL are called `take` and `skip` in Arel:

    users.take(5) # => SELECT * FROM users LIMIT 5
    users.skip(4) # => SELECT * FROM users OFFSET 4

`GROUP BY` is called `group`:

    users.group(users[:name]) # => SELECT * FROM users GROUP BY name

The best property of the Relational Algebra is its "composability", or closure under all operations. For example, to select AND project, just "chain" the method invocations:

    users                                 \
      .where(users[:name].eq('amy'))      \
      .project(users[:id])                \
    # => SELECT users.id FROM users WHERE users.name = 'amy'

All operators are chainable in this way, and they are chainable any number of times, in any order.

    users.where(users[:name].eq('bob')).where(users[:age].lt(25))

Of course, many of the operators take multiple arguments, so the last example can be written more tersely:

    users.where(users[:name].eq('bob'), users[:age].lt(25))

The `OR` operator is not yet supported. It will work like this:

    users.where(users[:name].eq('bob').or(users[:age].lt(25)))

The `AND` operator will behave similarly.

Finally, most operations take a block form. For example:

    Table(:users)                    \
      .where   { |u| u[:id].eq(1) } \
      .project { |u| u[:id] }

This provides a (sometimes) convenient alternative syntax.

### The Crazy Features ###

The examples above are fairly simple and other libraries match or come close to matching the expressiveness of Arel (e.g., `Sequel` in Ruby).

#### Complex Joins ####

Where Arel really shines in its ability to handle complex joins and aggregations. As a first example, let's consider an "adjacency list", a tree represented in a table. Suppose we have a table `comments`, representing a threaded discussion:

    comments = Table(:comments)

And this table has the following attributes:

    comments.attributes # => [comments[:id], comments[:body], comments[:parent_id]]

The `parent_id` column is a foreign key from the `comments` table to itself. Now, joining a table to itself requires aliasing in SQL. In fact, you may alias in Arel as well:

    replies = comments.alias
    comments_with_replies = \
      comments.join(replies).on(replies[:parent_id].eq(comments[:id]))
    # => SELECT * FROM comments INNER JOIN comments AS comments_2 WHERE comments_2.parent_id = comments.id

The call to `#alias` is actually optional: Arel will always produce a unique name for every table joined in the relation, and it will always do so deterministically to exploit query caching. Explicit aliasing is more common, however. When you want to extract specific slices of data, aliased tables are a necessity. For example to get just certain columns from the row, treat a row like a hash:

    comments_with_replies.first[replies[:body]]

This will return the first comment's reply's body.

If you don't need to extract the data later (for example, you're simply doing a join to find comments that have replies, you don't care what the content of the replies are), the block form may be preferable:

    comments.join(comments) { |comments, replies| replies[:parent_id].eq(comments[:id]) }
    # => SELECT * FROM comments INNER JOIN comments AS comments_2 WHERE comments_2.parent_id = comments.id

Note that you do NOT want to do something like:

    comments.join(comments, comments[:parent_id].eq(comments[:id]))
    # => SELECT * FROM comments INNER JOIN comments AS comments_2 WHERE comments.parent_id = comments.id

This does NOT have the same meaning as the previous query, since the comments[:parent_id] reference is effectively ambiguous.

#### Complex Aggregations ####

My personal favorite feature of Arel, certainly the most difficult to implement, and possibly only of marginal value, is **closure under joining even in the presence of aggregations**. This is a feature where the Relational Algebra is fundamentally easier to use than SQL. Think of this as a preview of the kind of radical functionality that is to come, stuff no other "ORM" is doing.

The easiest way to introduce this is in SQL. Your task is to get all users and the **count** of their associated photos. Let's start from the inside out:

    SELECT count(*)
    FROM photos
    GROUP BY user_id

Now, we'd like to join this with the user table. Naively, you might try to do this:

    SELECT users.*, count(photos.id)
    FROM users
    LEFT OUTER JOIN photos
      ON users.id = photos.user_id
    GROUP BY photos.user_id

Of course, this has a slightly different meaning than our intended query. This is actually a fairly advanced topic in SQL so let's see why this doesn't work *step by step*. Suppose we have these records in our `users` table:

    mysql> select * from users;
    +------+--------+
    | id   | name   |
    +------+--------+
    |    1 | hai    |
    |    2 | bai    |
    |    3 | dumpty |
    +------+--------+

And these in the photos table:

    mysql> select * from photos;
    +------+---------+-----------+
    | id   | user_id | camera_id |
    +------+---------+-----------+
    |    1 |       1 |         1 |
    |    2 |       1 |         1 |
    |    3 |       1 |         1 |
    +------+---------+-----------+

If we perform the above, incorrect query, we get the following:

    mysql> select users.*, count(photos.id) from users left outer join photos on users.id = photos.user_id limit 3 group by user_id;
    +------+------+------------------+
    | id   | name | count(photos.id) |
    +------+------+------------------+
    |    2 | bai  |                0 |
    |    1 | hai  |                3 |
    +------+------+------------------+

As you can see, we're completely missing data for user with id 3. `dumpty` has no photos, neither does `bai`. But strangely `bai` appeared and `dumpty` didn't! The reason is that the `GROUP BY` clause is aggregating on both tables, not just the `photos` table. All users without photos have a `photos.id` of `null` (thanks to the left outer join). These are rolled up together and an arbitrary user wins. In this case, `bai` not `dumpty`.

    SELECT users.*, photos_aggregation.cnt
    FROM users
    LEFT OUTER JOIN (SELECT user_id, count(*) as cnt FROM photos GROUP BY user_id) AS photos_aggregation
      ON photos_aggregation.user_id = users.id
