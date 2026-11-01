# frozen_string_literal: true

require "active_record/fixture_set/table_row"
require "active_record/fixture_set/model_metadata"

module ActiveRecord
  class FixtureSet
    class TableRows # :nodoc:
      def initialize(table_name, model_class:, fixtures:)
        @model_class = model_class

        # track any join tables we need to insert later
        @tables = Hash.new { |h, table| h[table] = [] }

        # ensure this table is loaded before any HABTM associations
        @tables[table_name] = nil

        build_table_rows_from(table_name, fixtures)
      end

      attr_reader :tables, :model_class

      def to_hash
        @tables.transform_values { |rows| rows.map(&:to_hash) }
      end

      def model_metadata
        @model_metadata ||= ModelMetadata.new(model_class)
      end

      private
        def build_table_rows_from(table_name, fixtures)
          now = ActiveRecord.default_timezone == :utc ? Time.now.utc : Time.now

          @tables[table_name] = fixtures.map do |label, fixture|
            TableRow.new(
              fixture,
              table_rows: self,
              label: label,
              now: now,
            )
          end
        end
    end
  end
end
