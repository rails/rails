**DO NOT READ THIS FILE ON GITHUB, GUIDES ARE PUBLISHED ON <https://guides.rubyonrails.org>.**

Multiple Databases with Active Record
=====================================

This guide covers using multiple databases with your Rails application.

After reading this guide you will know:

* How to set up your application for multiple databases.
* How automatic connection switching works.
* How to use horizontal sharding for multiple databases.


--------------------------------------------------------------------------------

## Overview

As your application grows, you may need to split data across more than one
database. You might move a group of tables to its own database cluster, send
read traffic to replicas, or partition the same set of tables across multiple
shards.

Rails supports these common multiple database patterns:

* Multiple writer databases, where each database stores a different part of
  your application's data. For example, `User` records might live in the
  `primary` database, while `Dog` records live in the `animals` database. This is
  also called vertical partitioning.
* Read replicas for each writer database, so reads can be sent to a replica
  while writes continue to use the writer.
* Automatic role switching between writers and replicas based on the HTTP verb
  and whether the request recently performed a write.
* Horizontal sharding, where each database has the same schema but stores a
  different subset of the records.
* Rails tasks for creating, dropping, migrating, loading schemas, dumping
  schemas, and interacting with each database.

The right setup depends on what you are trying to accomplish:

| If you need to...                                              | Use...                                                |
| -------------------------------------------------------------- | ----------------------------------------------------- |
| Move some models to a separate database                        | Multiple writer databases                             |
| Send read traffic away from the writer                         | Read replicas and automatic role switching            |
| Split records across databases that share the same schema      | Horizontal sharding                                   |
| Connect to a legacy, reporting, or externally managed database | A database configuration with `database_tasks: false` |

Rails handles the application-side plumbing for these configurations: connection
definitions, abstract connection classes, role and shard switching, and database
tasks. It does not provision database servers, create database users, manage
replication, balance traffic across replicas, or provide distributed
transactions across database clusters. Those responsibilities remain with your
database infrastructure and application architecture.

## Setting Up Multiple Databases

Setting up multiple databases starts with `config/database.yml`. Each entry
names a database configuration that Rails can connect to, and Rails uses those
configuration names later when you connect models, run database tasks, and
switch between writers, replicas, or shards.

Rails supports two layouts for `config/database.yml`. A two-tier configuration
has the environment, such as `development`, point directly to one database
configuration. A three-tier configuration has the environment point to multiple
named database configurations, such as `primary`, `primary_replica`, `animals`,
and `animals_replica`.

INFO: Three-tier configuration refers to the YAML nesting: environment, database configuration name, and then database settings.<br><br><code class="yaml">production:          # tier 1: environment
  primary:           # tier 2: database configuration name
    database: ...    # tier 3: adapter/database/credentials/settings
</code>
<br>
In a default Rails application, `development` and `test` often use a two-tier
configuration, while `production` may already use a three-tier configuration
for `primary`, `cache`, `queue`, and `cable`.

The examples in this guide start with a three-tier production configuration
that has one primary database. The application then adds a second database
named `animals`. Models such as `User` will continue to use the primary
database, while models such as `Dog` will use the animals database. Later
sections build on this example by adding replicas and showing how Rails
switches between them.

### Database Configurations

Suppose you have an application with a single primary database configuration:

```yaml
production:
  primary:
    database: my_primary_database
    adapter: mysql2
    username: root
    password: <%= ENV['ROOT_PASSWORD'] %>
```

To add the `animals` database and replicas for both databases, add new named
database configurations under `production`.

If a `primary` configuration key is provided, it will be used as the default
configuration. If there is no configuration named `primary`, Rails will use the
first configuration as the default for each environment. The default
configuration uses the default Rails filenames. For example, a `primary`
configuration will use `db/schema.rb` for the schema file, whereas other entries
will use `db/[CONFIGURATION_NAMESPACE]_schema.rb`.

```yaml
production:
  primary:
    database: my_primary_database
    username: root
    password: <%= ENV['ROOT_PASSWORD'] %>
    adapter: mysql2
  primary_replica:
    database: my_primary_database
    username: root_readonly
    password: <%= ENV['ROOT_READONLY_PASSWORD'] %>
    adapter: mysql2
    replica: true
  animals:
    database: my_animals_database
    username: animals_root
    password: <%= ENV['ANIMALS_ROOT_PASSWORD'] %>
    adapter: mysql2
    migrations_paths: db/animals_migrate
  animals_replica:
    database: my_animals_database
    username: animals_readonly
    password: <%= ENV['ANIMALS_READONLY_PASSWORD'] %>
    adapter: mysql2
    replica: true
```

The updated configuration defines two writer databases, `primary` and
`animals`. A writer database is the database Rails uses for inserts, updates,
and deletes. Each writer also has a replica: `primary_replica` copies data from
`primary`, and `animals_replica` copies data from `animals`, so Rails can send
read queries to a replica when appropriate.

#### Database Connection URLs

A database connection URL is a single string that contains the adapter,
username, password, host, and database name for a database connection.
Connection URLs can also be configured using environment variables.

The variable name is formed by concatenating the database configuration name
with `_DATABASE_URL`. For example, because the configuration name is `animals`,
Rails looks for an environment variable named `ANIMALS_DATABASE_URL`:

```bash
ANIMALS_DATABASE_URL="mysql2://animals_root:password@localhost/my_animals_database"
```

Rails combines the matching environment variable with the matching
`database.yml` entry. The URL supplies the connection details, while
`database.yml` can keep Rails-specific options such as `migrations_paths`.

For example, `database.yml` does not need to include the username, password,
host, or database name if those details are provided by the connection URL:

```yaml
production:
  animals:
    adapter: mysql2
    migrations_paths: db/animals_migrate
```

When Rails loads the `animals` configuration, it uses
`ANIMALS_DATABASE_URL` for the connection details and keeps
`migrations_paths` from `database.yml`.

See [Configuring a Database](configuring.html#configuring-a-database) for
details about how the merging works.

#### Configuration Settings

When using multiple databases, there are a few important settings.

First, the database name for a writer and its replica should be the same because
they contain the same data. This means `primary` and `primary_replica` should
point to the same database, and `animals` and `animals_replica` should point to
the same database.

```yaml#3,5
production:
  primary:
    database: my_primary_database
  primary_replica:
    database: my_primary_database
```

Second, the username for the writers and replicas should be different, and the
replica user's database permissions should be set to only read and not write.

```yaml#3,5
production:
  primary:
    username: root
  primary_replica:
    username: root_readonly
```

When using a replica database, you need to add `replica: true` to the replica
configuration in `config/database.yml`. Rails otherwise has no way of knowing
which configuration is the replica and which one is the writer. Rails will not
run certain tasks, such as migrations, against replicas.

```yaml#3
production:
  primary_replica:
    replica: true
```

Lastly, for new writer databases, you need to set the `migrations_paths` key to
the directory where you will store migrations for that database. We'll look more
at `migrations_paths` later on in this guide.

```yaml#3
production:
  animals:
    migrations_paths: db/animals_migrate
```

You can also configure the schema dump file by setting `schema_dump` to a
custom schema file name. For example:

```yaml#5
production:
  animals:
    database: my_animals_database
    adapter: mysql2
    schema_dump: db/animals_schema.rb
```

If you want to skip dumping the schema for a database entirely, set
`schema_dump: false`.

#### Connecting Models to Databases

Adding a database configuration tells Rails how to connect to the database, but
Rails also needs to know which models should use that connection. To do that,
define an abstract class for each database and have the models for that database
inherit from it.

Each abstract class owns the connection for one database, or for one writer and
replica pair. Concrete models then inherit from the abstract class for the
database where their table lives.

In `connects_to`, `writing` and `reading` are role names. The `writing` role
points to the writer database, and the `reading` role points to the replica:

```ruby
connects_to database: { writing: :primary, reading: :primary_replica }
```

By default, Rails expects these role names to be `writing` and `reading`.

##### Connecting the Primary Model and Database

The primary database and its replica can be configured in `ApplicationRecord`
this way:

```ruby
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :primary, reading: :primary_replica }
end
```

Models that inherit from `ApplicationRecord` will use the `primary` database for
writes and the `primary_replica` database for reads when Rails is switched to
the reading role.

If you use a differently named class for your application record, set
`primary_abstract_class` so that Rails knows which class `ActiveRecord::Base`
should share a connection with:

```ruby
class PrimaryApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  connects_to database: { writing: :primary, reading: :primary_replica }
end
```

In that case, classes that connect to `primary`/`primary_replica` can inherit
from your primary abstract class like standard Rails applications do with
`ApplicationRecord`:

```ruby
class Person < PrimaryApplicationRecord
end
```

##### Connecting the Animals Model and Database

Next, set up an abstract class for models stored in the `animals` database:

```ruby
class AnimalsRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :animals, reading: :animals_replica }
end
```

Models stored in the `animals` database should inherit from that common
abstract class:

```ruby
class Dog < AnimalsRecord
  # Talks automatically to the animals database.
end
```

`Dog` now uses the `animals` database for writes and the `animals_replica`
database for reads when Rails is switched to the reading role.

WARNING. It's important to connect to each database from a single abstract class and
then inherit from that class for the models stored in that database. Connecting
multiple individual models to the same database multiplies the number of
connections, because Rails uses the model class name for the connection
specification name.

#### Custom Role Names

If your application already uses different role names, you can configure Rails
to use those names instead:

```ruby
config.active_record.writing_role = :default
config.active_record.reading_role = :readonly
```

After changing the role names, use those names in `connects_to`:

```ruby
connects_to database: { default: :primary, readonly: :primary_replica }
```

#### Running Database Tasks

Rails creates database tasks for each managed database configuration. Running a
task without a database name applies it to all managed databases, for example:

```bash
$ bin/rails db:create
$ bin/rails db:migrate
$ bin/rails db:schema:dump
```

To run a task for one database, append the database configuration name:

```bash
$ bin/rails db:create:animals
$ bin/rails db:migrate:animals
$ bin/rails db:schema:dump:animals
```

The same pattern applies to the primary database:

```bash
$ bin/rails db:migrate:primary
```

Rails does not create database tasks for replicas. For example,
`primary_replica` and `animals_replica` do not get migration tasks because they
are marked with `replica: true`.

Running `bin/rails db:create` will create both the primary and animals
databases. Rails does not create database users; create writer and read-only
replica users in your database system.

For the full list of Rails database commands, see the
[Command Line guide](command_line.html#managing-the-database).

### Connecting to Databases Managed Outside Rails

Some applications connect to databases that Rails should use but not manage.
For example, you might connect to a legacy database, a reporting database, or a
database owned by another application.

In those cases, Rails needs the database configuration so models can connect to
the database, but Rails should not run database management tasks such as
creating, dropping, migrating, seeding, or dumping the schema for that database.
Set `database_tasks: false` on the database configuration to opt out of those
tasks. By default, `database_tasks` is `true`.

```yaml
production:
  primary:
    database: my_database
    adapter: mysql2
  reporting:
    database: my_reporting_database
    adapter: mysql2
    database_tasks: false
```

In this example, Rails will still connect to the `reporting` database when a
model uses that configuration, but commands such as `bin/rails db:create`,
`bin/rails db:migrate`, and `bin/rails db:schema:dump` will skip it.

### Generating Migrations and Models

Each managed writer database needs a migration path. Keeping migrations
separate lets Rails migrate one database without running migrations intended for
another database. Replicas do not need migration paths because Rails does not
run migrations against configurations marked with `replica: true`.

#### Migration Paths

Migrations for multiple databases should live in their own folders prefixed
with the name of the database key in the configuration. You also need to set
`migrations_paths` in the database configuration to tell Rails where to find
those migrations.

The `primary` database uses the default `db/migrate` path, so you usually only
need to set `migrations_paths` for additional writer databases. In the example
configuration, the `animals` database uses `db/animals_migrate`:

```yaml
production:
  animals:
    migrations_paths: db/animals_migrate
```

#### Generating Migrations

Rails generators take a `--database` option so that generated migration files
are placed in the correct directory:

```bash
$ bin/rails generate migration CreateDogs name:string --database animals
```

This creates the migration in `db/animals_migrate`. Without `--database
animals`, the migration would be generated in the default migration path.

#### Generating Models and Scaffolds

The model and scaffold generators also take the `--database` option:

```bash
$ bin/rails generate scaffold Dog name:string --database animals
```

When you pass `--database`, Rails generates an abstract class for that database
unless one already exists. The class name is the camelized database name
followed by `Record`. In this example, the database is `animals`, so Rails
generates `AnimalsRecord`:

```ruby
class AnimalsRecord < ApplicationRecord
  self.abstract_class = true

  connects_to database: { writing: :animals }
end
```

The generated model will automatically inherit from `AnimalsRecord`.

```ruby
class Dog < AnimalsRecord
end
```

NOTE: Since Rails doesn't know which database is the replica for your writer you will need to add this to the abstract class after you're done: `connects_to database: { writing: :animals, reading: :animals_replica }`.

Rails will only generate `AnimalsRecord` once. It will not be overwritten by new
scaffolds or deleted if the scaffold is deleted, so your changes to the
abstract class are preserved.

#### Using a Custom Abstract Class

If you already have an abstract class and its name differs from
`AnimalsRecord`, pass the `--parent` option to tell Rails which class the model
should inherit from:

```bash
$ bin/rails generate scaffold Dog name:string --database animals --parent Animals::Record
```

This will skip generating `AnimalsRecord` since you've indicated to Rails that you want to
use a different parent class.

### Activating Automatic Role Switching

Automatic switching allows the application to switch from the writer to the replica or the replica
to the writer based on the HTTP verb and whether there was a recent write by the requesting user.

If the application receives a POST, PUT, DELETE, or PATCH request, the application will
automatically write to the writer database. If the request is not one of those methods,
but the application recently made a write, the writer database will also be used. All
other requests will use the replica database.

To activate the automatic connection switching middleware you can run the automatic swapping
generator:

```bash
$ bin/rails g active_record:multi_db
```

And then uncomment the following lines:

```ruby
Rails.application.configure do
  config.active_record.database_selector = { delay: 2.seconds }
  config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
  config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
end
```

Rails guarantees "read your own write" and will send your GET or HEAD request to the
writer if it's within the `delay` window. By default the delay is set to 2 seconds. You
should change this based on your database infrastructure. Rails doesn't guarantee "read
a recent write" for other users within the delay window and will send GET and HEAD requests
to the replicas unless they wrote recently.

The automatic connection switching in Rails is relatively primitive and deliberately doesn't
do a whole lot. The goal is a system that demonstrates how to do automatic connection
switching that is flexible enough to be customizable by app developers.

The setup in Rails allows you to easily change how the switching is done and what
parameters it's based on. Let's say you want to use a cookie instead of a session to
decide when to swap connections. You can write your own class:

```ruby
class MyCookieResolver < ActiveRecord::Middleware::DatabaseSelector::Resolver
  def self.call(request)
    new(request.cookies)
  end

  def initialize(cookies)
    @cookies = cookies
  end

  attr_reader :cookies

  def last_write_timestamp
    self.class.convert_timestamp_to_time(cookies[:last_write])
  end

  def update_last_write_timestamp
    cookies[:last_write] = self.class.convert_time_to_timestamp(Time.now)
  end

  def save(response)
  end
end
```

And then pass it to the middleware:

```ruby
config.active_record.database_selector = { delay: 2.seconds }
config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
config.active_record.database_resolver_context = MyCookieResolver
```

### Using Manual Connection Switching

There are some cases where you may want your application to connect to a writer or a replica
and the automatic connection switching isn't adequate. For example, you may know that for a
particular request you always want to send the request to a replica, even when you are in a
POST request path.

To do this Rails provides a `connected_to` method that will switch to the connection you
need.

```ruby
ActiveRecord::Base.connected_to(role: :reading) do
  # All code in this block will be connected to the reading role.
end
```

The "role" in the `connected_to` call looks up the connections that are connected on that
connection handler (or role). The `reading` connection handler will hold all the connections
that were connected via `connects_to` with the role name of `reading`.

Note that `connected_to` with a role will look up an existing connection and switch
using the connection specification name. This means that if you pass an unknown role
like `connected_to(role: :nonexistent)` you will get an error that says
`ActiveRecord::ConnectionNotEstablished (No connection pool for 'ActiveRecord::Base' found for the 'nonexistent' role.)`

If you want Rails to ensure any queries performed are read-only, pass `prevent_writes: true`.
This just prevents queries that look like writes from being sent to the database.
You should also configure your replica database to run in read-only mode.

```ruby
ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
  # Rails will check each query to ensure it's a read query.
end
```

## Horizontal Sharding

Horizontal sharding is when you split up your database to reduce the number of rows on each
database server, but maintain the same schema across "shards". This is commonly called "multi-tenant"
sharding.

The API for supporting horizontal sharding in Rails is similar to the multiple database / vertical
sharding API.

Shards are declared in the three-tier config like this:

```yaml
production:
  primary:
    database: my_primary_database
    adapter: mysql2
  primary_replica:
    database: my_primary_database
    adapter: mysql2
    replica: true
  primary_shard_one:
    database: my_primary_shard_one
    adapter: mysql2
    migrations_paths: db/migrate_shards
  primary_shard_one_replica:
    database: my_primary_shard_one
    adapter: mysql2
    replica: true
  primary_shard_two:
    database: my_primary_shard_two
    adapter: mysql2
    migrations_paths: db/migrate_shards
  primary_shard_two_replica:
    database: my_primary_shard_two
    adapter: mysql2
    replica: true
```

Models are then connected with the `connects_to` API via the `shards` key:

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  connects_to database: { writing: :primary, reading: :primary_replica }
end

class ShardRecord < ApplicationRecord
  self.abstract_class = true

  connects_to shards: {
    shard_one: { writing: :primary_shard_one, reading: :primary_shard_one_replica },
    shard_two: { writing: :primary_shard_two, reading: :primary_shard_two_replica }
  }
end

class Customer < ShardRecord
end
```

If you're using shards, make sure both `migrations_paths` and `schema_dump` remain unchanged for
all the shards. When generating a migration you can pass the `--database` option and
use one of the shard names. Since they all set the same path, it doesn't matter which
one you choose.

```
$ bin/rails g scaffold Dog name:string --database primary_shard_one
```

Then models can swap shards manually via the `connected_to` API. If
using sharding, both a `role` and a `shard` must be passed:

```ruby
ShardRecord.connected_to(role: :writing, shard: :shard_one) do
  @customer = Customer.create! # Creates a record in shard shard_one
end

ShardRecord.connected_to(role: :writing, shard: :shard_two) do
  Customer.find(@customer.id) # Can't find record, doesn't exist because it was created
                   # in the shard named ":shard_one".
end
```

The horizontal sharding API also supports read replicas. You can swap the
role and the shard with the `connected_to` API.

```ruby
ShardRecord.connected_to(role: :reading, shard: :shard_one) do
  Customer.first # Lookup record from read replica of shard one.
end
```

### Activating Automatic Shard Switching

Applications are able to automatically switch shards per request using the `ShardSelector`
middleware, which allows an application to provide custom logic for determining the appropriate
shard for each request.

The same generator used for the database selector above can be used to generate an initializer file
for automatic shard swapping:

```bash
$ bin/rails g active_record:multi_db
```

Then in the generated `config/initializers/multi_db.rb` uncomment and modify the following code:

```ruby
Rails.application.configure do
  config.active_record.shard_selector = { lock: true }
  config.active_record.shard_resolver = ->(request) { Tenant.find_by!(host: request.host).shard }
end
```

Applications must provide a resolver to provide application-specific logic. An example resolver that
uses a subdomain to determine the shard might look like this:

```ruby
config.active_record.shard_resolver = ->(request) {
  subdomain = request.subdomain
  tenant = Tenant.find_by_subdomain!(subdomain)
  tenant.shard
}
```

The behavior of `ShardSelector` can be altered through some configuration options.

`lock` is true by default and will prohibit the request from switching shards during the request. If
`lock` is false, then shard swapping will be allowed. For tenant-based sharding, `lock` should
always be true to prevent application code from mistakenly switching between tenants.

`class_name` is the name of the abstract connection class to switch. By default, the `ShardSelector`
will use `ActiveRecord::Base`, but if the application has multiple databases, then this option
should be set to the name of the sharded database's abstract connection class.

Options may be set in the application configuration. For example, this configuration tells
`ShardSelector` to switch shards using `AnimalsRecord.connected_to`:


``` ruby
config.active_record.shard_selector = { lock: true, class_name: "AnimalsRecord" }
```

## Granular Database Connection Switching

It's possible to switch connections for one database instead of all databases globally.

With granular database connection switching, any abstract connection class
will be able to switch connections without affecting other connections. This
is useful for switching your `AnimalsRecord` queries to read from the replica
while ensuring your `ApplicationRecord` queries go to the primary.

```ruby
AnimalsRecord.connected_to(role: :reading) do
  Dog.first # Reads from animals_replica.
  Person.first  # Reads from primary.
end
```

It's also possible to swap connections granularly for shards.

```ruby
AnimalsRecord.connected_to(role: :reading, shard: :shard_one) do
  # Will read from shard_one_replica. If no connection exists for shard_one_replica,
  # a ConnectionNotEstablished error will be raised.
  Dog.first

  # Will read from primary writer.
  Person.first
end
```

To switch only the primary database cluster use `ApplicationRecord`:

```ruby
ApplicationRecord.connected_to(role: :reading, shard: :shard_one) do
  Person.first # Reads from primary_shard_one_replica.
  Dog.first # Reads from animals_primary.
end
```

`ActiveRecord::Base.connected_to` maintains the ability to switch
connections globally.

### Handling Associations with Joins across Databases

Active Record has an option for handling associations that would perform a join across multiple
databases. If you have a has many through or a has one through association that you want to disable
joining and perform 2 or more queries, pass the `disable_joins: true` option.

For example:

```ruby
class Dog < AnimalsRecord
  has_many :humans, disable_joins: true
  has_many :treats, through: :humans, disable_joins: true

  has_one :home
  has_one :yard, through: :home, disable_joins: true
end

class Human < ApplicationRecord
  belongs_to :dog
  has_many :treats
end

class Treat < ApplicationRecord
  belongs_to :human
end

class Home < ApplicationRecord
  belongs_to :dog
  has_one :yard
end

class Yard < ApplicationRecord
  belongs_to :home
end
```

Previously calling `@dog.treats` without `disable_joins` or `@dog.yard` without `disable_joins`
would raise an error because databases are unable to handle joins across clusters. With the
`disable_joins` option, Rails will generate multiple select queries
to avoid attempting joining across clusters. For the above association, `@dog.treats` would generate the
following SQL:

```sql
SELECT "humans"."id" FROM "humans" WHERE "humans"."dog_id" = ?  [["dog_id", 1]]
SELECT "treats".* FROM "treats" WHERE "treats"."human_id" IN (?, ?, ?)  [["human_id", 1], ["human_id", 2], ["human_id", 3]]
```

While `@dog.yard` would generate the following SQL:

```sql
SELECT "home"."id" FROM "homes" WHERE "homes"."dog_id" = ? [["dog_id", 1]]
SELECT "yards".* FROM "yards" WHERE "yards"."home_id" = ? [["home_id", 1]]
```

There are some important things to be aware of with this option:

1. There may be performance implications since now two or more queries will be performed (depending
   on the association) rather than a join. If the select for `humans` returned a high number of IDs
   the select for `treats` may send too many IDs.
2. Since we are no longer performing joins, a query with an order or limit is now sorted in-memory since
   order from one table cannot be applied to another table.
3. This setting must be added to all associations where you want joining to be disabled.
   Rails can't guess this for you because association loading is lazy, to load `treats` in `@dog.treats`
   Rails already needs to know what SQL should be generated.

### Schema Caching

If you want to load a schema cache for each database you must set
`schema_cache_path` in each database configuration and set
`config.active_record.lazily_load_schema_cache = true` in your application
configuration.

Schema caching stores a snapshot of the database table and column metadata so Rails
does not have to query the database for that information every time a connection is
established.


NOTE: With these settings the cache is loaded lazily when the database connections are established.

## Caveats

### Load Balancing Replicas

Rails doesn't support automatic load balancing of replicas. This is very
dependent on your infrastructure. We may implement basic, primitive load
balancing in the future, but for an application at scale this should be
something your application handles outside of Rails.
