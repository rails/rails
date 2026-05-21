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
tasks.


NOTE: Rails does not provision database servers, create database users, manage
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

### Models and Migrations

Once the database configurations are in place, the next step is to connect
models to those configurations and make sure migrations are generated in the
right directories.

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

WARNING: It's important to connect to each database from a single abstract class
and then inherit from that class for the models stored in that database.
Connecting multiple individual models to the same database multiplies the
number of connections, because Rails uses the model class name for the
connection specification name.

If you create models and migrations with Rails generators, pass the database
name so Rails can place files in the right migration path and use the right
abstract class.

#### Generating Migrations

Each managed writer database needs a migration path. Keeping migrations
separate lets Rails migrate one database without running migrations intended for
another database. Replicas do not need migration paths because Rails does not
run migrations against configurations marked with `replica: true`.

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

Since Rails doesn't know which database is the replica for your writer, add the
replica to the abstract class after it's generated:

```ruby
connects_to database: { writing: :animals, reading: :animals_replica }
```

Rails will only generate `AnimalsRecord` once. It will not be overwritten by new
scaffolds or deleted if the scaffold is deleted, so your changes to the
abstract class are preserved.

If you already have an abstract class and its name differs from
`AnimalsRecord`, pass the `--parent` option to tell Rails which class the model
should inherit from:

```bash
$ bin/rails generate scaffold Dog name:string --database animals --parent Animals::Record
```

This will skip generating `AnimalsRecord` since you've indicated to Rails that you want to
use a different parent class.

### Database Tasks

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

Other Rails commands can also target a database configuration by name. For
example, `bin/rails dbconsole --database=animals` opens a database console for
the `animals` database, and `bin/rails query "Dog.count" --database animals`
runs a read-only query against that database configuration.

For the full list of Rails database commands, see the
[Command Line guide](command_line.html#managing-the-database).

### External Databases

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

### Role Switching

Role switching lets Rails choose between the `writing` and `reading` roles.
These roles usually point to a writer database and its replica.

#### Automatic Role Switching

Automatic role switching lets Rails choose between the writer and replica for
each request. This is sometimes called automatic connection switching.

You may want automatic role switching when your application uses replicas to
reduce read traffic on the writer, but still needs users to see their own
changes immediately after they write. It is implemented as middleware, so it
applies to web requests.

The middleware chooses a role based on the HTTP verb and whether the same
requesting user recently wrote to the database:

* `POST`, `PUT`, `PATCH`, and `DELETE` requests use the writer database.
* `GET` and `HEAD` requests use the replica, unless the user recently wrote to
  the database.
* `GET` and `HEAD` requests from a user who recently wrote to the database use
  the writer until the configured delay has passed.

This helps the application provide "read your own write" behavior. For example,
after a user submits a form, a redirect back to a `GET` request can still read
from the writer for a short time so the user can see their own change.

To activate the automatic connection switching middleware, run the automatic
swapping generator:

```bash
$ bin/rails g active_record:multi_db
```

Then uncomment the following lines in the generated initializer:

```ruby
Rails.application.configure do
  config.active_record.database_selector = { delay: 2.seconds }
  config.active_record.database_resolver = ActiveRecord::Middleware::DatabaseSelector::Resolver
  config.active_record.database_resolver_context = ActiveRecord::Middleware::DatabaseSelector::Resolver::Session
end
```

The `delay` controls how long Rails keeps sending a user's reads to the writer
after that user writes. By default, the delay is set to 2 seconds. Change this
based on your database infrastructure and expected replication lag.

Rails does not guarantee that other users will immediately see a recent write.
For users who did not perform the write, `GET` and `HEAD` requests can still go
to the replica and may be affected by replication lag.

Automatic role switching is intentionally simple. It does not inspect actual
replication lag, load balance across multiple replicas, or decide per query
which database should be used. The default behavior is designed to be a small,
customizable starting point for applications.

You can change how Rails tracks the last write. By default, Rails stores the
last write timestamp in the session. If you want to use a cookie instead, you
can write your own resolver context:

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

#### Manual Role Switching

Manual role switching lets you choose the database role for a block of code.
Use it when automatic role switching would choose the wrong role for a specific
case, or when automatic role switching does not apply, such as in scripts,
console sessions, and background jobs.

For example, automatic role switching sends `POST` requests to the writer, but
you may have a `POST` request that only reads data and should use a replica.

To switch roles manually, wrap the code in `connected_to`:

```ruby
ActiveRecord::Base.connected_to(role: :reading) do
  # All code in this block uses the reading role.
end
```

The role passed to `connected_to` must match a role defined by `connects_to`.
In the examples above, the `reading` role points to the replica configuration:

```ruby
connects_to database: { writing: :primary, reading: :primary_replica }
```

If you pass an unknown role, Rails raises an error:

```ruby
ActiveRecord::Base.connected_to(role: :nonexistent) do
  # ...
end
```

The error will look like:

`ActiveRecord::ConnectionNotEstablished (No connection pool for 'ActiveRecord::Base' found for the 'nonexistent' role.)`

If you want Rails to prevent write queries while using a role, pass
`prevent_writes: true`. This prevents queries that look like writes from being
sent to the database:

```ruby
ActiveRecord::Base.connected_to(role: :reading, prevent_writes: true) do
  # Rails will check each query to ensure it's a read query.
end
```

This Rails-level check is not a substitute for database permissions. You should
also configure replica users as read-only in your database.

## Horizontal Sharding

Horizontal sharding splits records across multiple databases that share the
same schema. Each database is called a shard. For example, one shard might store
customers 1 through 100, while another shard stores customers 101 through 200.

Sharding is different from replication. A replica copies the same data from its
writer. A shard stores a different subset of records. Applications commonly use
sharding when one database has too much data or traffic, or when tenant or
account data should be distributed across database servers.

Rails uses the same `connects_to` and `connected_to` APIs for sharding.

### Configuring Shards

Shards are declared as database configurations in `config/database.yml`. Each
shard needs a writer configuration, and can also have a replica configuration:

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

In this example, `primary_shard_one` and `primary_shard_two` are database
configuration names. Later, [the model connection maps those configurations to
Rails shard names](#connecting-models-to-shards), such as `shard_one` and `shard_two`.

Each shard can also have its own replica. `primary_shard_one` stores one subset
of records, and `primary_shard_one_replica` is a read replica of that same
shard. `primary_shard_two` stores a different subset of records, and
`primary_shard_two_replica` is a read replica of that second shard. Shards split
records across databases; replicas copy one shard's data so reads for that shard
can be sent away from its writer.

### Connecting Models to Shards

Models are connected to shards with the `connects_to` API using the `shards`
key:

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

In this example, `Customer` inherits from `ShardRecord`, so `Customer` records
can be stored on either `shard_one` or `shard_two`. The `shard_one` name maps to
the `primary_shard_one` writer and `primary_shard_one_replica` replica. The
`shard_two` name maps to the `primary_shard_two` writer and
`primary_shard_two_replica` replica.

### Generating Migrations for Shards

Shards usually share a schema, so shard migrations should use the same
`migrations_paths` and `schema_dump` settings across all shards.

When generating a migration or scaffold, pass `--database` with one of the
shard database configuration names. Since both shards use the same migration
path, it does not matter which shard configuration you choose.

```bash
$ bin/rails g scaffold Customer name:string --database primary_shard_one
```

This command generates the scaffold and places the migration in the shared
`db/migrate_shards` path.

### Shard Switching

Rails needs to know which shard to use for each operation. You can choose the
shard manually with `connected_to`, or configure middleware to choose the shard
for each request.

#### Manual Shard Switching

Use manual shard switching when you need to run a block of code against a
specific shard. This is common in background jobs, data migrations, scripts, or
service objects where there is no request middleware to choose the shard.

To switch shards manually, use `connected_to` with both a `role` and a `shard`:

```ruby
ShardRecord.connected_to(role: :writing, shard: :shard_one) do
  @customer = Customer.create! # Creates a record in shard shard_one
end

ShardRecord.connected_to(role: :writing, shard: :shard_two) do
  Customer.find(@customer.id) # Can't find record, doesn't exist because it was created
                   # in the shard named ":shard_one".
end
```

The shard name must match one of the shard keys passed to `connects_to`, such
as `shard_one` or `shard_two`.

The horizontal sharding API also supports read replicas. To read from a shard's
replica, use the `reading` role with the shard:

```ruby
ShardRecord.connected_to(role: :reading, shard: :shard_one) do
  Customer.first # Lookup record from read replica of shard one.
end
```

#### Automatic Shard Switching

Applications can automatically switch shards per request using the
`ShardSelector` middleware. This is useful for tenant-based applications where
each request can be mapped to a shard, for example from a subdomain or current
account.

The same generator used for the database selector above can be used to generate
an initializer file for automatic shard swapping:

```bash
$ bin/rails g active_record:multi_db
```

Then in the generated `config/initializers/multi_db.rb`, uncomment and modify
the following code:

```ruby
Rails.application.configure do
  config.active_record.shard_selector = { lock: true }
  config.active_record.shard_resolver = ->(request) { Tenant.find_by!(host: request.host).shard }
end
```

Applications must provide a resolver because Rails cannot know how your
application assigns tenants or accounts to shards. An example resolver that
uses a subdomain to determine the shard might look like this:

```ruby
config.active_record.shard_resolver = ->(request) {
  subdomain = request.subdomain
  tenant = Tenant.find_by_subdomain!(subdomain)
  tenant.shard
}
```

The behavior of `ShardSelector` can be altered through some configuration
options.

- `lock` is true by default and prevents the request from switching shards after
  the resolver chooses one. If `lock` is false, shard swapping is allowed
  during the request. For tenant-based sharding, `lock` should usually be true
  to prevent application code from accidentally switching between tenants.

- `class_name` is the name of the abstract connection class to switch. By
  default, the `ShardSelector` uses `ActiveRecord::Base`. If the application
  has multiple abstract connection classes, set `class_name` to the sharded
  database's abstract connection class.

Options may be set in the application configuration. For example, this
configuration tells `ShardSelector` to switch shards using
`ShardRecord.connected_to`:

```ruby
config.active_record.shard_selector = { lock: true, class_name: "ShardRecord" }
```

## Granular Role and Shard Switching

By default, calling `connected_to` on `ActiveRecord::Base` switches the role or
shard for all abstract connection classes. In a multiple database application,
you may only want to switch one database connection while leaving the others
unchanged.

Granular role and shard switching lets you call `connected_to` on a specific
abstract class. This is useful when you want `AnimalsRecord` queries to read
from the replica while `ApplicationRecord` queries continue using the primary
writer.

```ruby
AnimalsRecord.connected_to(role: :reading) do
  Dog.first # Reads from animals_replica.
  Person.first  # Reads from primary.
end
```

Inside the block, only models that inherit from `AnimalsRecord` switch to the
`reading` role. Models that inherit from `ApplicationRecord` keep using their
current role.

You can also switch one sharded abstract class to a specific shard:

```ruby
ShardRecord.connected_to(role: :reading, shard: :shard_one) do
  Customer.first # Reads from primary_shard_one_replica.
  Person.first  # Reads from primary writer.
end
```

If no connection exists for the requested role and shard, Rails raises
`ActiveRecord::ConnectionNotEstablished`.

To switch only the primary database cluster, call `connected_to` on
`ApplicationRecord`:

```ruby
ApplicationRecord.connected_to(role: :reading) do
  Person.first # Reads from primary_replica.
  Dog.first # Reads from animals writer.
end
```

Use `ActiveRecord::Base.connected_to` when you want to switch all abstract
connection classes globally.

## Handling Associations Across Databases

Databases cannot perform SQL joins across separate database clusters. If an
association would require Rails to join tables that live in different databases,
the query cannot be sent as a single SQL join.

For `has_many :through` and `has_one :through` associations, you can pass
`disable_joins: true` to tell Rails to load the association with separate
queries instead of a join.

In this example, `Dog` is stored in the `animals` database, while `Human`,
`Treat`, `Home`, and `Yard` are stored in the primary database:

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

Notice that `disable_joins: true` is added to the associations in the `Dog`
model. If these models used the same database connection, Rails would normally
load the association with a SQL join. Since the associated models are backed by
different database connections, Rails needs to avoid that join. Without
`disable_joins: true`, calling `@dog.treats` or `@dog.yard` would raise an
error because databases are unable to handle joins across clusters.

The `disable_joins: true` option tells Rails to skip the SQL join for that
association and load the records with two or more queries instead.

Instead of building one query that joins the tables, Rails queries the
intermediate association first, collects the IDs it needs, and then uses those
IDs in a second query for the associated records.

In the example below, to get `@dog.treats`, Rails first loads the associated
`humans` IDs, and then uses those IDs to load `treats`:

```sql
SELECT "humans"."id" FROM "humans" WHERE "humans"."dog_id" = ?  [["dog_id", 1]]
SELECT "treats".* FROM "treats" WHERE "treats"."human_id" IN (?, ?, ?)  [["human_id", 1], ["human_id", 2], ["human_id", 3]]
```

For `@dog.yard`, Rails first loads the associated `home` ID, and then uses
that ID to load `yards`:

```sql
SELECT "home"."id" FROM "homes" WHERE "homes"."dog_id" = ? [["dog_id", 1]]
SELECT "yards".* FROM "yards" WHERE "yards"."home_id" = ? [["home_id", 1]]
```

There are some tradeoffs to be aware of with this option:

1. There may be performance implications because Rails performs two or more
   queries, depending on the association, rather than one join. If the query for
   `humans` returns many IDs, the query for `treats` may send a large `IN`
   list.
2. Since Rails is no longer performing a join, a query with an order or limit
   is sorted in-memory because an order from one table cannot be applied to
   another table.
3. This setting must be added to all associations where you want joining to be
   disabled. Rails can't guess this for you because association loading is
   lazy. To load `treats` in `@dog.treats`, Rails already needs to know what
   SQL should be generated.

## Schema Caching

Schema caching stores a snapshot of database table and column metadata. Rails
uses this information for features like attribute type casting, query generation,
and dynamically defining model attributes. Without schema caching, Rails may
need to query the database for schema information each time a connection is
established. By loading this metadata from the cache instead, applications can
reduce unnecessary database queries and improve boot and connection performance.

In a multiple database application, each database should use its own schema
cache file. By default, the primary database uses `db/schema_cache.yml`, and
other databases use `db/[DATABASE_CONFIGURATION_NAME]_schema_cache.yml`. For
example, the `animals` database uses `db/animals_schema_cache.yml`.

You can configure the schema cache path explicitly with `schema_cache_path`:

```yaml#4,7
production:
  primary:
    database: my_primary_database
    schema_cache_path: db/schema_cache.yml
  animals:
    database: my_animals_database
    schema_cache_path: db/animals_schema_cache.yml
```

To load schema cache files lazily as database connections are established, set
`config.active_record.lazily_load_schema_cache = true` in your application
configuration:

```ruby
config.active_record.lazily_load_schema_cache = true
```

You can generate schema cache files with:

```bash
$ bin/rails db:schema:cache:dump
```

For multiple databases, this command dumps a schema cache for each managed
database configuration. Each database needs its own cache file because each
database can have different tables, columns, and metadata.

You can read more about schema management in the
[Command Line guide](command_line.html#schema-management).

## Caveats and Operational Considerations

Multiple database applications have a few important limitations and production
considerations.

### Connection Pools

Each database configuration can have its own connection pool. Roles, replicas,
and shards can increase the total number of database connections your
application may open. Make sure the pool sizes in `config/database.yml` match
your web server and job worker concurrency, and that your database servers can
handle the total number of connections.

### Load Balancing Replicas

Rails does not automatically load balance reads across multiple replicas. If
your application needs replica load balancing, handle it in your database
infrastructure or with application-specific connection logic.

### Transactions Across Databases

Rails does not provide distributed transactions across database clusters. A
transaction is scoped to one database connection. If a workflow writes to
multiple databases, design it so it can tolerate partial failure, retry safely,
or reconcile data later.

### Foreign Keys Across Databases

Database-level foreign keys generally cannot span separate database clusters.
Keep data that requires strict database-level integrity in the same database
when possible, or enforce cross-database consistency in your application.
