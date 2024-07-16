*   Protect against invalid validate option on remove_check_constraint

    *Shayon Mukherjee*

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

*   Optimize `Relation#exists?` when records are loaded and the relation has no conditions.

    This can avoid queries in some cases.

    *fatkodima*

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
