ActiveRecord::Base.send :increment_open_transactions
ActiveRecord::Base.connection.begin_db_transaction
at_exit do
  ActiveRecord::Base.connection.rollback_db_transaction
  ActiveRecord::Base.send :decrement_open_transactions
end
