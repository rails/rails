## Rails 7.1.3 (January 16, 2024) ##

*   Fix Migrations with versions older than 7.1 validating options given to
    `add_reference`.

    *Hartley McGuire*

*   Ensure `reload` sets correct owner for each association.

    *Dmytro Savochkin*

*   Fix view runtime for controllers with async queries.

    *fatkodima*

*   Fix `load_async` to work with query cache.

    *fatkodima*

*   Fix polymorphic `belongs_to` to correctly use parent's `query_constraints`.

    *fatkodima*

*   Fix `Preloader` to not generate a query for already loaded association with `query_constraints`.

    *fatkodima*

*   Fix multi-database polymorphic preloading with equivalent table names.

    When preloading polymorphic associations, if two models pointed to two
    tables with the same name but located in different databases, the
    preloader would only load one.

    *Ari Summer*

*   Fix `encrypted_attribute?` to take into account context properties passed to `encrypts`.

    *Maxime Réty*

*   Fix `find_by` to work correctly in presence of composite primary keys.

    *fatkodima*

*   Fix async queries sometimes returning a raw result if they hit the query cache.

    `ShipPart.async_count` could return a raw integer rather than a Promise
    if it found the result in the query cache.

    *fatkodima*

*   Fix `Relation#transaction` to not apply a default scope.

    The method was incorrectly setting a default scope around its block:

    ```ruby
    Post.where(published: true).transaction do
      Post.count # SELECT COUNT(*) FROM posts WHERE published = FALSE;
    end
    ```

    *Jean Boussier*

*   Fix calling `async_pluck` on a `none` relation.

    `Model.none.async_pluck(:id)` was returning a naked value
    instead of a promise.

    *Jean Boussier*

*   Fix calling `load_async` on a `none` relation.

    `Model.none.load_async` was returning a broken result.

    *Lucas Mazza*

*   TrilogyAdapter: ignore `host` if `socket` parameter is set.

    This allows to configure a connection on a UNIX socket via DATABASE_URL:

    ```
    DATABASE_URL=trilogy://does-not-matter/my_db_production?socket=/var/run/mysql.sock
    ```

    *Jean Boussier*

*   Fix `has_secure_token` calls the setter method on initialize.

    *Abeid Ahmed*

*   Allow using `object_id` as a database column name.
    It was available before rails 7.1 and may be used as a part of polymorphic relationship to `object` where `object` can be any other database record.

    *Mikhail Doronin*

*   Fix `rails db:create:all` to not touch databases before they are created.

    *fatkodima*


## Rails 7.1.2 (November 10, 2023) ##

*   Fix renaming primary key index when renaming a table with a UUID primary key
    in PostgreSQL.

    *fatkodima*

*   Fix `where(field: values)` queries when `field` is a serialized attribute
    (for example, when `field` uses `ActiveRecord::Base.serialize` or is a JSON
    column).

    *João Alves*

*   Prevent marking broken connections as verified.

    *Daniel Colson*

*   Don't mark Float::INFINITY as changed when reassigning it

    When saving a record with a float infinite value, it shouldn't mark as changed

    *Maicol Bentancor*

*   `ActiveRecord::Base.table_name` now returns `nil` instead of raising
    "undefined method `abstract_class?` for Object:Class".

    *a5-stable*

*   Fix upserting for custom `:on_duplicate` and `:unique_by` consisting of all
    inserts keys.

    *fatkodima*

*   Fixed an [issue](https://github.com/rails/rails/issues/49809) where saving a
    record could innappropriately `dup` its attributes.

    *Jonathan Hefner*

*   Dump schema only for a specific db for rollback/up/down tasks for multiple dbs.

    *fatkodima*

*   Fix `NoMethodError` when casting a PostgreSQL `money` value that uses a
    comma as its radix point and has no leading currency symbol.  For example,
    when casting `"3,50"`.

    *Andreas Reischuck* and *Jonathan Hefner*

*   Re-enable support for using `enum` with non-column-backed attributes.
    Non-column-backed attributes must be previously declared with an explicit
    type. For example:

      ```ruby
      class Post < ActiveRecord::Base
        attribute :topic, :string
        enum topic: %i[science tech engineering math]
      end
      ```

    *Jonathan Hefner*

*   Raise on `foreign_key:` being passed as an array in associations

    *Nikita Vasilevsky*

*   Return back maximum allowed PostgreSQL table name to 63 characters.

    *fatkodima*

*   Fix detecting `IDENTITY` columns for PostgreSQL < 10.

    *fatkodima*


## Rails 7.1.1 (October 11, 2023) ##

*   Fix auto populating IDENTITY columns for PostgreSQL.

    *fatkodima*

*   Fix "ArgumentError: wrong number of arguments (given 3, expected 2)" when
    down migrating `rename_table` in older migrations.

    *fatkodima*

*   Do not require the Action Text, Active Storage and Action Mailbox tables
    to be present when running when running test on CI.

    *Rafael Mendonça França*


## Rails 7.1.0 (October 05, 2023) ##

*   No changes.


## Rails 7.1.0.rc2 (October 01, 2023) ##

*   Remove -shm and -wal SQLite files when `rails db:drop` is run.

    *Niklas Häusele*

*   Revert the change to raise an `ArgumentError` when `#accepts_nested_attributes_for` is declared more than once for
    an association in the same class.

    The reverted behavior broke the case where the `#accepts_nested_attributes_for` was defined in a concern and
    where overridden in the class that included the concern.

    *Rafael Mendonça França*


## Rails 7.1.0.rc1 (September 27, 2023) ##

*   Better naming for unique constraints support.

    Naming unique keys leads to misunderstanding it's a short-hand of unique indexes.
    Just naming it unique constraints is not misleading.

    In Rails 7.1.0.beta1 or before:

    ```ruby
    add_unique_key :sections, [:position], deferrable: :deferred, name: "unique_section_position"
    remove_unique_key :sections, name: "unique_section_position"
    ```

    Now:

    ```ruby
    add_unique_constraint :sections, [:position], deferrable: :deferred, name: "unique_section_position"
    remove_unique_constraint :sections, name: "unique_section_position"
    ```

    *Ryuta Kamizono*

*   Fix duplicate quoting for check constraint expressions in schema dump when using MySQL

    A check constraint with an expression, that already contains quotes, lead to an invalid schema
    dump with the mysql2 adapter.

    Fixes #42424.

    *Felix Tscheulin*

*   Performance tune the SQLite3 adapter connection configuration

    For Rails applications, the Write-Ahead-Log in normal syncing mode with a capped journal size, a healthy shared memory buffer and a shared cache will perform, on average, 2× better.

    *Stephen Margheim*

*   Allow SQLite3 `busy_handler` to be configured with simple max number of `retries`

    Retrying busy connections without delay is a preferred practice for performance-sensitive applications. Add support for a `database.yml` `retries` integer, which is used in a simple `busy_handler` function to retry busy connections without exponential backoff up to the max number of `retries`.

    *Stephen Margheim*

*   The SQLite3 adapter now supports `supports_insert_returning?`

    Implementing the full `supports_insert_returning?` contract means the SQLite3 adapter supports auto-populated columns (#48241) as well as custom primary keys.

    *Stephen Margheim*

*   Ensure the SQLite3 adapter handles default functions with the `||` concatenation operator

    Previously, this default function would produce the static string `"'Ruby ' || 'on ' || 'Rails'"`.
    Now, the adapter will appropriately receive and use `"Ruby on Rails"`.

    ```ruby
    change_column_default "test_models", "ruby_on_rails", -> { "('Ruby ' || 'on ' || 'Rails')" }
    ```

    *Stephen Margheim*

*   Dump PostgreSQL schemas as part of the schema dump.

    *Lachlan Sylvester*


## Rails 7.1.0.beta1 (September 13, 2023) ##

*   Encryption now supports `support_unencrypted_data` being set per-attribute.

    You can now opt out of `support_unencrypted_data` on a specific encrypted attribute.
    This only has an effect if `ActiveRecord::Encryption.config.support_unencrypted_data == true`.

    ```ruby
    class User < ActiveRecord::Base
      encrypts :name, deterministic: true, support_unencrypted_data: false
      encrypts :email, deterministic: true
    end
    ```

    *Alex Ghiculescu*

*   Add instrumentation for Active Record transactions

    Allows subscribing to transaction events for tracking/instrumentation. The event payload contains the connection and the outcome (commit, rollback, restart, incomplete), as well as timing details.

    ```ruby
    ActiveSupport::Notifications.subscribe("transaction.active_record") do |event|
      puts "Transaction event occurred!"
      connection = event.payload[:connection]
      puts "Connection: #{connection.inspect}"
    end
    ```

    *Daniel Colson*, *Ian Candy*

*   Support composite foreign keys via migration helpers.

    ```ruby
    # Assuming "carts" table has "(shop_id, user_id)" as a primary key.

    add_foreign_key(:orders, :carts, primary_key: [:shop_id, :user_id])

    remove_foreign_key(:orders, :carts, primary_key: [:shop_id, :user_id])
    foreign_key_exists?(:orders, :carts, primary_key: [:shop_id, :user_id])
    ```

    *fatkodima*

*   Adds support for `if_not_exists` when adding a check constraint.

    ```ruby
    add_check_constraint :posts, "post_type IN ('blog', 'comment', 'share')", if_not_exists: true
    ```

    *Cody Cutrer*

*   Raise an `ArgumentError` when `#accepts_nested_attributes_for` is declared more than once for an association in
    the same class. Previously, the last declaration would silently override the previous one. Overriding in a subclass
    is still allowed.

    *Joshua Young*

*   Deprecate `rewhere` argument on `#merge`.

    The `rewhere` argument on `#merge`is deprecated without replacement and
    will be removed in Rails 7.2.

    *Adam Hess*

*   Deprecate aliasing non-attributes with `alias_attribute`.

    *Ian Candy*

*   Fix unscope is not working in specific case

    Before:
    ```ruby
    Post.where(id: 1...3).unscope(where: :id).to_sql # "SELECT `posts`.* FROM `posts` WHERE `posts`.`id` >= 1 AND `posts`.`id` < 3"

    ```

    After:
    ```ruby
    Post.where(id: 1...3).unscope(where: :id).to_sql # "SELECT `posts`.* FROM `posts`"
    ```

    Fixes #48094.

    *Kazuya Hatanaka*

*   Change `has_secure_token` default to `on: :initialize`

    Change the new default value from `on: :create` to `on: :initialize`

    Can be controlled by the `config.active_record.generate_secure_token_on`
    configuration:

    ```ruby
    config.active_record.generate_secure_token_on = :create
    ```

    *Sean Doyle*

*   Fix `change_column` not setting `precision: 6` on `datetime` columns when
    using 7.0+ Migrations and SQLite.

    *Hartley McGuire*

*   Support composite identifiers in `to_key`

    `to_key` avoids wrapping `#id` value into an `Array` if `#id` already an array

    *Nikita Vasilevsky*

*   Add validation option for `enum`

    ```ruby
    class Contract < ApplicationRecord
      enum :status, %w[in_progress completed], validate: true
    end
    Contract.new(status: "unknown").valid? # => false
    Contract.new(status: nil).valid? # => false
    Contract.new(status: "completed").valid? # => true

    class Contract < ApplicationRecord
      enum :status, %w[in_progress completed], validate: { allow_nil: true }
    end
    Contract.new(status: "unknown").valid? # => false
    Contract.new(status: nil).valid? # => true
    Contract.new(status: "completed").valid? # => true
    ```

    *Edem Topuzov*, *Ryuta Kamizono*

*   Allow batching methods to use already loaded relation if available

    Calling batch methods on already loaded relations will use the records previously loaded instead of retrieving
    them from the database again.

    *Adam Hess*

*   Deprecate `read_attribute(:id)` returning the primary key if the primary key is not `:id`.

    Starting in Rails 7.2, `read_attribute(:id)` will return the value of the id column, regardless of the model's
    primary key. To retrieve the value of the primary key, use `#id` instead. `read_attribute(:id)` for composite
    primary key models will now return the value of the id column.

    *Adrianna Chang*

*   Fix `change_table` setting datetime precision for 6.1 Migrations

    *Hartley McGuire*

*   Fix change_column setting datetime precision for 6.1 Migrations

    *Hartley McGuire*

*   Add `ActiveRecord::Base#id_value` alias to access the raw value of a record's id column.

    This alias is only provided for models that declare an `:id` column.

    *Adrianna Chang*

*   Fix previous change tracking for `ActiveRecord::Store` when using a column with JSON structured database type

    Before, the methods to access the changes made during the last save `#saved_change_to_key?`, `#saved_change_to_key`, and `#key_before_last_save` did not work if the store was defined as a `store_accessor` on a column with a JSON structured database type

    *Robert DiMartino*

*   Fully support `NULLS [NOT] DISTINCT` for PostgreSQL 15+ indexes.

    Previous work was done to allow the index to be created in a migration, but it was not
    supported in schema.rb. Additionally, the matching for `NULLS [NOT] DISTINCT` was not
    in the correct order, which could have resulted in inconsistent schema detection.

    *Gregory Jones*

*   Allow escaping of literal colon characters in `sanitize_sql_*` methods when named bind variables are used

    *Justin Bull*

*   Fix `#previously_new_record?` to return true for destroyed records.

    Before, if a record was created and then destroyed, `#previously_new_record?` would return true.
    Now, any UPDATE or DELETE to a record is considered a change, and will result in `#previously_new_record?`
    returning false.

    *Adrianna Chang*

*   Specify callback in `has_secure_token`

    ```ruby
    class User < ApplicationRecord
      has_secure_token on: :initialize
    end

    User.new.token # => "abc123...."
    ```

    *Sean Doyle*

*   Fix incrementation of in memory counter caches when associations overlap

    When two associations had a similarly named counter cache column, Active Record
    could sometime increment the wrong one.

    *Jacopo Beschi*, *Jean Boussier*

*   Don't show secrets for Active Record's `Cipher::Aes256Gcm#inspect`.

    Before:

    ```ruby
    ActiveRecord::Encryption::Cipher::Aes256Gcm.new(secret).inspect
    "#<ActiveRecord::Encryption::Cipher::Aes256Gcm:0x0000000104888038 ... @secret=\"\\xAF\\bFh]LV}q\\nl\\xB2U\\xB3 ... >"
    ```

    After:

    ```ruby
    ActiveRecord::Encryption::Cipher::Aes256Gcm(secret).inspect
    "#<ActiveRecord::Encryption::Cipher::Aes256Gcm:0x0000000104888038>"
    ```

    *Petrik de Heus*

*   Bring back the historical behavior of committing transaction on non-local return.

    ```ruby
    Model.transaction do
      model.save
      return
      other_model.save # not executed
    end
    ```

    Historically only raised errors would trigger a rollback, but in Ruby `2.3`, the `timeout` library
    started using `throw` to interrupt execution which had the adverse effect of committing open transactions.

    To solve this, in Active Record 6.1 the behavior was changed to instead rollback the transaction as it was safer
    than to potentially commit an incomplete transaction.

    Using `return`, `break` or `throw` inside a `transaction` block was essentially deprecated from Rails 6.1 onwards.

    However with the release of `timeout 0.4.0`, `Timeout.timeout` now raises an error again, and Active Record is able
    to return to its original, less surprising, behavior.

    This historical behavior can now be opt-ed in via:

    ```
    Rails.application.config.active_record.commit_transaction_on_non_local_return = true
    ```

    And is the default for new applications created in Rails 7.1.

    *Jean Boussier*

*   Deprecate `name` argument on `#remove_connection`.

    The `name` argument is deprecated on `#remove_connection` without replacement. `#remove_connection` should be called directly on the class that established the connection.

    *Eileen M. Uchitelle*

*   Fix has_one through singular building with inverse.

    Allows building of records from an association with a has_one through a
    singular association with inverse. For belongs_to through associations,
    linking the foreign key to the primary key model isn't needed.
    For has_one, we cannot build records due to the association not being mutable.

    *Gannon McGibbon*

*   Disable database prepared statements when query logs are enabled

    Prepared Statements and Query Logs are incompatible features due to query logs making every query unique.

    *zzak, Jean Boussier*

*   Support decrypting data encrypted non-deterministically with a SHA1 hash digest.

    This adds a new Active Record encryption option to support decrypting data encrypted
    non-deterministically with a SHA1 hash digest:

    ```
    Rails.application.config.active_record.encryption.support_sha1_for_non_deterministic_encryption = true
    ```

    The new option addresses a problem when upgrading from 7.0 to 7.1. Due to a bug in how Active Record
    Encryption was getting initialized, the key provider used for non-deterministic encryption were using
    SHA-1 as its digest class, instead of the one configured globally by Rails via
    `Rails.application.config.active_support.key_generator_hash_digest_class`.

    *Cadu Ribeiro and Jorge Manrubia*

*   Added PostgreSQL migration commands for enum rename, add value, and rename value.

    `rename_enum` and `rename_enum_value` are reversible. Due to Postgres
    limitation, `add_enum_value` is not reversible since you cannot delete enum
    values. As an alternative you should drop and recreate the enum entirely.

    ```ruby
    rename_enum :article_status, to: :article_state
    ```

    ```ruby
    add_enum_value :article_state, "archived" # will be at the end of existing values
    add_enum_value :article_state, "in review", before: "published"
    add_enum_value :article_state, "approved", after: "in review"
    ```

    ```ruby
    rename_enum_value :article_state, from: "archived", to: "deleted"
    ```

    *Ray Faddis*

*   Allow composite primary key to be derived from schema

    Booting an application with a schema that contains composite primary keys
    will not issue warning and won't `nil`ify the `ActiveRecord::Base#primary_key` value anymore.

    Given a `travel_routes` table definition and a `TravelRoute` model like:
    ```ruby
    create_table :travel_routes, primary_key: [:origin, :destination], force: true do |t|
      t.string :origin
      t.string :destination
    end

    class TravelRoute < ActiveRecord::Base; end
    ```
    The `TravelRoute.primary_key` value will be automatically derived to `["origin", "destination"]`

    *Nikita Vasilevsky*

*   Include the `connection_pool` with exceptions raised from an adapter.

    The `connection_pool` provides added context such as the connection used
    that led to the exception as well as which role and shard.

    *Luan Vieira*

*   Support multiple column ordering for `find_each`, `find_in_batches` and `in_batches`.

    When find_each/find_in_batches/in_batches are performed on a table with composite primary keys, ascending or descending order can be selected for each key.

    ```ruby
    Person.find_each(order: [:desc, :asc]) do |person|
      person.party_all_night!
    end
    ```

    *Takuya Kurimoto*

*   Fix where on association with has_one/has_many polymorphic relations.

    Before:
    ```ruby
    Treasure.where(price_estimates: PriceEstimate.all)
    #=> SELECT (...) WHERE "treasures"."id" IN (SELECT "price_estimates"."estimate_of_id" FROM "price_estimates")
    ```

    Later:
    ```ruby
    Treasure.where(price_estimates: PriceEstimate.all)
    #=> SELECT (...) WHERE "treasures"."id" IN (SELECT "price_estimates"."estimate_of_id" FROM "price_estimates" WHERE "price_estimates"."estimate_of_type" = 'Treasure')
    ```

    *Lázaro Nixon*

*   Assign auto populated columns on Active Record record creation.

    Changes record creation logic to allow for the `auto_increment` column to be assigned
    immediately after creation regardless of it's relation to the model's primary key.

    The PostgreSQL adapter benefits the most from the change allowing for any number of auto-populated
    columns to be assigned on the object immediately after row insertion utilizing the `RETURNING` statement.

    *Nikita Vasilevsky*

*   Use the first key in the `shards` hash from `connected_to` for the `default_shard`.

    Some applications may not want to use `:default` as a shard name in their connection model. Unfortunately Active Record expects there to be a `:default` shard because it must assume a shard to get the right connection from the pool manager. Rather than force applications to manually set this, `connects_to` can infer the default shard name from the hash of shards and will now assume that the first shard is your default.

    For example if your model looked like this:

    ```ruby
    class ShardRecord < ApplicationRecord
      self.abstract_class = true

      connects_to shards: {
        shard_one: { writing: :shard_one },
        shard_two: { writing: :shard_two }
      }
    ```

    Then the `default_shard` for this class would be set to `shard_one`.

    Fixes: #45390

    *Eileen M. Uchitelle*

*   Fix mutation detection for serialized attributes backed by binary columns.

    *Jean Boussier*

*   Add `ActiveRecord.disconnect_all!` method to immediately close all connections from all pools.

    *Jean Boussier*

*   Discard connections which may have been left in a transaction.

    There are cases where, due to an error, `within_new_transaction` may unexpectedly leave a connection in an open transaction. In these cases the connection may be reused, and the following may occur:
    - Writes appear to fail when they actually succeed.
    - Writes appear to succeed when they actually fail.
    - Reads return stale or uncommitted data.

    Previously, the following case was detected:
    - An error is encountered during the transaction, then another error is encountered while attempting to roll it back.

    Now, the following additional cases are detected:
    - An error is encountered just after successfully beginning a transaction.
    - An error is encountered while committing a transaction, then another error is encountered while attempting to roll it back.
    - An error is encountered while rolling back a transaction.

    *Nick Dower*

*   Active Record query cache now evicts least recently used entries

    By default it only keeps the `100` most recently used queries.

    The cache size can be configured via `database.yml`

    ```yaml
    development:
      adapter: mysql2
      query_cache: 200
    ```

    It can also be entirely disabled:

    ```yaml
    development:
      adapter: mysql2
      query_cache: false
    ```

    *Jean Boussier*

*   Deprecate `check_pending!` in favor of `check_all_pending!`.

    `check_pending!` will only check for pending migrations on the current database connection or the one passed in. This has been deprecated in favor of `check_all_pending!` which will find all pending migrations for the database configurations in a given environment.

    *Eileen M. Uchitelle*

*   Make `increment_counter`/`decrement_counter` accept an amount argument

    ```ruby
    Post.increment_counter(:comments_count, 5, by: 3)
    ```

    *fatkodima*

*   Add support for `Array#intersect?` to `ActiveRecord::Relation`.

    `Array#intersect?` is only available on Ruby 3.1 or later.

    This allows the Rubocop `Style/ArrayIntersect` cop to work with `ActiveRecord::Relation` objects.

    *John Harry Kelly*

*   The deferrable foreign key can be passed to `t.references`.

    *Hiroyuki Ishii*

*   Deprecate `deferrable: true` option of `add_foreign_key`.

    `deferrable: true` is deprecated in favor of `deferrable: :immediate`, and
    will be removed in Rails 7.2.

    Because `deferrable: true` and `deferrable: :deferred` are hard to understand.
    Both true and :deferred are truthy values.
    This behavior is the same as the deferrable option of the add_unique_key method, added in #46192.

    *Hiroyuki Ishii*

*   `AbstractAdapter#execute` and `#exec_query` now clear the query cache

    If you need to perform a read only SQL query without clearing the query
    cache, use `AbstractAdapter#select_all`.

    *Jean Boussier*

*   Make `.joins` / `.left_outer_joins` work with CTEs.

    For example:

    ```ruby
    Post
     .with(commented_posts: Comment.select(:post_id).distinct)
     .joins(:commented_posts)
    #=> WITH (...) SELECT ... INNER JOIN commented_posts on posts.id = commented_posts.post_id
    ```

    *Vladimir Dementyev*

*   Add a load hook for `ActiveRecord::ConnectionAdapters::Mysql2Adapter`
    (named `active_record_mysql2adapter`) to allow for overriding aspects of the
    `ActiveRecord::ConnectionAdapters::Mysql2Adapter` class. This makes `Mysql2Adapter`
    consistent with `PostgreSQLAdapter` and `SQLite3Adapter` that already have load hooks.

    *fatkodima*

*   Introduce adapter for Trilogy database client

    Trilogy is a MySQL-compatible database client. Rails applications can use Trilogy
    by configuring their `config/database.yml`:

    ```yaml
    development:
    adapter: trilogy
    database: blog_development
    pool: 5
    ```

    Or by using the `DATABASE_URL` environment variable:

    ```ruby
    ENV['DATABASE_URL'] # => "trilogy://localhost/blog_development?pool=5"
    ```

    *Adrianna Chang*

*   `after_commit` callbacks defined on models now execute in the correct order.

    ```ruby
    class User < ActiveRecord::Base
      after_commit { puts("this gets called first") }
      after_commit { puts("this gets called second") }
    end
    ```

    Previously, the callbacks executed in the reverse order. To opt in to the new behaviour:

    ```ruby
    config.active_record.run_after_transaction_callbacks_in_order_defined = true
    ```

    This is the default for new apps.

    *Alex Ghiculescu*

*   Infer `foreign_key` when `inverse_of` is present on `has_one` and `has_many` associations.

    ```ruby
    has_many :citations, foreign_key: "book1_id", inverse_of: :book
    ```

    can be simplified to

    ```ruby
    has_many :citations, inverse_of: :book
    ```

    and the foreign_key will be read from the corresponding `belongs_to` association.

    *Daniel Whitney*

*   Limit max length of auto generated index names

    Auto generated index names are now limited to 62 bytes, which fits within
    the default index name length limits for MySQL, Postgres and SQLite.

    Any index name over the limit will fallback to the new short format.

    Before (too long):
    ```
    index_testings_on_foo_and_bar_and_first_name_and_last_name_and_administrator
    ```

    After (short format):
    ```
    idx_on_foo_bar_first_name_last_name_administrator_5939248142
    ```

    The short format includes a hash to ensure the name is unique database-wide.

    *Mike Coutermarsh*

*   Introduce a more stable and optimized Marshal serializer for Active Record models.

    Can be enabled with `config.active_record.marshalling_format_version = 7.1`.

    *Jean Boussier*

*   Allow specifying where clauses with column-tuple syntax.

    Querying through `#where` now accepts a new tuple-syntax which accepts, as
    a key, an array of columns and, as a value, an array of corresponding tuples.
    The key specifies a list of columns, while the value is an array of
    ordered-tuples that conform to the column list.

    For instance:

    ```ruby
    # Cpk::Book => Cpk::Book(author_id: integer, number: integer, title: string, revision: integer)
    # Cpk::Book.primary_key => ["author_id", "number"]

    book = Cpk::Book.create!(author_id: 1, number: 1)
    Cpk::Book.where(Cpk::Book.primary_key => [[1, 2]]) # => [book]

    # Topic => Topic(id: integer, title: string, author_name: string...)

    Topic.where([:title, :author_name] => [["The Alchemist", "Paulo Coelho"], ["Harry Potter", "J.K Rowling"]])
    ```

    *Paarth Madan*

*   Allow warning codes to be ignore when reporting SQL warnings.

    Active Record config that can ignore warning codes

    ```ruby
    # Configure allowlist of warnings that should always be ignored
    config.active_record.db_warnings_ignore = [
      "1062", # MySQL Error 1062: Duplicate entry
    ]
    ```

    This is supported for the MySQL and PostgreSQL adapters.

    *Nick Borromeo*

*   Introduce `:active_record_fixtures` lazy load hook.

    Hooks defined with this name will be run whenever `TestFixtures` is included
    in a class.

    ```ruby
    ActiveSupport.on_load(:active_record_fixtures) do
      self.fixture_paths << "test/fixtures"
    end

    klass = Class.new
    klass.include(ActiveRecord::TestFixtures)

    klass.fixture_paths # => ["test/fixtures"]
    ```

    *Andrew Novoselac*

*   Introduce `TestFixtures#fixture_paths`.

    Multiple fixture paths can now be specified using the `#fixture_paths` accessor.
    Apps will continue to have `test/fixtures` as their one fixture path by default,
    but additional fixture paths can be specified.

    ```ruby
    ActiveSupport::TestCase.fixture_paths << "component1/test/fixtures"
    ActiveSupport::TestCase.fixture_paths << "component2/test/fixtures"
    ```

    `TestFixtures#fixture_path` is now deprecated.

    *Andrew Novoselac*

*   Adds support for deferrable exclude constraints in PostgreSQL.

    By default, exclude constraints in PostgreSQL are checked after each statement.
    This works for most use cases, but becomes a major limitation when replacing
    records with overlapping ranges by using multiple statements.

    ```ruby
    exclusion_constraint :users, "daterange(valid_from, valid_to) WITH &&", deferrable: :immediate
    ```

    Passing `deferrable: :immediate` checks constraint after each statement,
    but allows manually deferring the check using `SET CONSTRAINTS ALL DEFERRED`
    within a transaction. This will cause the excludes to be checked after the transaction.

    It's also possible to change the default behavior from an immediate check
    (after the statement), to a deferred check (after the transaction):

    ```ruby
    exclusion_constraint :users, "daterange(valid_from, valid_to) WITH &&", deferrable: :deferred
    ```

    *Hiroyuki Ishii*

*   Respect `foreign_type` option to `delegated_type` for `{role}_class` method.

    Usage of `delegated_type` with non-conventional `{role}_type` column names can now be specified with `foreign_type` option.
    This option is the same as `foreign_type` as forwarded to the underlying `belongs_to` association that `delegated_type` wraps.

    *Jason Karns*

*   Add support for unique constraints (PostgreSQL-only).

    ```ruby
    add_unique_key :sections, [:position], deferrable: :deferred, name: "unique_section_position"
    remove_unique_key :sections, name: "unique_section_position"
    ```

    See PostgreSQL's [Unique Constraints](https://www.postgresql.org/docs/current/ddl-constraints.html#DDL-CONSTRAINTS-UNIQUE-CONSTRAINTS) documentation for more on unique constraints.

    By default, unique constraints in PostgreSQL are checked after each statement.
    This works for most use cases, but becomes a major limitation when replacing
    records with unique column by using multiple statements.

    An example of swapping unique columns between records.

    ```ruby
    # position is unique column
    old_item = Item.create!(position: 1)
    new_item = Item.create!(position: 2)

    Item.transaction do
      old_item.update!(position: 2)
      new_item.update!(position: 1)
    end
    ```

    Using the default behavior, the transaction would fail when executing the
    first `UPDATE` statement.

    By passing the `:deferrable` option to the `add_unique_key` statement in
    migrations, it's possible to defer this check.

    ```ruby
    add_unique_key :items, [:position], deferrable: :immediate
    ```

    Passing `deferrable: :immediate` does not change the behaviour of the previous example,
    but allows manually deferring the check using `SET CONSTRAINTS ALL DEFERRED` within a transaction.
    This will cause the unique constraints to be checked after the transaction.

    It's also possible to adjust the default behavior from an immediate
    check (after the statement), to a deferred check (after the transaction):

    ```ruby
    add_unique_key :items, [:position], deferrable: :deferred
    ```

    If you want to change an existing unique index to deferrable, you can use :using_index
    to create deferrable unique constraints.

    ```ruby
    add_unique_key :items, deferrable: :deferred, using_index: "index_items_on_position"
    ```

    *Hiroyuki Ishii*

*   Remove deprecated `Tasks::DatabaseTasks.schema_file_type`.

    *Rafael Mendonça França*

*   Remove deprecated `config.active_record.partial_writes`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveRecord::Base` config accessors.

    *Rafael Mendonça França*

*   Remove the `:include_replicas` argument from `configs_for`. Use `:include_hidden` argument instead.

    *Eileen M. Uchitelle*

*   Allow applications to lookup a config via a custom hash key.

    If you have registered a custom config or want to find configs where the hash matches a specific key, now you can pass `config_key` to `configs_for`. For example if you have a `db_config` with the key `vitess` you can look up a database configuration hash by  matching that key.

    ```ruby
    ActiveRecord::Base.configurations.configs_for(env_name: "development", name: "primary", config_key: :vitess)
    ActiveRecord::Base.configurations.configs_for(env_name: "development", config_key: :vitess)
    ```

    *Eileen M. Uchitelle*

*   Allow applications to register a custom database configuration handler.

    Adds a mechanism for registering a custom handler for cases where you want database configurations to respond to custom methods. This is useful for non-Rails database adapters or tools like Vitess that you may want to configure differently from a standard `HashConfig` or `UrlConfig`.

    Given the following database YAML we want the `animals` db to create a `CustomConfig` object instead while the `primary` database will be a `UrlConfig`:

    ```yaml
    development:
      primary:
        url: postgres://localhost/primary
      animals:
        url: postgres://localhost/animals
        custom_config:
          sharded: 1
    ```

    To register a custom handler first make a class that has your custom methods:

    ```ruby
    class CustomConfig < ActiveRecord::DatabaseConfigurations::UrlConfig
      def sharded?
        custom_config.fetch("sharded", false)
      end

      private
        def custom_config
          configuration_hash.fetch(:custom_config)
        end
    end
    ```

    Then register the config in an initializer:

    ```ruby
    ActiveRecord::DatabaseConfigurations.register_db_config_handler do |env_name, name, url, config|
      next unless config.key?(:custom_config)
      CustomConfig.new(env_name, name, url, config)
    end
    ```

    When the application is booted, configuration hashes with the `:custom_config` key will be `CustomConfig` objects and respond to `sharded?`. Applications must handle the condition in which Active Record should use their custom handler.

    *Eileen M. Uchitelle and John Crepezzi*

*   `ActiveRecord::Base.serialize` no longer uses YAML by default.

    YAML isn't particularly performant and can lead to security issues
    if not used carefully.

    Unfortunately there isn't really any good serializers in Ruby's stdlib
    to replace it.

    The obvious choice would be JSON, which is a fine format for this use case,
    however the JSON serializer in Ruby's stdlib isn't strict enough, as it fallback
    to casting unknown types to strings, which could lead to corrupted data.

    Some third party JSON libraries like `Oj` have a suitable strict mode.

    So it's preferable that users choose a serializer based on their own constraints.

    The original default can be restored by setting `config.active_record.default_column_serializer = YAML`.

    *Jean Boussier*

*   `ActiveRecord::Base.serialize` signature changed.

    Rather than a single positional argument that accepts two possible
    types of values, `serialize` now accepts two distinct keyword arguments.

    Before:

    ```ruby
    serialize :content, JSON
    serialize :backtrace, Array
    ```

    After:

    ```ruby
    serialize :content, coder: JSON
    serialize :backtrace, type: Array
    ```

    *Jean Boussier*

*   YAML columns use `YAML.safe_dump` if available.

    As of `psych 5.1.0`, `YAML.safe_dump` can now apply the same permitted
    types restrictions than `YAML.safe_load`.

    It's preferable to ensure the payload only use allowed types when we first
    try to serialize it, otherwise you may end up with invalid records in the
    database.

    *Jean Boussier*

*   `ActiveRecord::QueryLogs` better handle broken encoding.

    It's not uncommon when building queries with BLOB fields to contain
    binary data. Unless the call carefully encode the string in ASCII-8BIT
    it generally end up being encoded in `UTF-8`, and `QueryLogs` would
    end up failing on it.

    `ActiveRecord::QueryLogs` no longer depend on the query to be properly encoded.

    *Jean Boussier*

*   Fix a bug where `ActiveRecord::Generators::ModelGenerator` would not respect create_table_migration template overrides.

    ```
    rails g model create_books title:string content:text
    ```
    will now read from the create_table_migration.rb.tt template in the following locations in order:
    ```
    lib/templates/active_record/model/create_table_migration.rb
    lib/templates/active_record/migration/create_table_migration.rb
    ```

    *Spencer Neste*

*   `ActiveRecord::Relation#explain` now accepts options.

    For databases and adapters which support them (currently PostgreSQL
    and MySQL), options can be passed to `explain` to provide more
    detailed query plan analysis:

    ```ruby
    Customer.where(id: 1).joins(:orders).explain(:analyze, :verbose)
    ```

    *Reid Lynch*

*   Multiple `Arel::Nodes::SqlLiteral` nodes can now be added together to
    form `Arel::Nodes::Fragments` nodes. This allows joining several pieces
    of SQL.

    *Matthew Draper*, *Ole Friis*

*   `ActiveRecord::Base#signed_id` raises if called on a new record.

    Previously it would return an ID that was not usable, since it was based on `id = nil`.

    *Alex Ghiculescu*

*   Allow SQL warnings to be reported.

    Active Record configs can be set to enable SQL warning reporting.

    ```ruby
    # Configure action to take when SQL query produces warning
    config.active_record.db_warnings_action = :raise

    # Configure allowlist of warnings that should always be ignored
    config.active_record.db_warnings_ignore = [
      /Invalid utf8mb4 character string/,
      "An exact warning message",
    ]
    ```

    This is supported for the MySQL and PostgreSQL adapters.

    *Adrianna Chang*, *Paarth Madan*

*   Add `#regroup` query method as a short-hand for `.unscope(:group).group(fields)`

    Example:

    ```ruby
    Post.group(:title).regroup(:author)
    # SELECT `posts`.`*` FROM `posts` GROUP BY `posts`.`author`
    ```

    *Danielius Visockas*

*   PostgreSQL adapter method `enable_extension` now allows parameter to be `[schema_name.]<extension_name>`
    if the extension must be installed on another schema.

    Example: `enable_extension('heroku_ext.hstore')`

    *Leonardo Luarte*

*   Add `:include` option to `add_index`.

    Add support for including non-key columns in indexes for PostgreSQL
    with the `INCLUDE` parameter.

    ```ruby
    add_index(:users, :email, include: [:id, :created_at])
    ```

    will result in:

    ```sql
    CREATE INDEX index_users_on_email USING btree (email) INCLUDE (id, created_at)
    ```

    *Steve Abrams*

*   `ActiveRecord::Relation`’s `#any?`, `#none?`, and `#one?` methods take an optional pattern
    argument, more closely matching their `Enumerable` equivalents.

    *George Claghorn*

*   Add `ActiveRecord::Base.normalizes` for declaring attribute normalizations.

    An attribute normalization is applied when the attribute is assigned or
    updated, and the normalized value will be persisted to the database.  The
    normalization is also applied to the corresponding keyword argument of query
    methods, allowing records to be queried using unnormalized values.

    For example:

      ```ruby
      class User < ActiveRecord::Base
        normalizes :email, with: -> email { email.strip.downcase }
        normalizes :phone, with: -> phone { phone.delete("^0-9").delete_prefix("1") }
      end

      user = User.create(email: " CRUISE-CONTROL@EXAMPLE.COM\n")
      user.email                  # => "cruise-control@example.com"

      user = User.find_by(email: "\tCRUISE-CONTROL@EXAMPLE.COM ")
      user.email                  # => "cruise-control@example.com"
      user.email_before_type_cast # => "cruise-control@example.com"

      User.where(email: "\tCRUISE-CONTROL@EXAMPLE.COM ").count         # => 1
      User.where(["email = ?", "\tCRUISE-CONTROL@EXAMPLE.COM "]).count # => 0

      User.exists?(email: "\tCRUISE-CONTROL@EXAMPLE.COM ")         # => true
      User.exists?(["email = ?", "\tCRUISE-CONTROL@EXAMPLE.COM "]) # => false

      User.normalize_value_for(:phone, "+1 (555) 867-5309") # => "5558675309"
      ```

    *Jonathan Hefner*

*   Hide changes to before_committed! callback behaviour behind flag.

    In #46525, behavior around before_committed! callbacks was changed so that callbacks
    would run on every enrolled record in a transaction, not just the first copy of a record.
    This change in behavior is now controlled by a configuration option,
    `config.active_record.before_committed_on_all_records`. It will be enabled by default on Rails 7.1.

    *Adrianna Chang*

*   The `namespaced_controller` Query Log tag now matches the `controller` format

    For example, a request processed by `NameSpaced::UsersController` will now log as:

    ```
    :controller # "users"
    :namespaced_controller # "name_spaced/users"
    ```

    *Alex Ghiculescu*

*   Return only unique ids from ActiveRecord::Calculations#ids

    Updated ActiveRecord::Calculations#ids to only return the unique ids of the base model
    when using eager_load, preload and includes.

    ```ruby
    Post.find_by(id: 1).comments.count
    # => 5
    Post.includes(:comments).where(id: 1).pluck(:id)
    # => [1, 1, 1, 1, 1]
    Post.includes(:comments).where(id: 1).ids
    # => [1]
    ```

    *Joshua Young*

*   Stop using `LOWER()` for case-insensitive queries on `citext` columns

    Previously, `LOWER()` was added for e.g. uniqueness validations with
    `case_sensitive: false`.
    It wasn't mentioned in the documentation that the index without `LOWER()`
    wouldn't be used in this case.

    *Phil Pirozhkov*

*   Extract `#sync_timezone_changes` method in AbstractMysqlAdapter to enable subclasses
    to sync database timezone changes without overriding `#raw_execute`.

    *Adrianna Chang*, *Paarth Madan*

*   Do not write additional new lines when dumping sql migration versions

    This change updates the `insert_versions_sql` function so that the database insert string containing the current database migration versions does not end with two additional new lines.

    *Misha Schwartz*

*   Fix `composed_of` value freezing and duplication.

    Previously composite values exhibited two confusing behaviors:

    - When reading a compositve value it'd _NOT_ be frozen, allowing it to get out of sync with its underlying database
      columns.
    - When writing a compositve value the argument would be frozen, potentially confusing the caller.

    Currently, composite values instantiated based on database columns are frozen (addressing the first issue) and
    assigned compositve values are duplicated and the duplicate is frozen (addressing the second issue).

    *Greg Navis*

*   Fix redundant updates to the column insensitivity cache

    Fixed redundant queries checking column capability for insensitive
    comparison.

    *Phil Pirozhkov*

*   Allow disabling methods generated by `ActiveRecord.enum`.

    *Alfred Dominic*

*   Avoid validating `belongs_to` association if it has not changed.

    Previously, when updating a record, Active Record will perform an extra query to check for the presence of
    `belongs_to` associations (if the presence is configured to be mandatory), even if that attribute hasn't changed.

    Currently, only `belongs_to`-related columns are checked for presence. It is possible to have orphaned records with
    this approach. To avoid this problem, you need to use a foreign key.

    This behavior can be controlled by configuration:

    ```ruby
    config.active_record.belongs_to_required_validates_foreign_key = false
    ```

    and will be disabled by default with `config.load_defaults 7.1`.

    *fatkodima*

*   `has_one` and `belongs_to` associations now define a `reset_association` method
    on the owner model (where `association` is the name of the association). This
    method unloads the cached associate record, if any, and causes the next access
    to query it from the database.

    *George Claghorn*

*   Allow per attribute setting of YAML permitted classes (safe load) and unsafe load.

    *Carlos Palhares*

*   Add a build persistence method

    Provides a wrapper for `new`, to provide feature parity with `create`s
    ability to create multiple records from an array of hashes, using the
    same notation as the `build` method on associations.

    *Sean Denny*

*   Raise on assignment to readonly attributes

    ```ruby
    class Post < ActiveRecord::Base
      attr_readonly :content
    end
    Post.create!(content: "cannot be updated")
    post.content # "cannot be updated"
    post.content = "something else" # => ActiveRecord::ReadonlyAttributeError
    ```

    Previously, assignment would succeed but silently not write to the database.

    This behavior can be controlled by configuration:

    ```ruby
    config.active_record.raise_on_assign_to_attr_readonly = true
    ```

    and will be enabled by default with `config.load_defaults 7.1`.

    *Alex Ghiculescu*, *Hartley McGuire*

*   Allow unscoping of preload and eager_load associations

    Added the ability to unscope preload and eager_load associations just like
    includes, joins, etc. See ActiveRecord::QueryMethods::VALID_UNSCOPING_VALUES
    for the full list of supported unscopable scopes.

    ```ruby
    query.unscope(:eager_load, :preload).group(:id).select(:id)
    ```

    *David Morehouse*

*   Add automatic filtering of encrypted attributes on inspect

    This feature is enabled by default but can be disabled with

    ```ruby
    config.active_record.encryption.add_to_filter_parameters = false
    ```

    *Hartley McGuire*

*   Clear locking column on #dup

    This change fixes not to duplicate locking_column like id and timestamps.

    ```
    car = Car.create!
    car.touch
    car.lock_version #=> 1
    car.dup.lock_version #=> 0
    ```

    *Shouichi Kamiya*, *Seonggi Yang*, *Ryohei UEDA*

*   Invalidate transaction as early as possible

    After rescuing a `TransactionRollbackError` exception Rails invalidates transactions earlier in the flow
    allowing the framework to skip issuing the `ROLLBACK` statement in more cases.
    Only affects adapters that have `savepoint_errors_invalidate_transactions?` configured as `true`,
    which at this point is only applicable to the `mysql2` adapter.

    *Nikita Vasilevsky*

*   Allow configuring columns list to be used in SQL queries issued by an `ActiveRecord::Base` object

    It is now possible to configure columns list that will be used to build an SQL query clauses when
    updating, deleting or reloading an `ActiveRecord::Base` object

    ```ruby
    class Developer < ActiveRecord::Base
      query_constraints :company_id, :id
    end
    developer = Developer.first.update(name: "Bob")
    # => UPDATE "developers" SET "name" = 'Bob' WHERE "developers"."company_id" = 1 AND "developers"."id" = 1
    ```

    *Nikita Vasilevsky*

*   Adds `validate` to foreign keys and check constraints in schema.rb

    Previously, `schema.rb` would not record if `validate: false` had been used when adding a foreign key or check
    constraint, so restoring a database from the schema could result in foreign keys or check constraints being
    incorrectly validated.

    *Tommy Graves*

*   Adapter `#execute` methods now accept an `allow_retry` option. When set to `true`, the SQL statement will be
    retried, up to the database's configured `connection_retries` value, upon encountering connection-related errors.

    *Adrianna Chang*

*   Only trigger `after_commit :destroy` callbacks when a database row is deleted.

    This prevents `after_commit :destroy` callbacks from being triggered again
    when `destroy` is called multiple times on the same record.

    *Ben Sheldon*

*   Fix `ciphertext_for` for yet-to-be-encrypted values.

    Previously, `ciphertext_for` returned the cleartext of values that had not
    yet been encrypted, such as with an unpersisted record:

      ```ruby
      Post.encrypts :body

      post = Post.create!(body: "Hello")
      post.ciphertext_for(:body)
      # => "{\"p\":\"abc..."

      post.body = "World"
      post.ciphertext_for(:body)
      # => "World"
      ```

    Now, `ciphertext_for` will always return the ciphertext of encrypted
    attributes:

      ```ruby
      Post.encrypts :body

      post = Post.create!(body: "Hello")
      post.ciphertext_for(:body)
      # => "{\"p\":\"abc..."

      post.body = "World"
      post.ciphertext_for(:body)
      # => "{\"p\":\"xyz..."
      ```

    *Jonathan Hefner*

*   Fix a bug where using groups and counts with long table names would return incorrect results.

    *Shota Toguchi*, *Yusaku Ono*

*   Fix encryption of column default values.

    Previously, encrypted attributes that used column default values appeared to
    be encrypted on create, but were not:

      ```ruby
      Book.encrypts :name

      book = Book.create!
      book.name
      # => "<untitled>"
      book.name_before_type_cast
      # => "{\"p\":\"abc..."
      book.reload.name_before_type_cast
      # => "<untitled>"
      ```

    Now, attributes with column default values are encrypted:

      ```ruby
      Book.encrypts :name

      book = Book.create!
      book.name
      # => "<untitled>"
      book.name_before_type_cast
      # => "{\"p\":\"abc..."
      book.reload.name_before_type_cast
      # => "{\"p\":\"abc..."
      ```

    *Jonathan Hefner*

*   Deprecate delegation from `Base` to `connection_handler`.

    Calling `Base.clear_all_connections!`, `Base.clear_active_connections!`, `Base.clear_reloadable_connections!` and `Base.flush_idle_connections!` is deprecated. Please call these methods on the connection handler directly. In future Rails versions, the delegation from `Base` to the `connection_handler` will be removed.

    *Eileen M. Uchitelle*

*   Allow ActiveRecord::QueryMethods#reselect to receive hash values, similar to ActiveRecord::QueryMethods#select

    *Sampat Badhe*

*   Validate options when managing columns and tables in migrations.

    If an invalid option is passed to a migration method like `create_table` and `add_column`, an error will be raised
    instead of the option being silently ignored. Validation of the options will only be applied for new migrations
    that are created.

    *Guo Xiang Tan*, *George Wambold*

*   Update query log tags to use the [SQLCommenter](https://open-telemetry.github.io/opentelemetry-sqlcommenter/) format by default. See [#46179](https://github.com/rails/rails/issues/46179)

    To opt out of SQLCommenter-formatted query log tags, set `config.active_record.query_log_tags_format = :legacy`. By default, this is set to `:sqlcommenter`.

    *Modulitos* and *Iheanyi*

*   Allow any ERB in the database.yml when creating rake tasks.

    Any ERB can be used in `database.yml` even if it accesses environment
    configurations.

    Deprecates `config.active_record.suppress_multiple_database_warning`.

    *Eike Send*

*   Add table to error for duplicate column definitions.

    If a migration defines duplicate columns for a table, the error message
    shows which table it concerns.

    *Petrik de Heus*

*   Fix erroneous nil default precision on virtual datetime columns.

    Prior to this change, virtual datetime columns did not have the same
    default precision as regular datetime columns, resulting in the following
    being erroneously equivalent:

        t.virtual :name, type: datetime,                 as: "expression"
        t.virtual :name, type: datetime, precision: nil, as: "expression"

    This change fixes the default precision lookup, so virtual and regular
    datetime column default precisions match.

    *Sam Bostock*

*   Use connection from `#with_raw_connection` in `#quote_string`.

    This ensures that the string quoting is wrapped in the reconnect and retry logic
    that `#with_raw_connection` offers.

    *Adrianna Chang*

*   Add `expires_at` option to `signed_id`.

    *Shouichi Kamiya*

*   Allow applications to set retry deadline for query retries.

    Building on the work done in #44576 and #44591, we extend the logic that automatically
    reconnects database connections to take into account a timeout limit. We won't retry
    a query if a given amount of time has elapsed since the query was first attempted. This
    value defaults to nil, meaning that all retryable queries are retried regardless of time elapsed,
    but this can be changed via the `retry_deadline` option in the database config.

    *Adrianna Chang*

*   Fix a case where the query cache can return wrong values. See #46044

    *Aaron Patterson*

*   Support MySQL's ssl-mode option for MySQLDatabaseTasks.

    Verifying the identity of the database server requires setting the ssl-mode
    option to VERIFY_CA or VERIFY_IDENTITY. This option was previously ignored
    for MySQL database tasks like creating a database and dumping the structure.

    *Petrik de Heus*

*   Move `ActiveRecord::InternalMetadata` to an independent object.

    `ActiveRecord::InternalMetadata` no longer inherits from `ActiveRecord::Base` and is now an independent object that should be instantiated with a `connection`. This class is private and should not be used by applications directly. If you want to interact with the schema migrations table, please access it on the connection directly, for example: `ActiveRecord::Base.connection.schema_migration`.

    *Eileen M. Uchitelle*

*   Deprecate quoting `ActiveSupport::Duration` as an integer

    Using ActiveSupport::Duration as an interpolated bind parameter in a SQL
    string template is deprecated. To avoid this warning, you should explicitly
    convert the duration to a more specific database type. For example, if you
    want to use a duration as an integer number of seconds:
    ```
    Record.where("duration = ?", 1.hour.to_i)
    ```
    If you want to use a duration as an ISO 8601 string:
    ```
    Record.where("duration = ?", 1.hour.iso8601)
    ```

    *Aram Greenman*

*   Allow `QueryMethods#in_order_of` to order by a string column name.

    ```ruby
    Post.in_order_of("id", [4,2,3,1]).to_a
    Post.joins(:author).in_order_of("authors.name", ["Bob", "Anna", "John"]).to_a
    ```

    *Igor Kasyanchuk*

*   Move `ActiveRecord::SchemaMigration` to an independent object.

    `ActiveRecord::SchemaMigration` no longer inherits from `ActiveRecord::Base` and is now an independent object that should be instantiated with a `connection`. This class is private and should not be used by applications directly. If you want to interact with the schema migrations table, please access it on the connection directly, for example: `ActiveRecord::Base.connection.schema_migration`.

    *Eileen M. Uchitelle*

*   Deprecate `all_connection_pools` and make `connection_pool_list` more explicit.

    Following on #45924 `all_connection_pools` is now deprecated. `connection_pool_list` will either take an explicit role or applications can opt into the new behavior by passing `:all`.

    *Eileen M. Uchitelle*

*   Fix connection handler methods to operate on all pools.

    `active_connections?`, `clear_active_connections!`, `clear_reloadable_connections!`, `clear_all_connections!`, and `flush_idle_connections!` now operate on all pools by default. Previously they would default to using the `current_role` or `:writing` role unless specified.

    *Eileen M. Uchitelle*


*   Allow ActiveRecord::QueryMethods#select to receive hash values.

    Currently, `select` might receive only raw sql and symbols to define columns and aliases to select.

    With this change we can provide `hash` as argument, for example:

    ```ruby
    Post.joins(:comments).select(posts: [:id, :title, :created_at], comments: [:id, :body, :author_id])
    #=> "SELECT \"posts\".\"id\", \"posts\".\"title\", \"posts\".\"created_at\", \"comments\".\"id\", \"comments\".\"body\", \"comments\".\"author_id\"
    #   FROM \"posts\" INNER JOIN \"comments\" ON \"comments\".\"post_id\" = \"posts\".\"id\""

    Post.joins(:comments).select(posts: { id: :post_id, title: :post_title }, comments: { id: :comment_id, body: :comment_body })
    #=> "SELECT posts.id as post_id, posts.title as post_title, comments.id as comment_id, comments.body as comment_body
    #    FROM \"posts\" INNER JOIN \"comments\" ON \"comments\".\"post_id\" = \"posts\".\"id\""
    ```
    *Oleksandr Holubenko*, *Josef Šimánek*, *Jean Boussier*

*   Adapts virtual attributes on `ActiveRecord::Persistence#becomes`.

    When source and target classes have a different set of attributes adapts
    attributes such that the extra attributes from target are added.

    ```ruby
    class Person < ApplicationRecord
    end

    class WebUser < Person
      attribute :is_admin, :boolean
      after_initialize :set_admin

      def set_admin
        write_attribute(:is_admin, email =~ /@ourcompany\.com$/)
      end
    end

    person = Person.find_by(email: "email@ourcompany.com")
    person.respond_to? :is_admin
    # => false
    person.becomes(WebUser).is_admin?
    # => true
    ```

    *Jacopo Beschi*, *Sampson Crowley*

*   Fix `ActiveRecord::QueryMethods#in_order_of` to include `nil`s, to match the
    behavior of `Enumerable#in_order_of`.

    For example, `Post.in_order_of(:title, [nil, "foo"])` will now include posts
    with `nil` titles, the same as `Post.all.to_a.in_order_of(:title, [nil, "foo"])`.

    *fatkodima*

*   Optimize `add_timestamps` to use a single SQL statement.

    ```ruby
    add_timestamps :my_table
    ```

    Now results in the following SQL:

    ```sql
    ALTER TABLE "my_table" ADD COLUMN "created_at" datetime(6) NOT NULL, ADD COLUMN "updated_at" datetime(6) NOT NULL
    ```

    *Iliana Hadzhiatanasova*

*   Add `drop_enum` migration command for PostgreSQL

    This does the inverse of `create_enum`. Before dropping an enum, ensure you have
    dropped columns that depend on it.

    *Alex Ghiculescu*

*   Adds support for `if_exists` option when removing a check constraint.

    The `remove_check_constraint` method now accepts an `if_exists` option. If set
    to true an error won't be raised if the check constraint doesn't exist.

    *Margaret Parsa* and *Aditya Bhutani*

*   `find_or_create_by` now try to find a second time if it hits a unicity constraint.

    `find_or_create_by` always has been inherently racy, either creating multiple
    duplicate records or failing with `ActiveRecord::RecordNotUnique` depending on
    whether a proper unicity constraint was set.

    `create_or_find_by` was introduced for this use case, however it's quite wasteful
    when the record is expected to exist most of the time, as INSERT require to send
    more data than SELECT and require more work from the database. Also on some
    databases it can actually consume a primary key increment which is undesirable.

    So for case where most of the time the record is expected to exist, `find_or_create_by`
    can be made race-condition free by re-trying the `find` if the `create` failed
    with `ActiveRecord::RecordNotUnique`. This assumes that the table has the proper
    unicity constraints, if not, `find_or_create_by` will still lead to duplicated records.

    *Jean Boussier*, *Alex Kitchens*

*   Introduce a simpler constructor API for ActiveRecord database adapters.

    Previously the adapter had to know how to build a new raw connection to
    support reconnect, but also expected to be passed an initial already-
    established connection.

    When manually creating an adapter instance, it will now accept a single
    config hash, and only establish the real connection on demand.

    *Matthew Draper*

*   Avoid redundant `SELECT 1` connection-validation query during DB pool
    checkout when possible.

    If the first query run during a request is known to be idempotent, it can be
    used directly to validate the connection, saving a network round-trip.

    *Matthew Draper*

*   Automatically reconnect broken database connections when safe, even
    mid-request.

    When an error occurs while attempting to run a known-idempotent query, and
    not inside a transaction, it is safe to immediately reconnect to the
    database server and try again, so this is now the default behavior.

    This new default should always be safe -- to support that, it's consciously
    conservative about which queries are considered idempotent -- but if
    necessary it can be disabled by setting the `connection_retries` connection
    option to `0`.

    *Matthew Draper*

*   Avoid removing a PostgreSQL extension when there are dependent objects.

    Previously, removing an extension also implicitly removed dependent objects. Now, this will raise an error.

    You can force removing the extension:

    ```ruby
    disable_extension :citext, force: :cascade
    ```

    Fixes #29091.

    *fatkodima*

*   Allow nested functions as safe SQL string

    *Michael Siegfried*

*   Allow `destroy_association_async_job=` to be configured with a class string instead of a constant.

    Defers an autoloading dependency between `ActiveRecord::Base` and `ActiveJob::Base`
    and moves the configuration of `ActiveRecord::DestroyAssociationAsyncJob`
    from ActiveJob to ActiveRecord.

    Deprecates `ActiveRecord::ActiveJobRequiredError` and now raises a `NameError`
    if the job class is unloadable or an `ActiveRecord::ConfigurationError` if
    `dependent: :destroy_async` is declared on an association but there is no job
    class configured.

    *Ben Sheldon*

*   Fix `ActiveRecord::Store` to serialize as a regular Hash

    Previously it would serialize as an `ActiveSupport::HashWithIndifferentAccess`
    which is wasteful and cause problem with YAML safe_load.

    *Jean Boussier*

*   Add `timestamptz` as a time zone aware type for PostgreSQL

    This is required for correctly parsing `timestamp with time zone` values in your database.

    If you don't want this, you can opt out by adding this initializer:

    ```ruby
    ActiveRecord::Base.time_zone_aware_types -= [:timestamptz]
    ```

    *Alex Ghiculescu*

*   Add new `ActiveRecord::Base.generates_token_for` API.

    Currently, `signed_id` fulfills the role of generating tokens for e.g.
    resetting a password.  However, signed IDs cannot reflect record state, so
    if a token is intended to be single-use, it must be tracked in a database at
    least until it expires.

    With `generates_token_for`, a token can embed data from a record.  When
    using the token to fetch the record, the data from the token and the current
    data from the record will be compared.  If the two do not match, the token
    will be treated as invalid, the same as if it had expired.  For example:

    ```ruby
    class User < ActiveRecord::Base
      has_secure_password

      generates_token_for :password_reset, expires_in: 15.minutes do
        # A password's BCrypt salt changes when the password is updated.
        # By embedding (part of) the salt in a token, the token will
        # expire when the password is updated.
        BCrypt::Password.new(password_digest).salt[-10..]
      end
    end

    user = User.first
    token = user.generate_token_for(:password_reset)

    User.find_by_token_for(:password_reset, token) # => user

    user.update!(password: "new password")
    User.find_by_token_for(:password_reset, token) # => nil
    ```

    *Jonathan Hefner*

*   Optimize Active Record batching for whole table iterations.

    Previously, `in_batches` got all the ids and constructed an `IN`-based query for each batch.
    When iterating over the whole tables, this approach is not optimal as it loads unneeded ids and
    `IN` queries with lots of items are slow.

    Now, whole table iterations use range iteration (`id >= x AND id <= y`) by default which can make iteration
    several times faster. E.g., tested on a PostgreSQL table with 10 million records: querying (`253s` vs `30s`),
    updating (`288s` vs `124s`), deleting (`268s` vs `83s`).

    Only whole table iterations use this style of iteration by default. You can disable this behavior by passing `use_ranges: false`.
    If you iterate over the table and the only condition is, e.g., `archived_at: nil` (and only a tiny fraction
    of the records are archived), it makes sense to opt in to this approach:

    ```ruby
    Project.where(archived_at: nil).in_batches(use_ranges: true) do |relation|
      # do something
    end
    ```

    See #45414 for more details.

    *fatkodima*

*   `.with` query method added. Construct common table expressions with ease and get `ActiveRecord::Relation` back.

    ```ruby
    Post.with(posts_with_comments: Post.where("comments_count > ?", 0))
    # => ActiveRecord::Relation
    # WITH posts_with_comments AS (SELECT * FROM posts WHERE (comments_count > 0)) SELECT * FROM posts
    ```

    *Vlado Cingel*

*   Don't establish a new connection if an identical pool exists already.

    Previously, if `establish_connection` was called on a class that already had an established connection, the existing connection would be removed regardless of whether it was the same config. Now if a pool is found with the same values as the new connection, the existing connection will be returned instead of creating a new one.

    This has a slight change in behavior if application code is depending on a new connection being established regardless of whether it's identical to an existing connection. If the old behavior is desirable, applications should call `ActiveRecord::Base#remove_connection` before establishing a new one. Calling `establish_connection` with a different config works the same way as it did previously.

    *Eileen M. Uchitelle*

*   Update `db:prepare` task to load schema when an uninitialized database exists, and dump schema after migrations.

    *Ben Sheldon*

*   Fix supporting timezone awareness for `tsrange` and `tstzrange` array columns.

    ```ruby
    # In database migrations
    add_column :shops, :open_hours, :tsrange, array: true
    # In app config
    ActiveRecord::Base.time_zone_aware_types += [:tsrange]
    # In the code times are properly converted to app time zone
    Shop.create!(open_hours: [Time.current..8.hour.from_now])
    ```

    *Wojciech Wnętrzak*

*   Introduce strategy pattern for executing migrations.

    By default, migrations will use a strategy object that delegates the method
    to the connection adapter. Consumers can implement custom strategy objects
    to change how their migrations run.

    *Adrianna Chang*

*   Add adapter option disallowing foreign keys

    This adds a new option to be added to `database.yml` which enables skipping
    foreign key constraints usage even if the underlying database supports them.

    Usage:
    ```yaml
    development:
        <<: *default
        database: storage/development.sqlite3
        foreign_keys: false
    ```

    *Paulo Barros*

*   Add configurable deprecation warning for singular associations

    This adds a deprecation warning when using the plural name of a singular associations in `where`.
    It is possible to opt into the new more performant behavior with `config.active_record.allow_deprecated_singular_associations_name = false`

    *Adam Hess*

*   Run transactional callbacks on the freshest instance to save a given
    record within a transaction.

    When multiple Active Record instances change the same record within a
    transaction, Rails runs `after_commit` or `after_rollback` callbacks for
    only one of them. `config.active_record.run_commit_callbacks_on_first_saved_instances_in_transaction`
    was added to specify how Rails chooses which instance receives the
    callbacks. The framework defaults were changed to use the new logic.

    When `config.active_record.run_commit_callbacks_on_first_saved_instances_in_transaction`
    is `true`, transactional callbacks are run on the first instance to save,
    even though its instance state may be stale.

    When it is `false`, which is the new framework default starting with version
    7.1, transactional callbacks are run on the instances with the freshest
    instance state. Those instances are chosen as follows:

    - In general, run transactional callbacks on the last instance to save a
      given record within the transaction.
    - There are two exceptions:
        - If the record is created within the transaction, then updated by
          another instance, `after_create_commit` callbacks will be run on the
          second instance. This is instead of the `after_update_commit`
          callbacks that would naively be run based on that instance’s state.
        - If the record is destroyed within the transaction, then
          `after_destroy_commit` callbacks will be fired on the last destroyed
          instance, even if a stale instance subsequently performed an update
          (which will have affected 0 rows).

    *Cameron Bothner and Mitch Vollebregt*

*   Enable strict strings mode for `SQLite3Adapter`.

    Configures SQLite with a strict strings mode, which disables double-quoted string literals.

    SQLite has some quirks around double-quoted string literals.
    It first tries to consider double-quoted strings as identifier names, but if they don't exist
    it then considers them as string literals. Because of this, typos can silently go unnoticed.
    For example, it is possible to create an index for a non existing column.
    See [SQLite documentation](https://www.sqlite.org/quirks.html#double_quoted_string_literals_are_accepted) for more details.

    If you don't want this behavior, you can disable it via:

    ```ruby
    # config/application.rb
    config.active_record.sqlite3_adapter_strict_strings_by_default = false
    ```

    Fixes #27782.

    *fatkodima*, *Jean Boussier*

*   Resolve issue where a relation cache_version could be left stale.

    Previously, when `reset` was called on a relation object it did not reset the cache_versions
    ivar. This led to a confusing situation where despite having the correct data the relation
    still reported a stale cache_version.

    Usage:

    ```ruby
    developers = Developer.all
    developers.cache_version

    Developer.update_all(updated_at: Time.now.utc + 1.second)

    developers.cache_version # Stale cache_version
    developers.reset
    developers.cache_version # Returns the current correct cache_version
    ```

    Fixes #45341.

    *Austen Madden*

*   Add support for exclusion constraints (PostgreSQL-only).

    ```ruby
    add_exclusion_constraint :invoices, "daterange(start_date, end_date) WITH &&", using: :gist, name: "invoices_date_overlap"
    remove_exclusion_constraint :invoices, name: "invoices_date_overlap"
    ```

    See PostgreSQL's [`CREATE TABLE ... EXCLUDE ...`](https://www.postgresql.org/docs/12/sql-createtable.html#SQL-CREATETABLE-EXCLUDE) documentation for more on exclusion constraints.

    *Alex Robbin*

*   `change_column_null` raises if a non-boolean argument is provided

    Previously if you provided a non-boolean argument, `change_column_null` would
    treat it as truthy and make your column nullable. This could be surprising, so now
    the input must be either `true` or `false`.

    ```ruby
    change_column_null :table, :column, true # good
    change_column_null :table, :column, false # good
    change_column_null :table, :column, from: true, to: false # raises (previously this made the column nullable)
    ```

    *Alex Ghiculescu*

*   Enforce limit on table names length.

    Fixes #45130.

    *fatkodima*

*   Adjust the minimum MariaDB version for check constraints support.

    *Eddie Lebow*

*   Fix Hstore deserialize regression.

    *edsharp*

*   Add validity for PostgreSQL indexes.

    ```ruby
    connection.index_exists?(:users, :email, valid: true)
    connection.indexes(:users).select(&:valid?)
    ```

    *fatkodima*

*   Fix eager loading for models without primary keys.

    *Anmol Chopra*, *Matt Lawrence*, and *Jonathan Hefner*

*   Avoid validating a unique field if it has not changed and is backed by a unique index.

    Previously, when saving a record, Active Record will perform an extra query to check for the
    uniqueness of each attribute having a `uniqueness` validation, even if that attribute hasn't changed.
    If the database has the corresponding unique index, then this validation can never fail for persisted
    records, and we could safely skip it.

    *fatkodima*

*   Stop setting `sql_auto_is_null`

    Since version 5.5 the default has been off, we no longer have to manually turn it off.

    *Adam Hess*

*   Fix `touch` to raise an error for readonly columns.

    *fatkodima*

*   Add ability to ignore tables by regexp for SQL schema dumps.

    ```ruby
    ActiveRecord::SchemaDumper.ignore_tables = [/^_/]
    ```

    *fatkodima*

*   Avoid queries when performing calculations on contradictory relations.

    Previously calculations would make a query even when passed a
    contradiction, such as `User.where(id: []).count`. We no longer perform a
    query in that scenario.

    This applies to the following calculations: `count`, `sum`, `average`,
    `minimum` and `maximum`

    *Luan Vieira, John Hawthorn and Daniel Colson*

*   Allow using aliased attributes with `insert_all`/`upsert_all`.

    ```ruby
    class Book < ApplicationRecord
      alias_attribute :title, :name
    end

    Book.insert_all [{ title: "Remote", author_id: 1 }], returning: :title
    ```

    *fatkodima*

*   Support encrypted attributes on columns with default db values.

    This adds support for encrypted attributes defined on columns with default values.
    It will encrypt those values at creation time. Before, it would raise an
    error unless `config.active_record.encryption.support_unencrypted_data` was true.

    *Jorge Manrubia* and *Dima Fatko*

*   Allow overriding `reading_request?` in `DatabaseSelector::Resolver`

    The default implementation checks if a request is a `get?` or `head?`,
    but you can now change it to anything you like. If the method returns true,
    `Resolver#read` gets called meaning the request could be served by the
    replica database.

    *Alex Ghiculescu*

*   Remove `ActiveRecord.legacy_connection_handling`.

    *Eileen M. Uchitelle*

*   `rails db:schema:{dump,load}` now checks `ENV["SCHEMA_FORMAT"]` before config

    Since `rails db:structure:{dump,load}` was deprecated there wasn't a simple
    way to dump a schema to both SQL and Ruby formats. You can now do this with
    an environment variable. For example:

    ```
    SCHEMA_FORMAT=sql rake db:schema:dump
    ```

    *Alex Ghiculescu*

*   Fixed MariaDB default function support.

    Defaults would be written wrong in "db/schema.rb" and not work correctly
    if using `db:schema:load`. Further more the function name would be
    added as string content when saving new records.

    *kaspernj*

*   Add `active_record.destroy_association_async_batch_size` configuration

    This allows applications to specify the maximum number of records that will
    be destroyed in a single background job by the `dependent: :destroy_async`
    association option. By default, the current behavior will remain the same:
    when a parent record is destroyed, all dependent records will be destroyed
    in a single background job. If the number of dependent records is greater
    than this configuration, the records will be destroyed in multiple
    background jobs.

    *Nick Holden*

*   Fix `remove_foreign_key` with `:if_exists` option when foreign key actually exists.

    *fatkodima*

*   Remove `--no-comments` flag in structure dumps for PostgreSQL

    This broke some apps that used custom schema comments. If you don't want
    comments in your structure dump, you can use:

    ```ruby
    ActiveRecord::Tasks::DatabaseTasks.structure_dump_flags = ['--no-comments']
    ```

    *Alex Ghiculescu*

*   Reduce the memory footprint of fixtures accessors.

    Until now fixtures accessors were eagerly defined using `define_method`.
    So the memory usage was directly dependent of the number of fixtures and
    test suites.

    Instead fixtures accessors are now implemented with `method_missing`,
    so they incur much less memory and CPU overhead.

    *Jean Boussier*

*   Fix `config.active_record.destroy_association_async_job` configuration

    `config.active_record.destroy_association_async_job` should allow
    applications to specify the job that will be used to destroy associated
    records in the background for `has_many` associations with the
    `dependent: :destroy_async` option. Previously, that was ignored, which
    meant the default `ActiveRecord::DestroyAssociationAsyncJob` always
    destroyed records in the background.

    *Nick Holden*

*   Fix `change_column_comment` to preserve column's AUTO_INCREMENT in the MySQL adapter

    *fatkodima*

*   Fix quoting of `ActiveSupport::Duration` and `Rational` numbers in the MySQL adapter.

    *Kevin McPhillips*

*   Allow column name with COLLATE (e.g., title COLLATE "C") as safe SQL string

    *Shugo Maeda*

*   Permit underscores in the VERSION argument to database rake tasks.

    *Eddie Lebow*

*   Reversed the order of `INSERT` statements in `structure.sql` dumps

    This should decrease the likelihood of merge conflicts. New migrations
    will now be added at the top of the list.

    For existing apps, there will be a large diff the next time `structure.sql`
    is generated.

    *Alex Ghiculescu*, *Matt Larraz*

*   Fix PG.connect keyword arguments deprecation warning on ruby 2.7

    Fixes #44307.

    *Nikita Vasilevsky*

*   Fix dropping DB connections after serialization failures and deadlocks.

    Prior to 6.1.4, serialization failures and deadlocks caused rollbacks to be
    issued for both real transactions and savepoints. This breaks MySQL which
    disallows rollbacks of savepoints following a deadlock.

    6.1.4 removed these rollbacks, for both transactions and savepoints, causing
    the DB connection to be left in an unknown state and thus discarded.

    These rollbacks are now restored, except for savepoints on MySQL.

    *Thomas Morgan*

*   Make `ActiveRecord::ConnectionPool` Fiber-safe

    When `ActiveSupport::IsolatedExecutionState.isolation_level` is set to `:fiber`,
    the connection pool now supports multiple Fibers from the same Thread checking
    out connections from the pool.

    *Alex Matchneer*

*   Add `update_attribute!` to `ActiveRecord::Persistence`

    Similar to `update_attribute`, but raises `ActiveRecord::RecordNotSaved` when a `before_*` callback throws `:abort`.

    ```ruby
    class Topic < ActiveRecord::Base
      before_save :check_title

      def check_title
        throw(:abort) if title == "abort"
      end
    end

    topic = Topic.create(title: "Test Title")
    # #=> #<Topic title: "Test Title">
    topic.update_attribute!(:title, "Another Title")
    # #=> #<Topic title: "Another Title">
    topic.update_attribute!(:title, "abort")
    # raises ActiveRecord::RecordNotSaved
    ```

    *Drew Tempelmeyer*

*   Avoid loading every record in `ActiveRecord::Relation#pretty_print`

    ```ruby
    # Before
    pp Foo.all # Loads the whole table.

    # After
    pp Foo.all # Shows 10 items and an ellipsis.
    ```

    *Ulysse Buonomo*

*   Change `QueryMethods#in_order_of` to drop records not listed in values.

    `in_order_of` now filters down to the values provided, to match the behavior of the `Enumerable` version.

    *Kevin Newton*

*   Allow named expression indexes to be revertible.

    Previously, the following code would raise an error in a reversible migration executed while rolling back, due to the index name not being used in the index removal.

    ```ruby
    add_index(:settings, "(data->'property')", using: :gin, name: :index_settings_data_property)
    ```

    Fixes #43331.

    *Oliver Günther*

*   Fix incorrect argument in PostgreSQL structure dump tasks.

    Updating the `--no-comment` argument added in Rails 7 to the correct `--no-comments` argument.

    *Alex Dent*

*   Fix migration compatibility to create SQLite references/belongs_to column as integer when migration version is 6.0.

    Reference/belongs_to in migrations with version 6.0 were creating columns as
    bigint instead of integer for the SQLite Adapter.

    *Marcelo Lauxen*

*   Fix `QueryMethods#in_order_of` to handle empty order list.

    ```ruby
    Post.in_order_of(:id, []).to_a
    ```

    Also more explicitly set the column as secondary order, so that any other
    value is still ordered.

    *Jean Boussier*

*   Fix quoting of column aliases generated by calculation methods.

    Since the alias is derived from the table name, we can't assume the result
    is a valid identifier.

    ```ruby
    class Test < ActiveRecord::Base
      self.table_name = '1abc'
    end
    Test.group(:id).count
    # syntax error at or near "1" (ActiveRecord::StatementInvalid)
    # LINE 1: SELECT COUNT(*) AS count_all, "1abc"."id" AS 1abc_id FROM "1...
    ```

    *Jean Boussier*

*   Add `authenticate_by` when using `has_secure_password`.

    `authenticate_by` is intended to replace code like the following, which
    returns early when a user with a matching email is not found:

    ```ruby
    User.find_by(email: "...")&.authenticate("...")
    ```

    Such code is vulnerable to timing-based enumeration attacks, wherein an
    attacker can determine if a user account with a given email exists. After
    confirming that an account exists, the attacker can try passwords associated
    with that email address from other leaked databases, in case the user
    re-used a password across multiple sites (a common practice). Additionally,
    knowing an account email address allows the attacker to attempt a targeted
    phishing ("spear phishing") attack.

    `authenticate_by` addresses the vulnerability by taking the same amount of
    time regardless of whether a user with a matching email is found:

    ```ruby
    User.authenticate_by(email: "...", password: "...")
    ```

    *Jonathan Hefner*


Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/activerecord/CHANGELOG.md) for previous changes.
