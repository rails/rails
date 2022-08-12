exclude :test_updating_auto_increment, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Unsupported modify column: can't remove auto_increment without @@tidb_allow_remove_auto_inc enabled
MSG
exclude :test_removing_index, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: column does not exist: name
MSG
exclude :test_changing_index, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: column does not exist: username
MSG
