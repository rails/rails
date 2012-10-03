Migrations
==========

Migrations are a convenient way for you to alter your database in a structured
and organized manner. You could edit fragments of SQL by hand but you would then
be responsible for telling other developers that they need to go and run them.
You'd also have to keep track of which changes need to be run against the
production machines next time you deploy.

Active Record tracks which migrations have already been run so all you have to
do is update your source and run `rake db:migrate`. Active Record will work out
which migrations should be run. Active Record will also update your `db/schema.rb` file to match the up-to-date structure of your database.

Migrations also allow you to describe these transformations using Ruby. The
great thing about this is that (like most of Active Record's functionality) it
is database independent: you don't need to worry about the precise syntax of
`CREATE TABLE` any more than you worry about variations on `SELECT *` (you can
drop down to raw SQL for database specific features). For example, you could use
SQLite3 in development, but MySQL in production.

In this guide, you'll learn all about migrations including:

* The generators you can use to create them
* The methods Active Record provides to manipulate your database
* The Rake tasks that manipulate them
* How they relate to `schema.rb`

--------------------------------------------------------------------------------

Anatomy of a Migration
----------------------

Before we dive into the details of a migration, here are a few examples of the
sorts of things you can do:

```ruby
class CreateProducts < ActiveRecord::Migration
  def up
    create_table :products do |t|
      t.string :name
      t.text :description

      t.timestamps
    end
  end

  def down
    drop_table :products
  end
end
```

This migration adds a table called `products` with a string column called `name`
and a text column called `description`. A primary key column called `id` will
also be added, however since this is the default we do not need to explicitly specify it.
The timestamp columns `created_at` and `updated_at` which Active Record
populates automatically will also be added. Reversing this migration is as
simple as dropping the table.

Migrations are not limited to changing the schema. You can also use them to fix
bad data in the database or populate new fields:

```ruby
class AddReceiveNewsletterToUsers < ActiveRecord::Migration
  def up
    change_table :users do |t|
      t.boolean :receive_newsletter, :default => false
    end
    User.update_all :receive_newsletter => true
  end

  def down
    remove_column :users, :receive_newsletter
  end
end
```

NOTE: Some [caveats](#using-models-in-your-migrations) apply to using models in
your migrations.

This migration adds a `receive_newsletter` column to the `users` table. We want
it to default to `false` for new users, but existing users are considered to
have already opted in, so we use the User model to set the flag to `true` for
existing users.

### Using the change method

Rails 3.1 makes migrations smarter by providing a new `change` method.
This method is preferred for writing constructive migrations (adding columns or
tables). The migration knows how to migrate your database and reverse it when
the migration is rolled back without the need to write a separate `down` method.

```ruby
class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
```

### Migrations are Classes

A migration is a subclass of `ActiveRecord::Migration` that implements
two methods: `up` (perform the required transformations) and `down` (revert
them).

Active Record provides methods that perform common data definition tasks in a
database independent way (you'll read about them in detail later):

* `add_column`
* `add_reference`
* `add_index`
* `change_column`
* `change_table`
* `create_table`
* `create_join_table`
* `drop_table`
* `remove_column`
* `remove_index`
* `rename_column`
* `remove_reference`

If you need to perform tasks specific to your database (e.g., create a
[foreign key](#active-record-and-referential-integrity) constraint) then the
`execute` method allows you to execute arbitrary SQL. A migration is just a
regular Ruby class so you're not limited to these functions. For example, after
adding a column you could write code to set the value of that column for
existing records (if necessary using your models).

On databases that support transactions with statements that change the schema
(such as PostgreSQL or SQLite3), migrations are wrapped in a transaction. If the
database does not support this (for example MySQL) then when a migration fails
the parts of it that succeeded will not be rolled back. You will have to rollback
the changes that were made by hand.

### What's in a Name

Migrations are stored as files in the `db/migrate` directory, one for each
migration class. The name of the file is of the form
`YYYYMMDDHHMMSS_create_products.rb`, that is to say a UTC timestamp
identifying the migration followed by an underscore followed by the name
of the migration. The name of the migration class (CamelCased version)
should match the latter part of the file name. For example
`20080906120000_create_products.rb` should define class `CreateProducts` and
`20080906120001_add_details_to_products.rb` should define
`AddDetailsToProducts`. If you do feel the need to change the file name then you
<em>have to</em> update the name of the class inside or Rails will complain
about a missing class.

Internally Rails only uses the migration's number (the timestamp) to identify
them. Prior to Rails 2.1 the migration number started at 1 and was incremented
each time a migration was generated. With multiple developers it was easy for
these to clash requiring you to rollback migrations and renumber them. With
Rails 2.1+ this is largely avoided by using the creation time of the migration
to identify them. You can revert to the old numbering scheme by adding the
following line to `config/application.rb`.

```ruby
config.active_record.timestamped_migrations = false
```

The combination of timestamps and recording which migrations have been run
allows Rails to handle common situations that occur with multiple developers.

For example, Alice adds migrations `20080906120000` and `20080906123000` and Bob
adds `20080906124500` and runs it. Alice finishes her changes and checks in her
migrations and Bob pulls down the latest changes. When Bob runs `rake db:migrate`,
Rails knows that it has not run Alice's two migrations so it executes the `up` method for each migration.

Of course this is no substitution for communication within the team. For
example, if Alice's migration removed a table that Bob's migration assumed to
exist, then trouble would certainly strike.

### Changing Migrations

Occasionally you will make a mistake when writing a migration. If you have
already run the migration then you cannot just edit the migration and run the
migration again: Rails thinks it has already run the migration and so will do
nothing when you run `rake db:migrate`. You must rollback the migration (for
example with `rake db:rollback`), edit your migration and then run `rake db:migrate` to run the corrected version.

In general, editing existing migrations is not a good idea. You will be creating
extra work for yourself and your co-workers and cause major headaches if the
existing version of the migration has already been run on production machines.
Instead, you should write a new migration that performs the changes you require.
Editing a freshly generated migration that has not yet been committed to source
control (or, more generally, which has not been propagated beyond your
development machine) is relatively harmless.

### Supported Types

Active Record supports the following database column types:

* `:binary`
* `:boolean`
* `:date`
* `:datetime`
* `:decimal`
* `:float`
* `:integer`
* `:primary_key`
* `:string`
* `:text`
* `:time`
* `:timestamp`

These will be mapped onto an appropriate underlying database type. For example,
with MySQL the type `:string` is mapped to `VARCHAR(255)`. You can create
columns of types not supported by Active Record when using the non-sexy syntax such as

```ruby
create_table :products do |t|
  t.column :name, 'polygon', :null => false
end
```

This may however hinder portability to other databases.

Creating a Migration
--------------------

### Creating a Model

The model and scaffold generators will create migrations appropriate for adding
a new model. This migration will already contain instructions for creating the
relevant table. If you tell Rails what columns you want, then statements for
adding these columns will also be created. For example, running

```bash
$ rails generate model Product name:string description:text
```

will create a migration that looks like this

```ruby
class CreateProducts < ActiveRecord::Migration
  def change
    create_table :products do |t|
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
```

You can append as many column name/type pairs as you want. By default, the
generated migration will include `t.timestamps` (which creates the
`updated_at` and `created_at` columns that are automatically populated
by Active Record).

### Creating a Standalone Migration

If you are creating migrations for other purposes (e.g., to add a column
to an existing table) then you can also use the migration generator:

```bash
$ rails generate migration AddPartNumberToProducts
```

This will create an empty but appropriately named migration:

```ruby
class AddPartNumberToProducts < ActiveRecord::Migration
  def change
  end
end
```

If the migration name is of the form "AddXXXToYYY" or "RemoveXXXFromYYY" and is
followed by a list of column names and types then a migration containing the
appropriate `add_column` and `remove_column` statements will be created.

```bash
$ rails generate migration AddPartNumberToProducts part_number:string
```

will generate

```ruby
class AddPartNumberToProducts < ActiveRecord::Migration
  def change
    add_column :products, :part_number, :string
  end
end
```

Similarly,

```bash
$ rails generate migration RemovePartNumberFromProducts part_number:string
```

generates

```ruby
class RemovePartNumberFromProducts < ActiveRecord::Migration
  def up
    remove_column :products, :part_number
  end

  def down
    add_column :products, :part_number, :string
  end
end
```

You are not limited to one magically generated column. For example

```bash
$ rails generate migration AddDetailsToProducts part_number:string price:decimal
```

generates

```ruby
class AddDetailsToProducts < ActiveRecord::Migration
  def change
    add_column :products, :part_number, :string
    add_column :products, :price, :decimal
  end
end
```

As always, what has been generated for you is just a starting point. You can add
or remove from it as you see fit by editing the
db/migrate/YYYYMMDDHHMMSS_add_details_to_products.rb file.

NOTE: The generated migration file for destructive migrations will still be
old-style using the `up` and `down` methods. This is because Rails needs to know
the original data types defined when you made the original changes.

Also, the generator accepts column type as `references`(also available as `belongs_to`). For instance

```bash
$ rails generate migration AddUserRefToProducts user:references
```

generates

```ruby
class AddUserRefToProducts < ActiveRecord::Migration
  def change
    add_reference :products, :user, :index => true
  end
end
```

This migration will create a user_id column and appropriate index.

### Supported Type Modifiers

You can also specify some options just after the field type between curly braces. You can use the
following modifiers:

* `limit`        Sets the maximum size of the `string/text/binary/integer` fields
* `precision`    Defines the precision for the `decimal` fields
* `scale`        Defines the scale for the `decimal` fields
* `polymorphic`  Adds a `type` column for `belongs_to` associations

For instance, running

```bash
$ rails generate migration AddDetailsToProducts price:decimal{5,2} supplier:references{polymorphic}
```

will produce a migration that looks like this

```ruby
class AddDetailsToProducts < ActiveRecord::Migration
  def change
    add_column :products, :price, :precision => 5, :scale => 2
    add_reference :products, :user, :polymorphic => true, :index => true
  end
end
```

Writing a Migration
-------------------

Once you have created your migration using one of the generators it's time to
get to work!

### Creating a Table

Migration method `create_table` will be one of your workhorses. A typical use
would be

```ruby
create_table :products do |t|
  t.string :name
end
```

which creates a `products` table with a column called `name` (and as discussed
below, an implicit `id` column).

The object yielded to the block allows you to create columns on the table. There
are two ways of doing it. The first (traditional) form looks like

```ruby
create_table :products do |t|
  t.column :name, :string, :null => false
end
```

The second form, the so called "sexy" migration, drops the somewhat redundant
`column` method. Instead, the `string`, `integer`, etc. methods create a column
of that type. Subsequent parameters are the same.

```ruby
create_table :products do |t|
  t.string :name, :null => false
end
```

By default, `create_table` will create a primary key called `id`. You can change
the name of the primary key with the `:primary_key` option (don't forget to
update the corresponding model) or, if you don't want a primary key at all (for
example for a HABTM join table), you can pass the option `:id => false`. If you
need to pass database specific options you can place an SQL fragment in the
`:options` option. For example,

```ruby
create_table :products, :options => "ENGINE=BLACKHOLE" do |t|
  t.string :name, :null => false
end
```

will append `ENGINE=BLACKHOLE` to the SQL statement used to create the table
(when using MySQL, the default is `ENGINE=InnoDB`).

### Creating a Join Table

Migration method `create_join_table` creates a HABTM join table. A typical use
would be

```ruby
create_join_table :products, :categories
```

which creates a `categories_products` table with two columns called `category_id` and `product_id`.
These columns have the option `:null` set to `false` by default.

You can pass the option `:table_name` with you want to customize the table name. For example,

```ruby
create_join_table :products, :categories, :table_name => :categorization
```

will create a `categorization` table.

By default, `create_join_table` will create two columns with no options, but you can specify these
options using the `:column_options` option. For example,

```ruby
create_join_table :products, :categories, :column_options => {:null => true}
```

will create the `product_id` and `category_id` with the `:null` option as `true`.

### Changing Tables

A close cousin of `create_table` is `change_table`, used for changing existing
tables. It is used in a similar fashion to `create_table` but the object yielded
to the block knows more tricks. For example

```ruby
change_table :products do |t|
  t.remove :description, :name
  t.string :part_number
  t.index :part_number
  t.rename :upccode, :upc_code
end
```

removes the `description` and `name` columns, creates a `part_number` string
column and adds an index on it. Finally it renames the `upccode` column.

### Special Helpers

Active Record provides some shortcuts for common functionality. It is for
example very common to add both the `created_at` and `updated_at` columns and so
there is a method that does exactly that:

```ruby
create_table :products do |t|
  t.timestamps
end
```

will create a new products table with those two columns (plus the `id` column)
whereas

```ruby
change_table :products do |t|
  t.timestamps
end
```
adds those columns to an existing table.

Another helper is called `references` (also available as `belongs_to`). In its
simplest form it just adds some readability.

```ruby
create_table :products do |t|
  t.references :category
end
```

will create a `category_id` column of the appropriate type. Note that you pass
the model name, not the column name. Active Record adds the `_id` for you. If
you have polymorphic `belongs_to` associations then `references` will add both
of the columns required:

```ruby
create_table :products do |t|
  t.references :attachment, :polymorphic => {:default => 'Photo'}
end
```

will add an `attachment_id` column and a string `attachment_type` column with
a default value of 'Photo'. `references` also allows you to define an
index directly, instead of using `add_index` after the `create_table` call:

```ruby
create_table :products do |t|
  t.references :category, :index => true
end
```

will create an index identical to calling `add_index :products, :category_id`.

NOTE: The `references` helper does not actually create foreign key constraints
for you. You will need to use `execute` or a plugin that adds [foreign key
support](#active-record-and-referential-integrity).

If the helpers provided by Active Record aren't enough you can use the `execute`
method to execute arbitrary SQL.

For more details and examples of individual methods, check the API documentation. 
In particular the documentation for
[`ActiveRecord::ConnectionAdapters::SchemaStatements`](http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html)
(which provides the methods available in the `up` and `down` methods),
[`ActiveRecord::ConnectionAdapters::TableDefinition`](http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/TableDefinition.html)
(which provides the methods available on the object yielded by `create_table`)
and
[`ActiveRecord::ConnectionAdapters::Table`](http://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/Table.html)
(which provides the methods available on the object yielded by `change_table`).

### Using the `change` Method

The `change` method removes the need to write both `up` and `down` methods in
those cases that Rails knows how to revert the changes automatically. Currently,
the `change` method supports only these migration definitions:

* `add_column`
* `add_index`
* `add_timestamps`
* `create_table`
* `remove_timestamps`
* `rename_column`
* `rename_index`
* `rename_table`

If you're going to need to use any other methods, you'll have to write the
`up` and `down` methods instead of using the `change` method.

### Using the `up`/`down` Methods

The `down` method of your migration should revert the transformations done by
the `up` method. In other words, the database schema should be unchanged if you
do an `up` followed by a `down`. For example, if you create a table in the `up`
method, you should drop it in the `down` method. It is wise to reverse the
transformations in precisely the reverse order they were made in the `up`
method. For example,

```ruby
class ExampleMigration < ActiveRecord::Migration
  def up
    create_table :products do |t|
      t.references :category
    end
    #add a foreign key
    execute <<-SQL
      ALTER TABLE products
        ADD CONSTRAINT fk_products_categories
        FOREIGN KEY (category_id)
        REFERENCES categories(id)
    SQL
    add_column :users, :home_page_url, :string
    rename_column :users, :email, :email_address
  end

  def down
    rename_column :users, :email_address, :email
    remove_column :users, :home_page_url
    execute <<-SQL
      ALTER TABLE products
        DROP FOREIGN KEY fk_products_categories
    SQL
    drop_table :products
  end
end
```

Sometimes your migration will do something which is just plain irreversible; for
example, it might destroy some data. In such cases, you can raise
`ActiveRecord::IrreversibleMigration` from your `down` method. If someone tries
to revert your migration, an error message will be displayed saying that it
can't be done.

Running Migrations
------------------

Rails provides a set of rake tasks to work with migrations which boil down to
running certain sets of migrations.

The very first migration related rake task you will use will probably be
`rake db:migrate`. In its most basic form it just runs the `up` or `change`
method for all the migrations that have not yet been run. If there are
no such migrations, it exits. It will run these migrations in order based
on the date of the migration.

Note that running the `db:migrate` also invokes the `db:schema:dump` task, which
will update your db/schema.rb file to match the structure of your database.

If you specify a target version, Active Record will run the required migrations
(up, down or change) until it has reached the specified version. The version
is the numerical prefix on the migration's filename. For example, to migrate
to version 20080906120000 run

```bash
$ rake db:migrate VERSION=20080906120000
```

If version 20080906120000 is greater than the current version (i.e., it is
migrating upwards), this will run the `up` method on all migrations up to and
including 20080906120000, and will not execute any later migrations. If
migrating downwards, this will run the `down` method on all the migrations
down to, but not including, 20080906120000.

### Rolling Back

A common task is to rollback the last migration. For example, if you made a
mistake in it and wish to correct it. Rather than tracking down the version
number associated with the previous migration you can run

```bash
$ rake db:rollback
```

This will run the `down` method from the latest migration. If you need to undo
several migrations you can provide a `STEP` parameter:

```bash
$ rake db:rollback STEP=3
```

will run the `down` method from the last 3 migrations.

The `db:migrate:redo` task is a shortcut for doing a rollback and then migrating
back up again. As with the `db:rollback` task, you can use the `STEP` parameter
if you need to go more than one version back, for example

```bash
$ rake db:migrate:redo STEP=3
```

Neither of these Rake tasks do anything you could not do with `db:migrate`. They
are simply more convenient, since you do not need to explicitly specify the
version to migrate to.

### Resetting the Database

The `rake db:reset` task will drop the database, recreate it and load the
current schema into it.

NOTE: This is not the same as running all the migrations - see the section on
[schema.rb](#schema-dumping-and-you).

### Running Specific Migrations

If you need to run a specific migration up or down, the `db:migrate:up` and
`db:migrate:down` tasks will do that. Just specify the appropriate version and
the corresponding migration will have its `up` or `down` method invoked, for
example,

```bash
$ rake db:migrate:up VERSION=20080906120000
```

will run the `up` method from the 20080906120000 migration. This task will first
check whether the migration is already performed and will do nothing if Active Record believes
that it has already been run.

### Changing the Output of Running Migrations

By default migrations tell you exactly what they're doing and how long it took.
A migration creating a table and adding an index might produce output like this

```bash
==  CreateProducts: migrating =================================================
-- create_table(:products)
   -> 0.0028s
==  CreateProducts: migrated (0.0028s) ========================================
```

Several methods are provided in migrations that allow you to control all this:

| Method               | Purpose
| -------------------- | -------
| suppress_messages    | Takes a block as an argument and suppresses any output generated by the block.
| say                  | Takes a message argument and outputs it as is. A second boolean argument can be passed to specify whether to indent or not.
| say_with_time        | Outputs text along with how long it took to run its block. If the block returns an integer it assumes it is the number of rows affected.

For example, this migration

```ruby
class CreateProducts < ActiveRecord::Migration
  def change
    suppress_messages do
      create_table :products do |t|
        t.string :name
        t.text :description
        t.timestamps
      end
    end
    say "Created a table"
    suppress_messages {add_index :products, :name}
    say "and an index!", true
    say_with_time 'Waiting for a while' do
      sleep 10
      250
    end
  end
end
```

generates the following output

```bash
==  CreateProducts: migrating =================================================
-- Created a table
   -> and an index!
-- Waiting for a while
   -> 10.0013s
   -> 250 rows
==  CreateProducts: migrated (10.0054s) =======================================
```

If you want Active Record to not output anything, then running `rake db:migrate
VERBOSE=false` will suppress all output.

Using Models in Your Migrations
-------------------------------

When creating or updating data in a migration it is often tempting to use one of
your models. After all, they exist to provide easy access to the underlying
data. This can be done, but some caution should be observed.

For example, problems occur when the model uses database columns which are (1)
not currently in the database and (2) will be created by this or a subsequent
migration.

Consider this example, where Alice and Bob are working on the same code base
which contains a `Product` model:

Bob goes on vacation.

Alice creates a migration for the `products` table which adds a new column and
initializes it.  She also adds a validation to the `Product` model for the new
column.

```ruby
# db/migrate/20100513121110_add_flag_to_product.rb

class AddFlagToProduct < ActiveRecord::Migration
  def change
    add_column :products, :flag, :boolean
    Product.update_all :flag => false
  end
end
```

```ruby
# app/model/product.rb

class Product < ActiveRecord::Base
  validates :flag, :presence => true
end
```

Alice adds a second migration which adds and initializes another column to the
`products` table and also adds a validation to the `Product` model for the new
column.

```ruby
# db/migrate/20100515121110_add_fuzz_to_product.rb

class AddFuzzToProduct < ActiveRecord::Migration
  def change
    add_column :products, :fuzz, :string
    Product.update_all :fuzz => 'fuzzy'
  end
end
```

```ruby
# app/model/product.rb

class Product < ActiveRecord::Base
  validates :flag, :fuzz, :presence => true
end
```

Both migrations work for Alice.

Bob comes back from vacation and:

*   Updates the source - which contains both migrations and the latest version of
    the Product model.
*   Runs outstanding migrations with `rake db:migrate`, which
    includes the one that updates the `Product` model.

The migration crashes because when the model attempts to save, it tries to
validate the second added column, which is not in the database when the _first_
migration runs:

```
rake aborted!
An error has occurred, this and all later migrations canceled:

undefined method `fuzz' for #<Product:0x000001049b14a0>
```

A fix for this is to create a local model within the migration. This keeps Rails
from running the validations, so that the migrations run to completion.

When using a faux model, it's a good idea to call
`Product.reset_column_information` to refresh the `ActiveRecord` cache for the
`Product` model prior to updating data in the database.

If Alice had done this instead, there would have been no problem:

```ruby
# db/migrate/20100513121110_add_flag_to_product.rb

class AddFlagToProduct < ActiveRecord::Migration
  class Product < ActiveRecord::Base
  end

  def change
    add_column :products, :flag, :boolean
    Product.reset_column_information
    Product.update_all :flag => false
  end
end
```

```ruby
# db/migrate/20100515121110_add_fuzz_to_product.rb

class AddFuzzToProduct < ActiveRecord::Migration
  class Product < ActiveRecord::Base
  end

  def change
    add_column :products, :fuzz, :string
    Product.reset_column_information
    Product.update_all :fuzz => 'fuzzy'
  end
end
```

Schema Dumping and You
----------------------

### What are Schema Files for?

Migrations, mighty as they may be, are not the authoritative source for your
database schema. That role falls to either `db/schema.rb` or an SQL file which
Active Record generates by examining the database. They are not designed to be
edited, they just represent the current state of the database.

There is no need (and it is error prone) to deploy a new instance of an app by
replaying the entire migration history. It is much simpler and faster to just
load into the database a description of the current schema.

For example, this is how the test database is created: the current development
database is dumped (either to `db/schema.rb` or `db/structure.sql`) and then
loaded into the test database.

Schema files are also useful if you want a quick look at what attributes an
Active Record object has. This information is not in the model's code and is
frequently spread across several migrations, but the information is nicely
summed up in the schema file. The
[annotate_models](https://github.com/ctran/annotate_models) gem automatically
adds and updates comments at the top of each model summarizing the schema if
you desire that functionality.

### Types of Schema Dumps

There are two ways to dump the schema. This is set in `config/application.rb` by
the `config.active_record.schema_format` setting, which may be either `:sql` or
`:ruby`.

If `:ruby` is selected then the schema is stored in `db/schema.rb`. If you look
at this file you'll find that it looks an awful lot like one very big migration:

```ruby
ActiveRecord::Schema.define(version: 20080906171750) do
  create_table "authors", force: true do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "products", force: true do |t|
    t.string   "name"
    t.text "description"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "part_number"
  end
end
```

In many ways this is exactly what it is. This file is created by inspecting the
database and expressing its structure using `create_table`, `add_index`, and so
on. Because this is database-independent, it could be loaded into any database
that Active Record supports. This could be very useful if you were to distribute
an application that is able to run against multiple databases.

There is however a trade-off: `db/schema.rb` cannot express database specific
items such as foreign key constraints, triggers, or stored procedures. While in
a migration you can execute custom SQL statements, the schema dumper cannot
reconstitute those statements from the database. If you are using features like
this, then you should set the schema format to `:sql`.

Instead of using Active Record's schema dumper, the database's structure will be
dumped using a tool specific to the database (via the `db:structure:dump` Rake task)
into `db/structure.sql`. For example, for the PostgreSQL RDBMS, the
`pg_dump` utility is used. For MySQL, this file will contain the output of `SHOW
CREATE TABLE` for the various tables. Loading these schemas is simply a question
of executing the SQL statements they contain. By definition, this will create a
perfect copy of the database's structure. Using the `:sql` schema format will,
however, prevent loading the schema into a RDBMS other than the one used to
create it.

### Schema Dumps and Source Control

Because schema dumps are the authoritative source for your database schema, it
is strongly recommended that you check them into source control.

Active Record and Referential Integrity
---------------------------------------

The Active Record way claims that intelligence belongs in your models, not in
the database. As such, features such as triggers or foreign key constraints,
which push some of that intelligence back into the database, are not heavily
used.

Validations such as `validates :foreign_key, :uniqueness => true` are one way in
which models can enforce data integrity. The `:dependent` option on associations
allows models to automatically destroy child objects when the parent is
destroyed. Like anything which operates at the application level, these cannot
guarantee referential integrity and so some people augment them with foreign key
constraints in the database.

Although Active Record does not provide any tools for working directly with such
features, the `execute` method can be used to execute arbitrary SQL. You could
also use some plugin like [foreigner](https://github.com/matthuhiggins/foreigner)
which add foreign key support to Active Record (including support for dumping
foreign keys in `db/schema.rb`).
