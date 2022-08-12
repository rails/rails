exclude :test_multi_results_from_select_one, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Unsupported type *ast.CallStmt
MSG
exclude :test_multi_results_from_find_by_sql, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Unsupported type *ast.CallStmt
MSG
exclude :test_multi_results, <<~MSG
  Error
  ActiveRecord::StatementInvalid: Mysql2::Error: Unsupported type *ast.CallStmt
MSG
