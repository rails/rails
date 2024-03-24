# frozen_string_literal: true

module ActiveRecord
  module Assertions
    module QueryAssertions
      # Asserts that the number of SQL queries executed in the given block matches the expected count.
      #
      #   # Check for exact number of queries
      #   assert_queries_count(1) { Post.first }
      #
      #   # Check for any number of queries
      #   assert_queries_count { Post.first }
      #
      # If the +:include_schema+ option is provided, any queries (including schema related) are counted.
      #
      #   assert_queries_count(1, include_schema: true) { Post.columns }
      #
      def assert_queries_count(count = nil, include_schema: false, &block)
        ActiveRecord::Base.lease_connection.materialize_transactions

        counter = SQLCounter.new
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          result = _assert_nothing_raised_or_warn("assert_queries_count", &block)
          queries = include_schema ? counter.log_all : counter.log
          if count
            assert_equal count, queries.size, "#{queries.size} instead of #{count} queries were executed. Queries: #{queries.join("\n\n")}"
          else
            assert_operator queries.size, :>=, 1, "1 or more queries expected, but none were executed.#{queries.empty? ? '' : "\nQueries:\n#{queries.join("\n")}"}"
          end
          result
        end
      end

      # Asserts that no SQL queries are executed in the given block.
      #
      #   assert_no_queries { post.comments }
      #
      # If the +:include_schema+ option is provided, any queries (including schema related) are counted.
      #
      #   assert_no_queries(include_schema: true) { Post.columns }
      #
      def assert_no_queries(include_schema: false, &block)
        assert_queries_count(0, include_schema: include_schema, &block)
      end

      # Asserts that the SQL queries executed in the given block match expected pattern.
      #
      #   # Check for exact number of queries
      #   assert_queries_match(/LIMIT \?/, count: 1) { Post.first }
      #
      #   # Check for any number of queries
      #   assert_queries_match(/LIMIT \?/) { Post.first }
      #
      # If the +:include_schema+ option is provided, any queries (including schema related)
      #   that match the matcher are considered.
      #
      #   assert_queries_match(/FROM pg_attribute/i, include_schema: true) { Post.columns }
      #
      def assert_queries_match(match, count: nil, include_schema: false, &block)
        ActiveRecord::Base.lease_connection.materialize_transactions

        counter = SQLCounter.new
        ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
          result = _assert_nothing_raised_or_warn("assert_queries_match", &block)
          queries = include_schema ? counter.log_all : counter.log
          matched_queries = queries.select { |query| match === query }

          if count
            assert_equal count, matched_queries.size, "#{matched_queries.size} instead of #{count} queries were executed.#{queries.empty? ? '' : "\nQueries:\n#{queries.join("\n")}"}"
          else
            assert_operator matched_queries.size, :>=, 1, "1 or more queries expected, but none were executed.#{queries.empty? ? '' : "\nQueries:\n#{queries.join("\n")}"}"
          end

          result
        end
      end

      # Asserts that no SQL queries matching the pattern are executed in the given block.
      #
      #   assert_no_queries_match(/SELECT/i) { post.comments }
      #
      # If the +:include_schema+ option is provided, any queries (including schema related)
      #   that match the matcher are counted.
      #
      #   assert_no_queries_match(/FROM pg_attribute/i, include_schema: true) { Post.columns }
      #
      def assert_no_queries_match(match, include_schema: false, &block)
        assert_queries_match(match, count: 0, include_schema: include_schema, &block)
      end

      class SQLCounter # :nodoc:
        attr_reader :log_full, :log_all

        def initialize
          @log_full = []
          @log_all = []
        end

        def log
          @log_full.map(&:first)
        end

        def call(*, payload)
          return if payload[:cached]

          sql = payload[:sql]
          @log_all << sql

          unless payload[:name] == "SCHEMA"
            bound_values = (payload[:binds] || []).map do |value|
              value = value.value_for_database if value.respond_to?(:value_for_database)
              value
            end

            @log_full << [sql, bound_values]
          end
        end
      end
    end
  end
end
