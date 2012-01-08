# ARel [![Build Status](https://secure.travis-ci.org/rails/arel.png)](http://travis-ci.org/rails/arel) [![Dependency Status](https://gemnasium.com/rails/arel.png)](https://gemnasium.com/rails/arel)

* http://github.com/rails/arel

## DESCRIPTION

Arel is a SQL AST manager for Ruby. It

1. Simplifies the generation of complex SQL queries
2. Adapts to various RDBMS systems

It is intended to be a framework framework; that is, you can build your own ORM
with it, focusing on innovative object and collection modeling as opposed to
database compatibility and query generation.

## Status

For the moment, Arel uses ActiveRecord's connection adapters to connect to the various engines, connection pooling, perform quoting, and do type conversion.

## A Gentle Introduction

Generating a query with ARel is simple. For example, in order to produce

    SELECT * FROM users

you construct a table relation and convert it to sql:

    users = Arel::Table.new(:users)
    query = users.project(Arel.sql('*'))
    query.to_sql

### More Sophisticated Queries

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

The best property of the Relational Algebra is its "composability", or closure under all operations. For example, to restrict AND project, just "chain" the method invocations:

    users                                 \
      .where(users[:name].eq('amy'))      \
      .project(users[:id])                \
    # => SELECT users.id FROM users WHERE users.name = 'amy'

All operators are chainable in this way, and they are chainable any number of times, in any order.

    users.where(users[:name].eq('bob')).where(users[:age].lt(25))

Of course, many of the operators take multiple arguments, so the last example can be written more tersely:

    users.where(users[:name].eq('bob'), users[:age].lt(25))

The `OR` operator works like this:

    users.where(users[:name].eq('bob').or(users[:age].lt(25)))

The `AND` operator behaves similarly.

### The Crazy Features

The examples above are fairly simple and other libraries match or come close to matching the expressiveness of Arel (e.g., `Sequel` in Ruby).

#### Inline math operations

Suppose we have a table `products` with prices in different currencies. And we have a table currency_rates, of constantly changing currency rates. In Arel:

    products = Arel::Table.new(:products)
    products.columns # => [products[:id], products[:name], products[:price], products[:currency_id]]

    currency_rates = Arel::Table.new(:currency_rates)
    currency_rates.columns # => [currency_rates[:from_id], currency_rates[:to_id], currency_rates[:date], currency_rates[:rate]]

Now, to order products by price in user preferred currency simply call:

    products.
      join(:currency_rates).on(products[:currency_id].eq(currency_rates[:from_id])).
      where(currency_rates[:to_id].eq(user_preferred_currency), currency_rates[:date].eq(Date.today)).
      order(products[:price] * currency_rates[:rate])

#### Complex Joins

Where Arel really shines in its ability to handle complex joins and aggregations. As a first example, let's consider an "adjacency list", a tree represented in a table. Suppose we have a table `comments`, representing a threaded discussion:

    comments = Arel::Table.new(:comments)

And this table has the following attributes:

    comments.columns # => [comments[:id], comments[:body], comments[:parent_id]]

The `parent_id` column is a foreign key from the `comments` table to itself. Now, joining a table to itself requires aliasing in SQL. In fact, you may alias in Arel as well:

    replies = comments.alias
    comments_with_replies = \
      comments.join(replies).on(replies[:parent_id].eq(comments[:id]))
    # => SELECT * FROM comments INNER JOIN comments AS comments_2 WHERE comments_2.parent_id = comments.id

This will return the first comment's reply's body.
