exlude: :test_create_table_with_query_from_relation, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: 'CREATE TABLE ... SELECT' is not implemented yet
MSG

exclude: :test_create_table_with_query, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: 'CREATE TABLE ... SELECT' is not implemented yet
MSG