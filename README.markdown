ActiveRelation
==============

## Abstract ##

ActiveRelation is a Relational Algebra for Ruby. It 1) simplifies the generation of both the simplest and the most complex of SQL queries and it 2) transparently adapts to various RDBMS systems. It is intended to be a framework framework; that is, you can build your own ORM with it, focusing on innovative object and collection modeling as opposed to database compatibility and query generation.

## A Gentle Introduction ##

Generating a query with ARel is simple. For example, in order to produce

    SELECT * FROM users
   
you construct a table relation and convert it to sql:

    ActiveRelation::Table.new(:users).to_sql

In fact, you will probably never call `#to_sql`. Let `users = ActiveRelation::Table.new(:users)`. Rather, you'll work with data from the table directly. You can iterate through all rows in the `users` table like this:

    users.each { |user| ... }

In other words, Arel relations behave implement Ruby's Eunmerable interface. Let's have a look at a concrete example:

    users.first # => {'id' => 10, 'name' => 'bob'}

As you can see, Arel converts the rows from the database into a hash, the values of which are sublimated to the appropriate Ruby primitive (integers, strings, and so forth).

## Relational Algebra ##

Arel is based on the Relational Algebra, a mathematical model that is also the inspiration for relational databases. ActiveRelation::Relation objects do not represent queries per se (i.e., they are not object-representations of `SELECT`, `INSERT`, `UPDATE`, or `DELETE` statements), rather they represent a collection of data that you can select from, insert into, update, and delete. For example, to insert a row into the users table, do the following:

    users.insert({users[:name] => 'amy'}) # => INSERT INTO users (users.name) VALUES ('amy')

To delete all users:

    users.delete # => DELETE FROM users

To update:

    users.update({users[:name] => 'carl'}) # => UPDATE users SET name = 'carl'
    
As you can see, the `relation` named `users` does not represent an individual query; rather it is an abstraction on a collection of data and it can produce appropriate SQL queries to do the various CRUD operations.

### More Sophisticated <strike>Queries</strike> Relations ###

Following the Relational Algebra, Arel's interface uses some jargon that differs from standard SQL. For example, in order to add a `WHERE` clause to your relations, you use the `select` operation:

    users.select(users[:name].equals('amy')) # => SELECT * FROM users WHERE users.name = 'amy'

What would, in SQL, be part of the `SELECT` clause is called here a `projection`:

    users.project(users[:id]) # => SELECT users.id FROM users
    
Joins are fairly straightforward:

    users.join(photos).on(users[:id].equals(photos[:user_id])) => SELECT * FROM users INNER JOIN photos ON users.id = photos.user_id

The best property of the Relational is compositionality, or closure under all operations. For example, to select and project:

    users                                 \
      .select(users[:name].equals('amy')) \
      .project(users[:id])                \
    # => SELECT users.id FROM users WHERE users.name = 'amy'

## Contributions ##

I appreciate all contributions to ActiveRelation. There is only one "unusual" requirement I have concerning code style: all specs should be written without mocks, using concrete examples to elicit testable behavior. This has two benefits: it 1) ensures the tests serve as concrete documentation and 2) suits the functional nature of this library, which emphasizes algebraic transformation rather than decoupled components.
