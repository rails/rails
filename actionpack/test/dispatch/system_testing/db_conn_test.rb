require "abstract_unit"

# We're trying to test that threads are shared between the test-runner
# thread and the server thread, when appropriate.  But we don't have the
# "real" ActiveRecord.  So, we mock up the per-thread behavior of
# ActiveRecord's connection pools, using "connections" which are
# just random objects.

# But to do this, we have to have mock ActiveRecord::Base.connection
# and .connection_pool in place while 'setup' is running, so they
# can't just be stubbed within the tests themselves.  Hence the
# following, admittedly dodgy hack:

module ActiveRecord
  class Base
    def self.connection; MockConnectionPool::connection; end
    def self.connection_pool; MockConnectionPool; end
  end
end

module MockConnectionPool

  def self.connection
    Thread.current['db_connection'] ||= Object.new
  end

  def self.using_connection(conn)
    saved_conn = Thread.current['db_connection']
    begin
      Thread.current['db_connection'] = conn
      yield
    ensure
      Thread.current['db_connection'] = saved_conn
    end
  end

end

class TestTransactionalSharing < DrivenByRackTest

  cattr_accessor :use_transactional_tests

  test "setup happens properly" do
    # Tests function of the Setup hook on SystemTest itself
    assert_equal self, self.class.currently_running_test
    assert_equal ActiveRecord::Base.connection, self.class.cached_db_connection
  end

  test "shares DB connection when transactional" do
    self.class.use_transactional_tests = true
    test_runner_connection = ActiveRecord::Base.connection
    Thread.new do
      ActionDispatch::SystemTestCase.with_db_connection_for_web_service do
        assert_equal test_runner_connection, ActiveRecord::Base.connection
      end
    end.join
  end

  test "doesn't share DB connection when not transactional" do
    self.class.use_transactional_tests = false
    test_runner_connection = ActiveRecord::Base.connection
    Thread.new do
      ActionDispatch::SystemTestCase.with_db_connection_for_web_service do
        assert_not_equal test_runner_connection, ActiveRecord::Base.connection
      end
    end.join
  end
  
end
