# frozen_string_literal: true

module ConnectionHelper
  def run_without_connection
    original_connection = ActiveRecord::Base.remove_connection
    yield original_connection.configuration_hash
  ensure
    ActiveRecord::Base.establish_connection(original_connection)
  end

  # Resets state (cached plans, session settings) on the existing connection.
  def reset_connection
    @connection.reset!
  end

  # Replaces the connection pool, yielding a fresh adapter instance.
  def reset_pool
    original_connection = ActiveRecord::Base.remove_connection
    ActiveRecord::Base.establish_connection(original_connection)
  end
end
