*   Add public method for checking if a table is ignored by the schema cache.

    Previously, an application would need to reimplement `ignored_table?` from the schema cache class to check if a table was set to be ignored. This adds a public method to support this and updates the schema cache to use that directly.

    ```ruby
    ActiveRecord.schema_cache_ignored_tables = ["developers"]
    ActiveRecord.schema_cache_ignored_tables?("developers")
    => true
    ```

    *Eileen M. Uchitelle*

Please check [7-2-stable](https://github.com/rails/rails/blob/7-2-stable/activerecord/CHANGELOG.md) for previous changes.
