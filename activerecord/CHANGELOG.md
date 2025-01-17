*   Fix orders of produced left joins when using `eager_load`.

    A `eager_load` followed by a `left_joins` was always resulting in the `LEFT JOIN`
    produced by `left_joins` to have precedence over the `LEFT JOIN` produced by
    the `eager_load` call.

    This was resulting in an invalid SQL query in some cases

    ```ruby
    Post.select(:id).eager_load(:author).merge(Author.left_joins(:address))
    ```

    ### Before (Invalid query)
    ```sql
    SELECT DISTINCT "posts"."id" FROM "posts" LEFT OUTER JOIN "addresses" ON "addresses"."id" = "authors"."address_id" LEFT OUTER JOIN "authors" ON "authors"."post_id" = "posts"."id"
    ```

    ### After
    ```sql
    SELECT DISTINCT "posts"."id" FROM "posts" LEFT OUTER JOIN "authors" ON "authors"."post_id" = "posts"."id" LEFT OUTER JOIN "addresses" ON "addresses"."id" = "authors"."address_id"
    ```

    *Edouard Chin*

*   Enable automatically retrying idempotent `#exists?` queries on connection
    errors.

    *Hartley McGuire*, *classidied*

*   Deprecate usage of unsupported methods in conjunction with `update_all`:

    `update_all` will now print a deprecation message if a query includes either `WITH`,
    `WITH RECURSIVE` or `DISTINCT` statements. Those were never supported and were ignored
    when generating the SQL query.

    An error will be raised in a future Rails release. This behaviour will be consistent
    with `delete_all` which currently raises an error for unsupported statements.

    *Edouard Chin*

*   The table columns inside `schema.rb` are now sorted alphabetically.

    Previously they'd be sorted by creation order, which can cause merge conflicts when two
    branches modify the same table concurrently.

    *John Duff*

*   Introduce versions formatter for the schema dumper.

    It is now possible to override how schema dumper formats versions information inside the
    `structure.sql` file. Currently, the versions are simply sorted in the decreasing order.
    Within large teams, this can potentially cause many merge conflicts near the top of the list.

    Now, the custom formatter can be provided with a custom sorting logic (e.g. by hash values
    of the versions), which can greatly reduce the number of conflicts.

    *fatkodima*

*   Serialized attributes can now be marked as comparable.

    A not rare issue when working with serialized attributes is that the serialized representation of an object
    can change over time. Either because you are migrating from one serializer to the other (e.g. YAML to JSON or to msgpack),
    or because the serializer used subtly changed its output.

    One example is libyaml that used to have some extra trailing whitespaces, and recently fixed that.
    When this sorts of thing happen, you end up with lots of records that report being changed even though
    they aren't, which in the best case leads to a lot more writes to the database and in the worst case lead to nasty bugs.

    The solution is to instead compare the deserialized representation of the object, however Active Record
    can't assume the deserialized object has a working `==` method. Hence why this new functionality is opt-in.

    ```ruby
    serialize :config, type: Hash, coder: JSON, comparable: true
    ```

    *Jean Boussier*

*   Fix MySQL default functions getting dropped when changing a column's nullability.

    *Bastian Bartmann*

*   SQLite extensions can be configured in `config/database.yml`.

    The database configuration option `extensions:` allows an application to load SQLite extensions
    when using `sqlite3` >= v2.4.0. The array members may be filesystem paths or the names of
    modules that respond to `.to_path`:

    ``` yaml
    development:
      adapter: sqlite3
      extensions:
        - SQLean::UUID                     # module name responding to `.to_path`
        - .sqlpkg/nalgeon/crypto/crypto.so # or a filesystem path
        - <%= AppExtensions.location %>    # or ruby code returning a path
    ```

    *Mike Dalessio*

*   `ActiveRecord::Middleware::ShardSelector` supports granular database connection switching.

    A new configuration option, `class_name:`, is introduced to
    `config.active_record.shard_selector` to allow an application to specify the abstract connection
    class to be switched by the shard selection middleware. The default class is
    `ActiveRecord::Base`.

    For example, this configuration tells `ShardSelector` to switch shards using
    `AnimalsRecord.connected_to`:

    ```
    config.active_record.shard_selector = { class_name: "AnimalsRecord" }
    ```

    *Mike Dalessio*

*   Reset relations after `insert_all`/`upsert_all`.

    Bulk insert/upsert methods will now call `reset` if used on a relation, matching the behavior of `update_all`.

    *Milo Winningham*

*   Use `_N` as a parallel tests databases suffixes

    Peviously, `-N` was used as a suffix. This can cause problems for RDBMSes
    which do not support dashes in database names.

    *fatkodima*

*   Remember when a database connection has recently been verified (for
    two seconds, by default), to avoid repeated reverifications during a
    single request.

    This should recreate a similar rate of verification as in Rails 7.1,
    where connections are leased for the duration of a request, and thus
    only verified once.

    *Matthew Draper*

*   Allow to reset cache counters for multiple records.

    ```
    Aircraft.reset_counters([1, 2, 3], :wheels_count)
    ```

    It produces much fewer queries compared to the custom implementation using looping over ids.
    Previously: `O(ids.size * counters.size)` queries, now: `O(ids.size + counters.size)` queries.

    *fatkodima*

*   Add `affected_rows` to `sql.active_record` Notification.

    *Hartley McGuire*

*   Fix `sum` when performing a grouped calculation.

    `User.group(:friendly).sum` no longer worked. This is fixed.

    *Edouard Chin*

*   Add support for enabling or disabling transactional tests per database.

    A test class can now override the default `use_transactional_tests` setting
    for individual databases, which can be useful if some databases need their
    current state to be accessible to an external process while tests are running.

    ```ruby
    class MostlyTransactionalTest < ActiveSupport::TestCase
      self.use_transactional_tests = true
      skip_transactional_tests_for_database :shared
    end
    ```

    *Matthew Cheetham*, *Morgan Mareve*

*   Cast `query_cache` value when using URL configuration.

    *zzak*

*   NULLS NOT DISTINCT works with UNIQUE CONSTRAINT as well as UNIQUE INDEX.

    *Ryuta Kamizono*

*   `PG::UnableToSend: no connection to the server` is now retryable as a connection-related exception

    *Kazuma Watanabe*

Please check [8-0-stable](https://github.com/rails/rails/blob/8-0-stable/activerecord/CHANGELOG.md) for previous changes.
