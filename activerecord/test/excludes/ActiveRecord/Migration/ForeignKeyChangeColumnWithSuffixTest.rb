exclude :test_rename_reference_column_of_child_table, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: runtime error: invalid memory address or nil pointer dereference
MSG
