ActiveRecord::Base.connection.begin_transaction
at_exit do
  ActiveRecord::Base.connection.rollback_transaction
end
