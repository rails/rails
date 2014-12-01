Active Record and PostgreSQL
============================

This guide covers PostgreSQL specific usage of Active Record.

After reading this guide, you will know:

* How to use PostgreSQL's datatypes.
* How to use UUID primary keys.
* How to implement full text search with PostgreSQL.
* How to back your Active Record models with database views.

--------------------------------------------------------------------------------

In order to use the PostgreSQL adapter you need to have at least version 8.2
installed. Older versions are not supported.

To get started with PostgreSQL have a look at the
[configuring Rails guide](configuring.html#configuring-a-postgresql-database).
It describes how to properly setup Active Record for PostgreSQL.

Datatypes
---------

PostgreSQL offers a number of specific datatypes. Following is a list of types,
that are supported by the PostgreSQL adapter.

### Bytea

* [type definition](http://www.postgresql.org/docs/9.3/static/datatype-binary.html)
* [functions and operators](http://www.postgresql.org/docs/9.3/static/functions-binarystring.html)

```ruby
# db/migrate/20140207133952_create_documents.rb
create_table :documents do |t|
  t.binary 'payload'
end

# app/models/document.rb
class Document < ActiveRecord::Base
end

# Usage
data = File.read(Rails.root + "tmp/output.pdf")
Document.create payload: data
```

### Array

* [type definition](http://www.postgresql.org/docs/9.3/static/arrays.html)
* [functions and operators](http://www.postgresql.org/docs/9.3/static/functions-array.html)

```ruby
# db/migrate/20140207133952_create_books.rb
create_table :books do |t|
  t.string 'title'
  t.string 'tags', array: true
  t.integer 'ratings', array: true
end
add_index :books, :tags, using: 'gin'
add_index :books, :ratings, using: 'gin'

# app/models/book.rb
class Book < ActiveRecord::Base
end

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

### Hstore

* [type definition](http://www.postgresql.org/docs/9.3/static/hstore.html)

```ruby
# db/migrate/20131009135255_create_profiles.rb
ActiveRecord::Schema.define do
  create_table :profiles do |t|
    t.hstore 'settings'
  end
end

# app/models/profile.rb
class Profile < ActiveRecord::Base
end

# Usage
Profile.create(settings: { "color" => "blue", "resolution" => "800x600" })

profile = Profile.first
profile.settings # => {"color"=>"blue", "resolution"=>"800x600"}

profile.settings = {"color" => "yellow", "resolution" => "1280x1024"}
profile.save!
```

### JSON

* [type definition](http://www.postgresql.org/docs/9.3/static/datatype-json.html)
* [functions and operators](http://www.postgresql.org/docs/9.3/static/functions-json.html)

```ruby
# db/migrate/20131220144913_create_events.rb
create_table :events do |t|
  t.json 'payload'
end

# app/models/event.rb
class Event < ActiveRecord::Base
end

# Usage
Event.create(payload: { kind: "user_renamed", change: ["jack", "john"]})

event = Event.first
event.payload # => {"kind"=>"user_renamed", "change"=>["jack", "john"]}

## Query based on JSON document
# The -> operator returns the original JSON type (which might be an object), whereas ->> returns text
Event.where("payload->>'kind' = ?", "user_renamed")
```

### Range Types

* [type definition](http://www.postgresql.org/docs/9.3/static/rangetypes.html)
* [functions and operators](http://www.postgresql.org/docs/9.3/static/functions-range.html)

This type is mapped to Ruby [`Range`](http://www.ruby-doc.org/core-2.1.1/Range.html) objects.

```ruby
# db/migrate/20130923065404_create_events.rb
create_table :events do |t|
  t.daterange 'duration'
end

# app/models/event.rb
class Event < ActiveRecord::Base
end

# Usage
Event.create(duration: Date.new(2014, 2, 11)..Date.new(2014, 2, 12))

event = Event.first
event.duration # => Tue, 11 Feb 2014...Thu, 13 Feb 2014

## All Events on a given date
Event.where("duration @> ?::date", Date.new(2014, 2, 12))

## Working with range bounds
event = Event.
  select("lower(duration) AS starts_at").
  select("upper(duration) AS ends_at").first

event.starts_at # => Tue, 11 Feb 2014
event.ends_at # => Thu, 13 Feb 2014
```

### Composite Types

* [type definition](http://www.postgresql.org/docs/9.3/static/rowtypes.html)

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

# app/models/contact.rb
class Contact < ActiveRecord::Base
end

# Usage
Contact.create address: "(Paris,Champs-Élysées)"
contact = Contact.first
contact.address # => "(Paris,Champs-Élysées)"
contact.address = "(Paris,Rue Basse)"
contact.save!
```

### Enumerated Types

* [type definition](http://www.postgresql.org/docs/9.3/static/datatype-enum.html)

Currently there is no special support for enumerated types. They are mapped as
normal text columns:

```ruby
# db/migrate/20131220144913_create_articles.rb
execute <<-SQL
  CREATE TYPE article_status AS ENUM ('draft', 'published');
SQL
create_table :articles do |t|
  t.column :status, :article_status
end

# app/models/article.rb
class Article < ActiveRecord::Base
end

# Usage
Article.create status: "draft"
article = Article.first
article.status # => "draft"

article.status = "published"
article.save!
```

### UUID

* [type definition](http://www.postgresql.org/docs/9.3/static/datatype-uuid.html)
* [generator functions](http://www.postgresql.org/docs/9.3/static/uuid-ossp.html)


```ruby
# db/migrate/20131220144913_create_revisions.rb
create_table :revisions do |t|
  t.column :identifier, :uuid
end

# app/models/revision.rb
class Revision < ActiveRecord::Base
end

# Usage
Revision.create identifier: "A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11"

revision = Revision.first
revision.identifier # => "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
```

### Bit String Types

* [type definition](http://www.postgresql.org/docs/9.3/static/datatype-bit.html)
* [functions and operators](http://www.postgresql.org/docs/9.3/static/functions-bitstring.html)

```ruby
# db/migrate/20131220144913_create_users.rb
create_table :users, force: true do |t|
  t.column :settings, "bit(8)"
end

# app/models/device.rb
class User < ActiveRecord::Base
end

# Usage
User.create settings: "01010011"
user = User.first
user.settings # => "01010011"
user.settings = "0xAF"
user.settings # => 10101111
user.save!
```

### Network Address Types

* [type definition](http://www.postgresql.org/docs/9.3/static/datatype-net-types.html)

The types `inet` and `cidr` are mapped to Ruby
[`IPAddr`](http://www.ruby-doc.org/stdlib-2.1.1/libdoc/ipaddr/rdoc/IPAddr.html)
objects. The `macaddr` type is mapped to normal text.

```ruby
# db/migrate/20140508144913_create_devices.rb
create_table(:devices, force: true) do |t|
  t.inet 'ip'
  t.cidr 'network'
  t.macaddr 'address'
end

# app/models/device.rb
class Device < ActiveRecord::Base
end

# Usage
macbook = Device.create(ip: "192.168.1.12",
                        network: "192.168.2.0/24",
                        address: "32:01:16:6d:05:ef")

macbook.ip
# => #<IPAddr: IPv4:192.168.1.12/255.255.255.255>

macbook.network
# => #<IPAddr: IPv4:192.168.2.0/255.255.255.0>

macbook.address
# => "32:01:16:6d:05:ef"
```

### Geometric Types

* [type definition](http://www.postgresql.org/docs/9.3/static/datatype-geometric.html)

All geometric types, with the exception of `points` are mapped to normal text.
A point is casted to an array containing `x` and `y` coordinates.


UUID Primary Keys
-----------------

NOTE: you need to enable the `uuid-ossp` extension to generate UUIDs.

```ruby
# db/migrate/20131220144913_create_devices.rb
enable_extension 'uuid-ossp' unless extension_enabled?('uuid-ossp')
create_table :devices, id: :uuid, default: 'uuid_generate_v4()' do |t|
  t.string :kind
end

# app/models/device.rb
class Device < ActiveRecord::Base
end

# Usage
device = Device.create
device.id # => "814865cd-5a1d-4771-9306-4268f188fe9e"
```

Full Text Search
----------------

```ruby
# db/migrate/20131220144913_create_documents.rb
create_table :documents do |t|
  t.string 'title'
  t.string 'body'
end

execute "CREATE INDEX documents_idx ON documents USING gin(to_tsvector('english', title || ' ' || body));"

# app/models/document.rb
class Document < ActiveRecord::Base
end

# Usage
Document.create(title: "Cats and Dogs", body: "are nice!")

## all documents matching 'cat & dog'
Document.where("to_tsvector('english', title || ' ' || body) @@ to_tsquery(?)",
                 "cat & dog")
```

Database Views
--------------

* [view creation](http://www.postgresql.org/docs/9.3/static/sql-createview.html)

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

# app/models/article.rb
class Article < ActiveRecord::Base
  self.primary_key = "id"
  def archive!
    update_attribute :archived, true
  end
end

# Usage
first = Article.create! title: "Winter is coming",
                        status: "published",
                        published_at: 1.year.ago
second = Article.create! title: "Brace yourself",
                         status: "draft",
                         published_at: 1.month.ago

Article.count # => 1
first.archive!
Article.count # => 2
```

NOTE: This application only cares about non-archived `Articles`. A view also
allows for conditions so we can exclude the archived `Articles` directly.
