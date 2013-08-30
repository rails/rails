ActiveRecord::Base.connection.begin_transaction(joinable: false)

at_exit do
  if ActiveRecord::Base.connection.transaction_open?
    ActiveRecord::Base.connection.rollback_transaction
  end
end
