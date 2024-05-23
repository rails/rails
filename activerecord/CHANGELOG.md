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
