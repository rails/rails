exclude :test_add_column_with_legacy_primary_key_should_be_integer, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: unsupported add column 'id' constraint AUTO_INCREMENT when altering 'activerecord_unittest.legacy_primary_keys'
MSG
exclude :test_add_column_with_legacy_primary_key_should_be_integer, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Can't DROP 'id'; check that column/key exists
MSG
exclude :test_legacy_primary_key_in_create_table_should_be_integer, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Table 'activerecord_unittest.legacy_primary_keys' already exists
MSG
exclude :test_legacy_primary_key_in_change_table_should_be_integer, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: unsupported add column 'id' constraint AUTO_INCREMENT when altering 'activerecord_unittest.legacy_primary_keys'
MSG
exclude :test_legacy_primary_key_in_change_table_should_be_integer, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Can't DROP 'id'; check that column/key exists
MSG
