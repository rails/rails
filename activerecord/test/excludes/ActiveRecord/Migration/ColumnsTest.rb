exclude :test_remove_column_with_multi_column_index, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: can't drop column hat_size with composite index covered or Primary Key covered now
MSG
