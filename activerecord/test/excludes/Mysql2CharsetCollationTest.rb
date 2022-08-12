exclude :test_change_column_with_charset_and_collation, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Unknown character set: 'ucs2'
MSG
exclude :test_text_column_with_charset_and_collation, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Unknown character set: 'ucs2'
MSG
exclude :test_add_column_with_charset_and_collation, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Unknown character set: 'ucs2'
MSG
exclude :test_change_column_preserves_collation, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Unknown character set: 'ucs2'
MSG
exclude :test_schema_dump_includes_collation, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Unknown character set: 'ucs2'
MSG
exclude :test_string_column_with_charset_and_collation, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Unknown character set: 'ucs2'
MSG
