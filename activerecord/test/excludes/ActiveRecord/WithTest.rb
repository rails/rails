exclude :test_common_table_expressions_are_unsupported, <<~MSG
  Failure
  ActiveRecord::StatementInvalid expected but nothing was raised.
MSG
