**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Active Record and PostgreSQL
============================

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
