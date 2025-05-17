**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Active Record and PostgreSQL
============================

This guide covers PostgreSQL specific usage of Active Record.

After reading this guide, you will know:

* How to use PostgreSQL's datatypes.
* How to use UUID primary keys.
* How to include non-key columns in indexes.
* How to use deferrable foreign keys.
* How to use unique constraints.
* How to implement exclusion constraints.
* How to implement full text search with PostgreSQL.
* How to back your Active Record models with database views.

--------------------------------------------------------------------------------

In order to use the PostgreSQL adapter you need to have at least version 9.3
installed. Older versions are not supported.

To get started with PostgreSQL have a look at the
[configuring Rails guide](configuring.html#configuring-a-postgresql-database).
It describes how to properly set up Active Record for PostgreSQL.

Datatypes
---------

PostgreSQL offers a number of specific datatypes. Following is a list of types,
that are supported by the PostgreSQL adapter.

### Array

* [type definition](https://www.postgresql.org/docs/current/static/arrays.html)
* [functions and operators](https://www.postgresql.org/docs/current/static/functions-array.html)

```ruby
# db/migrate/20140207133952_create_books.rb
create_table :books do |t|
  t.string "title"
  t.string "tags", array: true
  t.integer "ratings", array: true
end
add_index :books, :tags, using: "gin"
add_index :books, :ratings, using: "gin"
```

```ruby
# app/models/book.rb
class Book < ApplicationRecord
end
```

```ruby
# Usage
Book.create title: "Brave New World",
            tags: ["fantasy", "fiction"],
            ratings: [4, 5]

## Books for a single tag
Book.where("'fantasy' = ANY (tags)")

## Books for multiple tags
Book.where("tags @> ARRAY[?]::varchar[]", ["fantasy", "fiction"])

## Books with 3 or more ratings
Book.where("array_length(ratings, 1) >= 3")
```

### Composite Types

* [type definition](https://www.postgresql.org/docs/current/static/rowtypes.html)

Currently there is no special support for composite types. They are mapped to
normal text columns:

```sql
CREATE TYPE full_address AS
(
  city VARCHAR(90),
  street VARCHAR(90)
);
```

```ruby
# db/migrate/20140207133952_create_contacts.rb
execute <<-SQL
  CREATE TYPE full_address AS
  (
    city VARCHAR(90),
    street VARCHAR(90)
  );
SQL
create_table :contacts do |t|
  t.column :address, :full_address
end
```

```ruby
# app/models/contact.rb
class Contact < ApplicationRecord
end
```

```irb
irb> Contact.create address: "(Paris,Champs-Élysées)"
irb> contact = Contact.first
irb> contact.address
=> "(Paris,Champs-Élysées)"
irb> contact.address = "(Paris,Rue Basse)"
irb> contact.save!
```

UUID Primary Keys
-----------------

NOTE: You need to enable the `pgcrypto` (only PostgreSQL >= 9.4) or `uuid-ossp`
extension to generate random UUIDs.

```ruby
# db/migrate/20131220144913_create_devices.rb
enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
create_table :devices, id: :uuid do |t|
  t.string :kind
end
```

```ruby
# app/models/device.rb
class Device < ApplicationRecord
end
```

```irb
irb> device = Device.create
irb> device.id
=> "814865cd-5a1d-4771-9306-4268f188fe9e"
```

NOTE: `gen_random_uuid()` (from `pgcrypto`) is assumed if no `:default` option
was passed to `create_table`.

To use the Rails model generator for a table using UUID as the primary key, pass
`--primary-key-type=uuid` to the model generator.

For example:

```bash
$ rails generate model Device --primary-key-type=uuid kind:string
```

When building a model with a foreign key that will reference this UUID, treat
`uuid` as the native field type, for example:

```bash
$ rails generate model Case device_id:uuid
```

Indexing
--------

* [index creation](https://www.postgresql.org/docs/current/sql-createindex.html)

PostgreSQL includes a variety of index options. The following options are
supported by the PostgreSQL adapter in addition to the
[common index options](https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/SchemaStatements.html#method-i-add_index)

### Include

When creating a new index, non-key columns can be included with the `:include` option.
These keys are not used in index scans for searching, but can be read during an index
only scan without having to visit the associated table.

```ruby
# db/migrate/20131220144913_add_index_users_on_email_include_id.rb

add_index :users, :email, include: :id
```

Multiple columns are supported:

```ruby
# db/migrate/20131220144913_add_index_users_on_email_include_id_and_created_at.rb

add_index :users, :email, include: [:id, :created_at]
```

Generated Columns
-----------------

NOTE: Generated columns are supported since version 12.0 of PostgreSQL.

```ruby
# db/migrate/20131220144913_create_users.rb
create_table :users do |t|
  t.string :name
  t.virtual :name_upcased, type: :string, as: "upper(name)", stored: true
end

# app/models/user.rb
class User < ApplicationRecord
end

# Usage
user = User.create(name: "John")
User.last.name_upcased # => "JOHN"
```

Deferrable Foreign Keys
-----------------------

* [foreign key table constraints](https://www.postgresql.org/docs/current/sql-set-constraints.html)

By default, table constraints in PostgreSQL are checked immediately after each statement. It intentionally does not allow creating records where the referenced record is not yet in the referenced table. It is possible to run this integrity check later on when the transaction is committed by adding `DEFERRABLE` to the foreign key definition though. To defer all checks by default it can be set to `DEFERRABLE INITIALLY DEFERRED`. Rails exposes this PostgreSQL feature by adding the `:deferrable` key to the `foreign_key` options in the `add_reference` and `add_foreign_key` methods.

One example of this is creating circular dependencies in a transaction even if you have created foreign keys:

```ruby
add_reference :person, :alias, foreign_key: { deferrable: :deferred }
add_reference :alias, :person, foreign_key: { deferrable: :deferred }
```

If the reference was created with the `foreign_key: true` option, the following transaction would fail when executing the first `INSERT` statement. It does not fail when the `deferrable: :deferred` option is set though.

```ruby
ActiveRecord::Base.lease_connection.transaction do
  person = Person.create(id: SecureRandom.uuid, alias_id: SecureRandom.uuid, name: "John Doe")
  Alias.create(id: person.alias_id, person_id: person.id, name: "jaydee")
end
```

When the `:deferrable` option is set to `:immediate`, let the foreign keys keep the default behavior of checking the constraint immediately, but allow manually deferring the checks using `set_constraints` within a transaction. This will cause the foreign keys to be checked when the transaction is committed:

```ruby
ActiveRecord::Base.lease_connection.transaction do
  ActiveRecord::Base.lease_connection.set_constraints(:deferred)
  person = Person.create(alias_id: SecureRandom.uuid, name: "John Doe")
  Alias.create(id: person.alias_id, person_id: person.id, name: "jaydee")
end
```

By default `:deferrable` is `false` and the constraint is always checked immediately.

Unique Constraint
-----------------

* [unique constraints](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS)

```ruby
# db/migrate/20230422225213_create_items.rb
create_table :items do |t|
  t.integer :position, null: false
  t.unique_constraint [:position], deferrable: :immediate
end
```

If you want to change an existing unique index to deferrable, you can use `:using_index` to create deferrable unique constraints.

```ruby
add_unique_constraint :items, deferrable: :deferred, using_index: "index_items_on_position"
```

Like foreign keys, unique constraints can be deferred by setting `:deferrable` to either `:immediate` or `:deferred`. By default, `:deferrable` is `false` and the constraint is always checked immediately.

Exclusion Constraints
---------------------

* [exclusion constraints](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-EXCLUSION)

```ruby
# db/migrate/20131220144913_create_products.rb
create_table :products do |t|
  t.integer :price, null: false
  t.daterange :availability_range, null: false

  t.exclusion_constraint "price WITH =, availability_range WITH &&", using: :gist, name: "price_check"
end
```

Like foreign keys, exclusion constraints can be deferred by setting `:deferrable` to either `:immediate` or `:deferred`. By default, `:deferrable` is `false` and the constraint is always checked immediately.

Full Text Search
----------------

```ruby
# db/migrate/20131220144913_create_documents.rb
create_table :documents do |t|
  t.string :title
  t.string :body
end

add_index :documents, "to_tsvector('english', title || ' ' || body)", using: :gin, name: "documents_idx"
```

```ruby
# app/models/document.rb
class Document < ApplicationRecord
end
```

```ruby
# Usage
Document.create(title: "Cats and Dogs", body: "are nice!")

## all documents matching 'cat & dog'
Document.where("to_tsvector('english', title || ' ' || body) @@ to_tsquery(?)",
                 "cat & dog")
```

Optionally, you can store the vector as automatically generated column (from PostgreSQL 12.0):

```ruby
# db/migrate/20131220144913_create_documents.rb
create_table :documents do |t|
  t.string :title
  t.string :body

  t.virtual :textsearchable_index_col,
            type: :tsvector, as: "to_tsvector('english', title || ' ' || body)", stored: true
end

add_index :documents, :textsearchable_index_col, using: :gin, name: "documents_idx"

# Usage
Document.create(title: "Cats and Dogs", body: "are nice!")

## all documents matching 'cat & dog'
Document.where("textsearchable_index_col @@ to_tsquery(?)", "cat & dog")
```

Database Views
--------------

* [view creation](https://www.postgresql.org/docs/current/static/sql-createview.html)

Imagine you need to work with a legacy database containing the following table:

```
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

This table does not follow the Rails conventions at all.
Because simple PostgreSQL views are updateable by default,
we can wrap it as follows:

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

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  self.primary_key = "id"
  def archive!
    update_attribute :archived, true
  end
end
```

```irb
irb> first = Article.create! title: "Winter is coming", status: "published", published_at: 1.year.ago
irb> second = Article.create! title: "Brace yourself", status: "draft", published_at: 1.month.ago

irb> Article.count
=> 2
irb> first.archive!
irb> Article.count
=> 1
```

NOTE: This application only cares about non-archived `Articles`. A view also
allows for conditions so we can exclude the archived `Articles` directly.

Explain
-------

Along with the standard [`explain`][explain-options] options, the PostgreSQL adapter supports [`buffers`][explain-analayze-buffers].

```ruby
Company.where(id: owning_companies_ids).explain(:analyze, :buffers)
#=> EXPLAIN (ANALYZE, BUFFERS) SELECT "companies".* FROM "companies"
# ...
# Seq Scan on companies  (cost=0.00..2.21 rows=3 width=64)
# ...
```

See their documentation for more details.

[explain-options]: active_record_querying.html#explain-options
[explain-analayze-buffers]: https://www.postgresql.org/docs/current/sql-explain.html
