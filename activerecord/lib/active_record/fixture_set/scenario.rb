# frozen_string_literal: true

module ActiveRecord
  class FixtureSet
    class Scenario # :nodoc:
      include Enumerable

      def self.open(file)
        x = new file
        block_given? ? yield(x) : x
      end

      def initialize(file, loaded_fixture_ids = nil)
        @file = file
        @loaded_fixture_ids = loaded_fixture_ids || {}
      end

      def each(&block)
        sets.each(&block)
      end

      def [](table_name)
        sets[table_name]
      end

      private
        def sets
          @sets ||= raw_rows.each_with_object({}) do |(table_name, rows), result|
            config_row = Config.validate_config_row(@file, rows.fetch("_fixture", {}))
            validate_fixture_identifiers(table_name, rows.keys)

            result[table_name] = Config.new(
              table_name: table_name,
              model_class: config_row["model_class"],
              ignored_fixtures: config_row["ignore"],
              rows: rows.reject { |k, v| k == "_fixture" }
            )
          end
        end

        def raw_rows
          @raw_rows ||= begin
            Config.read_fixture_file(@file) || []
          rescue RuntimeError => error
            raise Fixture::FormatError, error.message
          end
        end

        def validate_fixture_identifiers(fs_table_name, fs_names)
          return unless @loaded_fixture_ids[fs_table_name]

          if (existing_identifiers = @loaded_fixture_ids[fs_table_name] & fs_names).any?
            raise Fixture::FixtureError, "Fixture scenarios cannot override already existing fixtures: #{existing_identifiers.to_sentence}"
          end
        end
    end
  end
end
