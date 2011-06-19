module ActiveRecord
  # = Active Record Test Case
  #
  # Defines some test assertions to test against SQL queries.
  class TestCase < ActiveSupport::TestCase #:nodoc:
    setup :cleanup_identity_map

    def setup
      cleanup_identity_map
    end

    def cleanup_identity_map
      ActiveRecord::IdentityMap.clear
    end

    # Backport skip to Ruby 1.8. test/unit doesn't support it, so just
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
      ActiveRecord::SQLCounter.log = []
      yield
      ActiveRecord::SQLCounter.log
    ensure
      failed_patterns = []
      patterns_to_match.each do |pattern|
        failed_patterns << pattern unless ActiveRecord::SQLCounter.log.any?{ |sql| pattern === sql }
      end
      assert failed_patterns.empty?, "Query pattern(s) #{failed_patterns.map{ |p| p.inspect }.join(', ')} not found.#{ActiveRecord::SQLCounter.log.size == 0 ? '' : "\nQueries:\n#{ActiveRecord::SQLCounter.log.join("\n")}"}"
    end

    def assert_queries(num = 1)
      ActiveRecord::SQLCounter.log = []
      yield
    ensure
      assert_equal num, ActiveRecord::SQLCounter.log.size, "#{ActiveRecord::SQLCounter.log.size} instead of #{num} queries were executed.#{ActiveRecord::SQLCounter.log.size == 0 ? '' : "\nQueries:\n#{ActiveRecord::SQLCounter.log.join("\n")}"}"
    end

    def assert_no_queries(&block)
      prev_ignored_sql = ActiveRecord::SQLCounter.ignored_sql
      ActiveRecord::SQLCounter.ignored_sql = []
      assert_queries(0, &block)
    ensure
      ActiveRecord::SQLCounter.ignored_sql = prev_ignored_sql
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
