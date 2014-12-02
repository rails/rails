*   `ActiveRecord::ConnectionAdapters::ColumnDumper#column_spec` and
    `ActiveRecord::ConnectionAdapters::ColumnDumper#prepare_column_options` no
    longer have a `types` argument. They should access
    `connection#native_database_types` directly.

    *Yves Senn*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/activerecord/CHANGELOG.md) for previous changes.
reverse_order will be called for all batch calls as a fix for the issue when using find_in_batches and reverse_order