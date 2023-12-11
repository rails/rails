# frozen_string_literal: true

module ActiveRecord
  module Assertions
    module QueryAssertions
      def assert_queries(expected_count, matcher: nil, &block)
        ActiveRecord::Base.connection.materialize_transactions

        queries = []
        ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
          queries << payload[:sql] if %w[ SCHEMA TRANSACTION ].exclude?(payload[:name]) && (matcher.nil? || payload[:sql].match(matcher))
        end

        result = _assert_nothing_raised_or_warn("assert_queries", &block)
        assert_equal expected_count, queries.size, "#{queries.size} instead of #{expected_count} queries were executed. Queries: #{queries.join("\n\n")}"
        result
      end

      def assert_no_queries(&block)
        assert_queries(0, &block)
      end
    end
  end
end
