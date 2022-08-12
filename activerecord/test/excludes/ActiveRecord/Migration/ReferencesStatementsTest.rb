exclude :test_deletes_reference_type_column, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: can't drop column supplier_id with composite index covered or Primary Key covered now
MSG
exclude :test_does_not_delete_reference_type_column, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: can't drop column supplier_id with composite index covered or Primary Key covered now
MSG
exclude :test_deletes_polymorphic_index, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: can't drop column supplier_id with composite index covered or Primary Key covered now
MSG
