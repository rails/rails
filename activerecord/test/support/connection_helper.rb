# frozen_string_literal: true

module ConnectionHelper
  def run_without_connection
    original_connection = ActiveRecord::Base.remove_connection_pool
    yield original_connection.configuration_hash
  ensure
    ActiveRecord::Base.establish_connection(original_connection)
  end

  # Used to drop all cache query plans in tests.
  def reset_connection
    original_connection = ActiveRecord::Base.remove_connection_pool
    ActiveRecord::Base.establish_connection(original_connection)
  end
end
