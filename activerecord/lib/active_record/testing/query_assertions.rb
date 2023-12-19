# frozen_string_literal: true

module ActiveRecord
  module Assertions
    module QueryAssertions
      # Asserts that the number of SQL queries executed in the given block matches the expected count.
      #
      #   assert_queries(1) { Post.first }
      #
      # If the +:matcher+ option is provided, only queries that match the matcher are counted.
      #
      #   assert_queries(1, matcher: /LIMIT \?/) { Post.first }
      #
      def assert_queries(expected_count, matcher: nil, &block)
        ActiveRecord::Base.connection.materialize_transactions

        queries = []
        callback = lambda do |*, payload|
          queries << payload[:sql] if %w[ SCHEMA TRANSACTION ].exclude?(payload[:name]) && (matcher.nil? || payload[:sql].match(matcher))
        end
        ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
          result = _assert_nothing_raised_or_warn("assert_queries", &block)
          assert_equal expected_count, queries.size, "#{queries.size} instead of #{expected_count} queries were executed. Queries: #{queries.join("\n\n")}"
          result
        end
      end

      # Asserts that no SQL queries are executed in the given block.
      def assert_no_queries(&block)
        assert_queries(0, &block)
      end
    end
  end
end
