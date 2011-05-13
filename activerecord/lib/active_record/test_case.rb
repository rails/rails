module ActiveRecord
  # = Active Record Test Case
  #
  # Defines some test assertions to test against SQL queries.
  class TestCase < ActiveSupport::TestCase #:nodoc:
    # Backport skip to Ruby 1.8.  test/unit doesn't support it, so just
    # make it a noop.
    unless instance_methods.map(&:to_s).include?("skip")
      def skip(message)
      end
    end

    def assert_date_from_db(expected, actual, message = nil)
      # SybaseAdapter doesn't have a separate column type just for dates,
      # so the time is in the string and incorrectly formatted
      if current_adapter?(:SybaseAdapter)
        assert_equal expected.to_s, actual.to_date.to_s, message
      else
        assert_equal expected.to_s, actual.to_s, message
      end
    end

    def assert_sql(*patterns_to_match)
      $queries_executed = []
      yield
    ensure
      failed_patterns = []
      patterns_to_match.each do |pattern|
        failed_patterns << pattern unless $queries_executed.any?{ |sql| pattern === sql }
      end
      assert failed_patterns.empty?, "Query pattern(s) #{failed_patterns.map{ |p| p.inspect }.join(', ')} not found.#{$queries_executed.size == 0 ? '' : "\nQueries:\n#{$queries_executed.join("\n")}"}"
    end

    def assert_queries(num = 1)
      $queries_executed = []
      yield
    ensure
      %w{ BEGIN COMMIT }.each { |x| $queries_executed.delete(x) }
      assert_equal num, $queries_executed.size, "#{$queries_executed.size} instead of #{num} queries were executed.#{$queries_executed.size == 0 ? '' : "\nQueries:\n#{$queries_executed.join("\n")}"}"
    end

    def assert_no_queries(&block)
      assert_queries(0, &block)
    end

    def self.use_concurrent_connections
      setup :connection_allow_concurrency_setup
      teardown :connection_allow_concurrency_teardown
    end

    def connection_allow_concurrency_setup
      @connection = ActiveRecord::Base.remove_connection
      ActiveRecord::Base.establish_connection(@connection.merge({:allow_concurrency => true}))
    end

    def connection_allow_concurrency_teardown
      ActiveRecord::Base.clear_all_connections!
      ActiveRecord::Base.establish_connection(@connection)
    end

    def with_kcode(kcode)
      if RUBY_VERSION < '1.9'
        orig_kcode, $KCODE = $KCODE, kcode
        begin
          yield
        ensure
          $KCODE = orig_kcode
        end
      else
        yield
      end
    end
  end
end
