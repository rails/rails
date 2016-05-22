## Rails 5.1.0.alpha ##

*   Remove deprecated `new_from_hash_copying_default` method from `ActiveSupport::HashWithIndifferentAccess`.

   *Jon Moss*

*   Remove deprecated `key_file_path` method from `ActiveSupport::Cache::FileStore`.

    *Jon Moss*

*   Remove deprecated `Kernel#debugger` core extension.

    *Jon Moss*

*   Remove deprecated `to_formatted_s` method from `ActiveSupport::NumericWithFormat`.

    *Jon Moss*

*   Remove deprecated `false` callback terminator from `ActiveSupport::Callbacks`.

    *Jon Moss*

*   Remove deprecated `namespaced_key` method from `ActiveSupport::Cache::Store`.

    *Jon Moss*

*   Remove deprecated `alias_method_chain` method.

    *Jon Moss*

*   Rescuable: If a handler doesn't match the exception, check for handlers
    matching the exception's cause.

    *Jeremy Daer*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/activesupport/CHANGELOG.md) for previous changes.
