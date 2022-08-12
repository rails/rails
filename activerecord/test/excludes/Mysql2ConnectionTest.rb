exclude :test_character_set_connection_is_configured, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Unknown character set: 'cp932'
MSG
exclude :test_get_and_release_advisory_lock, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: FUNCTION IS_FREE_LOCK does not exist
MSG
