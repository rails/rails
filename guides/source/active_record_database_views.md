**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Working with Database Views
===========================

This guide explains how to use database views with Active Record models, especially in cases where your database schema does not follow Rails conventions.

After reading this guide, you will be able to:

* Define database views in migrations
* Map models to views using Active Record
* Interact with views as if they were regular database tables
* Work around legacy or read-only schemas using views
* Understand compatibility and limitations across different database systems

------------------------------------------------------------------------------

Sometimes, the database you’re working with isn’t structured the way Rails
expects. You might be dealing with a legacy system where table and column names
don’t follow Rails conventions—like `TBL_ART` instead of `articles`, or
`STR_TITLE` instead of `title`. Or maybe you only want to expose a filtered
subset of data to your application.

This is where database views come in handy. A view is a virtual table defined by
a SQL query. It behaves like a regular table when queried, but it doesn’t store
data itself. Instead, it presents the results of the underlying query. This
allows you to rename columns, filter rows, and reshape non-standard tables into
something Active Record can work with easily.

Non-Conventional Tables
----------------------

In some databases—such as PostgreSQL—views can even be updateable, meaning you
can insert, update, or delete records through them under certain conditions.

Imagine you're working with a legacy table like this:

```sh
rails_pg_guide=# \d "TBL_ART"
                                        Table "public.TBL_ART"
   Column   |            Type             |                         Modifiers
------------+-----------------------------+------------------------------------------------------------
 INT_ID     | integer                     | not null default nextval('"TBL_ART_INT_ID_seq"'::regclass)
 STR_TITLE  | character varying           |
 STR_STAT   | character varying           | default 'draft'::character varying
 DT_PUBL_AT | timestamp without time zone |
 BL_ARCH    | boolean                     | default false
Indexes:
    "TBL_ART_pkey" PRIMARY KEY, btree ("INT_ID")
```

This table doesn’t follow Rails conventions at all. Instead of trying to work
around the mismatched column names and formats, you can define a view that
reshapes the data to fit Rails expectations.


Creating the View
-----------------

You can define the view using raw SQL inside a migration:

```ruby
# db/migrate/20131220144913_create_articles_view.rb
execute <<-SQL
  CREATE VIEW articles AS
    SELECT "INT_ID" AS id,
           "STR_TITLE" AS title,
           "STR_STAT" AS status,
           "DT_PUBL_AT" AS published_at,
           "BL_ARCH" AS archived
    FROM "TBL_ART"
    WHERE "BL_ARCH" = 'f'
SQL
```

This creates a virtual table named articles, with Rails-style column names and
only includes non-archived records.

Defining the Model
-------------------

Next, define your model to work with the view:

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  self.primary_key = "id"

  def archive!
    update_attribute :archived, true
  end
end
```

Since the view exposes the archived field, and Active Record is aware of the
primary key, you can perform standard model operations.

Using the View in Rails
----------------------

Here’s how this works in practice:

```irb
irb> first = Article.create!(
  title: "Winter is coming",
  status: "published",
  published_at: 1.year.ago
)

irb> second = Article.create!(
  title: "Brace yourself",
  status: "draft",
  published_at: 1.month.ago
)

irb> Article.count
# => 2

irb> first.archive!

irb> Article.count
# => 1
```

Since the view only includes non-archived articles `(WHERE "BL_ARCH" = 'f')`,
archiving an article causes it to disappear from the view—without needing to
manually filter it out in your application code.

Compatibility Notes
-------------------

Most relational databases support views, but their behavior varies. Some treat
views as read-only and do not support writing through them.

Others only allow updates under specific conditions (for example, no joins, no
computed columns).

PostgreSQL offers the most seamless experience with updateable views, making it
ideal for this pattern.

Be sure to consult your database’s documentation to determine what operations
are supported for views in your environment.
