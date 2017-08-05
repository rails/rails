# frozen_string_literal: true

ActiveRecord::Base.connection.begin_transaction(joinable: false)

at_exit do
  ActiveRecord::Base.connection.rollback_transaction
end
