*   SQLite3Adapter: Bulk insert fixtures.

    Previously one insert command was executed for each fixture, now they are
    aggregated in a single bulk insert command.

    *Lázaro Nixon*

*   PostgreSQLAdapter: Allow `disable_extension` to be called with schema-qualified name.

    For parity with `enable_extension`, the `disable_extension` method can be called with a schema-qualified
    name (e.g. `disable_extension "myschema.pgcrypto"`). Note that PostgreSQL's `DROP EXTENSION` does not
    actually take a schema name (unlike `CREATE EXTENSION`), so the resulting SQL statement will only name
    the extension, e.g. `DROP EXTENSION IF EXISTS "pgcrypto"`.

    *Tony Novak*

*   Make `create_schema` / `drop_schema` reversible in migrations.

    Previously, `create_schema` and `drop_schema` were irreversible migration operations.

    *Tony Novak*

*   Support batching using custom columns.

    ```ruby
    Product.in_batches(cursor: [:shop_id, :id]) do |relation|
      # do something with relation
    end
    ```

    *fatkodima*

*   Use SQLite `IMMEDIATE` transactions when possible.

    Transactions run against the SQLite3 adapter default to IMMEDIATE mode to improve concurrency support and avoid busy exceptions.

    *Stephen Margheim*

*   Raise specific exception when a connection is not defined.

     The new `ConnectionNotDefined` exception provides connection name, shard and role accessors indicating the details of the connection that was requested.

    *Hana Harencarova*, *Matthew Draper*

*   Delete the deprecated constant `ActiveRecord::ImmutableRelation`.

    *Xavier Noria*

*   Fix duplicate callback execution when child autosaves parent with `has_one` and `belongs_to`.

    Before, persisting a new child record with a new associated parent record would run `before_validation`,
    `after_validation`, `before_save` and `after_save` callbacks twice.

    Now, these callbacks are only executed once as expected.

    *Joshua Young*

*   `ActiveRecord::Encryption::Encryptor` now supports a `:compressor` option to customize the compression algorithm used.

    ```ruby
    module ZstdCompressor
      def self.deflate(data)
        Zstd.compress(data)
      end

      def self.inflate(data)
        Zstd.decompress(data)
      end
    end

    class User
      encrypts :name, compressor: ZstdCompressor
    end
    ```

    You disable compression by passing `compress: false`.

    ```ruby
    class User
      encrypts :name, compress: false
    end
    ```

    *heka1024*

*   Add condensed `#inspect` for `ConnectionPool`, `AbstractAdapter`, and
    `DatabaseConfig`.

    *Hartley McGuire*

*   Add `.shard_keys`, `.sharded?`, & `.connected_to_all_shards` methods.

    ```ruby
    class ShardedBase < ActiveRecord::Base
        self.abstract_class = true

        connects_to shards: {
          shard_one: { writing: :shard_one },
          shard_two: { writing: :shard_two }
        }
    end

    class ShardedModel < ShardedBase
    end

    ShardedModel.shard_keys => [:shard_one, :shard_two]
    ShardedModel.sharded? => true
    ShardedBase.connected_to_all_shards { ShardedModel.current_shard } => [:shard_one, :shard_two]
    ```

    *Nony Dutton*

*   Add a `filter` option to `in_order_of` to prioritize certain values in the sorting without filtering the results
    by these values.

    *Igor Depolli*

*   Fix an issue where the IDs reader method did not return expected results
    for preloaded associations in models using composite primary keys.

    *Jay Ang*

*   Allow to configure `strict_loading_mode` globally or within a model.

    Defaults to `:all`, can be changed to `:n_plus_one_only`.

    *Garen Torikian*

*   Add `ActiveRecord::Relation#readonly?`.

    Reflects if the relation has been marked as readonly.

    *Theodor Tonum*

*   Improve `ActiveRecord::Store` to raise a descriptive exception if the column is not either
    structured (e.g., PostgreSQL +hstore+/+json+, or MySQL +json+) or declared serializable via
    `ActiveRecord.store`.

    Previously, a `NoMethodError` would be raised when the accessor was read or written:

        NoMethodError: undefined method `accessor' for an instance of ActiveRecord::Type::Text

    Now, a descriptive `ConfigurationError` is raised:

        ActiveRecord::ConfigurationError: the column 'metadata' has not been configured as a store.
          Please make sure the column is declared serializable via 'ActiveRecord.store' or, if your
          database supports it, use a structured column type like hstore or json.

    *Mike Dalessio*

*   Fix inference of association model on nested models with the same demodularized name.

    E.g. with the following setup:

    ```ruby
    class Nested::Post < ApplicationRecord
      has_one :post, through: :other
    end
    ```

    Before, `#post` would infer the model as `Nested::Post`, but now it correctly infers `Post`.

    *Joshua Young*

*   Add public method for checking if a table is ignored by the schema cache.

    Previously, an application would need to reimplement `ignored_table?` from the schema cache class to check if a table was set to be ignored. This adds a public method to support this and updates the schema cache to use that directly.

    ```ruby
    ActiveRecord.schema_cache_ignored_tables = ["developers"]
    ActiveRecord.schema_cache_ignored_table?("developers")
    => true
    ```

    *Eileen M. Uchitelle*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activerecord/CHANGELOG.md) for previous changes.
