exclude :test_raises_StatementTimeout_when_statement_timeout_exceeded, <<~MSG
  Failure
  [ActiveRecord::StatementTimeout] exception expected, not
MSG
exclude :test_raises_QueryCanceled_when_canceling_statement_due_to_user_request, <<~MSG
  Failure
  [ActiveRecord::QueryCanceled] exception expected, not
MSG
