module ConnectionHelper
  def run_without_connection
    teardown_fixtures
    original_connection = ActiveRecord::Base.remove_connection
    yield original_connection
  ensure
    ActiveRecord::Base.establish_connection(original_connection)
  end

  # Used to drop all cache query plans in tests.
  def reset_connection
    teardown_fixtures
    original_connection = ActiveRecord::Base.remove_connection
    ActiveRecord::Base.establish_connection(original_connection)
  end
end
