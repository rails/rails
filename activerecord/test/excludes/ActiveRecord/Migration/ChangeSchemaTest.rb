exclude :test_add_column_with_primary_key_attribute, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: unsupported add column 'id' constraint AUTO_INCREMENT when altering 'activerecord_unittest.testings'
MSG
