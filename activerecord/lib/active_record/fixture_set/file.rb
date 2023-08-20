# frozen_string_literal: true

module ActiveRecord
  class FixtureSet
    class File # :nodoc:
      include Enumerable

      ##
      # Open a fixture file named +file+.  When called with a block, the block
      # is called with the filehandle and the filehandle is automatically closed
      # when the block finishes.
      def self.open(file)
        x = new file
        block_given? ? yield(x) : x
      end

      def initialize(file)
        @file = file
      end

      def each(&block)
        rows.each(&block)
      end

      def model_class
        config_row["model_class"]
      end

      def ignored_fixtures
        config_row["ignore"]
      end

      def fixtures_config
        Config.new(
          model_class: model_class,
          ignored_fixtures: ignored_fixtures,
          rows: to_h
        )
      end

      private
        def rows
          @rows ||= raw_rows.reject { |fixture_name, _| fixture_name == "_fixture" }
        end

        def config_row
          @config_row ||= begin
            row = raw_rows.find { |fixture_name, _| fixture_name == "_fixture" }
            if row
              Config.validate_config_row(@file, row.last)
            else
              { 'model_class': nil, 'ignore': nil }
            end
          end
        end

        def raw_rows
          @raw_rows ||= begin
            Config.read_fixture_file(@file) || []
          rescue RuntimeError => error
            raise Fixture::FormatError, error.message
          end
        end
    end
  end
end
