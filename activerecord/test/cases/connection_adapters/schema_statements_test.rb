# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class SchemaStatementsTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      WHOLE_SCHEMA_READERS = %i[
        columns indexes primary_keys foreign_keys table_options
        check_constraints exclusion_constraints unique_constraints
      ].freeze

      def setup
        @connection = ActiveRecord::Base.lease_connection
      end

      def test_a_list_reads_exactly_the_tables_it_is_given
        some = @connection.tables.sort.first(3)

        each_reader do |reader|
          assert_equal some.sort, @connection.public_send(reader, some).keys.sort,
            "#{reader} did not read exactly the tables it was given"
        end
      end

      def test_a_list_returns_what_asking_for_each_table_returns
        tables = @connection.tables

        each_reader do |reader|
          listed = @connection.public_send(reader, tables)

          tables.each do |table|
            one = attributes(@connection.public_send(reader, table))
            many = attributes(listed.fetch(table))

            # An adapter with nothing to report for a reader answers nil for every table.
            if one.nil?
              assert_nil many, "#{reader} disagreed about #{table}"
            else
              assert_equal one, many, "#{reader} disagreed about #{table}"
            end
          end
        end
      end

      def test_a_list_does_not_scale_with_the_number_of_tables
        tables = @connection.tables
        assert_operator tables.size, :>, 10, "need a decent number of tables for this to mean anything"

        queries = {}
        each_reader do |reader|
          queries[reader] = capture_sql(include_schema: true) { @connection.public_send(reader, tables) }.size
        end

        cheaper_than_one_read_per_table = queries.select { |_, count| count < tables.size }

        if cheaper_than_one_read_per_table.empty?
          skip "#{@connection.adapter_name} reads every table one at a time"
        end

        cheaper_than_one_read_per_table.each do |reader, count|
          assert_operator count, :<=, 2,
            "#{reader} took #{count} queries to read #{tables.size} tables; expected a constant few"
        end
      end

      def test_an_empty_list_reads_nothing
        each_reader do |reader|
          queries = capture_sql(include_schema: true) do
            assert_empty @connection.public_send(reader, [])
          end

          assert_empty queries, "#{reader}([]) queried the database"
        end
      end

      def test_a_list_keys_a_qualified_name_by_the_name_it_was_given
        qualifier = schema_qualifier
        skip "#{@connection.adapter_name} does not qualify table names" unless qualifier

        each_reader do |reader|
          # A table with nothing to report would compare empty to empty.
          table = @connection.tables.sort.find { |name| @connection.public_send(reader, name).any? }
          next unless table

          qualified = "#{qualifier}.#{table}"
          listed = @connection.public_send(reader, [qualified])

          assert_equal [qualified], listed.keys, "#{reader} did not key by the name it was given"
          assert_equal attributes(@connection.public_send(reader, qualified)),
            attributes(listed.fetch(qualified)),
            "#{reader} disagreed about #{qualified}"
          assert_not_empty listed.fetch(qualified), "#{reader} found nothing for #{qualified}"
        end
      end

      def test_a_list_reads_columns_in_the_same_order_as_one_table
        tables = @connection.tables.sort.first(5)
        listed = @connection.columns(tables)

        tables.each do |table|
          assert_equal @connection.columns(table).map(&:name), listed.fetch(table).map(&:name),
            "columns for #{table} came back in a different order"
        end
      end

      private
        def each_reader
          checked = 0

          WHOLE_SCHEMA_READERS.each do |reader|
            next unless @connection.respond_to?(reader)
            next unless supported?(reader)

            checked += 1
            yield reader
          end

          skip "#{@connection.adapter_name} has none of #{WHOLE_SCHEMA_READERS.join(", ")}" if checked.zero?
        end

        # SQLite has no schema qualifier its readers understand.
        def schema_qualifier
          case @connection.adapter_name
          when /postgres/i then @connection.current_schema
          when /mysql|trilogy/i then @connection.current_database
          end
        end

        def supported?(reader)
          case reader
          when :check_constraints then @connection.supports_check_constraints?
          when :exclusion_constraints then @connection.supports_exclusion_constraints?
          when :unique_constraints then @connection.supports_unique_constraints?
          else true
          end
        end

        # Definitions inherit Object#==, which compares identity, so compare the
        # attributes the dumper actually reads instead.
        def attributes(value)
          case value
          when Array
            value.all?(String) ? value : value.map { |element| attributes(element) }.sort_by(&:to_s)
          when Hash, String, nil then value
          else value.instance_variables.sort.index_with { |ivar| value.instance_variable_get(ivar) }
          end
        end
    end
  end
end
