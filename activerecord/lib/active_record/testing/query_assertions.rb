# frozen_string_literal: true

module ActiveRecord
  module Testing
    module QueryAssertions # :nodoc:
      def assert_queries(expected_count = 1, options = {})
        ignore_none = options.fetch(:ignore_none) { expected_count == :any }
        ActiveRecord::Base.connection.materialize_transactions
        SQLCounter.clear_log
        result = yield
        the_log = ignore_none ? SQLCounter.log_all : SQLCounter.log

        if expected_count == :any
          assert_operator the_log.size, :>=, 1, "1 or more queries expected, but none were executed."
        else
          message = "#{the_log.size} instead of #{expected_count} queries were executed.#{the_log.size == 0 ? '' : "\nQueries:\n#{the_log.join("\n")}"}"
          assert_equal expected_count, the_log.size, message
        end

        result
      end

      def assert_no_queries(&block)
        assert_queries(0, &block)
      end

      class SQLCounter # :nodoc:
        class << self
          attr_accessor :ignored_sql, :log, :log_all
          def clear_log; self.log = []; self.log_all = []; end
        end

        clear_log

        def call(*, values)
          return if values[:cached]

          sql = values[:sql]
          self.class.log_all << sql
          self.class.log << sql unless ["SCHEMA", "TRANSACTION"].include? values[:name]
        end
      end

      ActiveSupport::Notifications.subscribe("sql.active_record", SQLCounter.new)
    end
  end
end
