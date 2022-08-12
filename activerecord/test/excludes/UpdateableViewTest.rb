exclude :test_update_record_to_fail_view_conditions, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: The target table printed_books of the UPDATE is not updatable
MSG
exclude :test_update_record, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: The target table printed_books of the UPDATE is not updatable
MSG
exclude :test_insert_record, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: insert into view printed_books is not supported now
MSG
