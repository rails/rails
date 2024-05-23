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
