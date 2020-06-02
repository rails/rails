# frozen_string_literal: true

require "active_support/configuration_file"

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

      private
        def rows
          @rows ||= raw_rows.reject { |fixture_name, _| fixture_name == "_fixture" }
        end

        def config_row
          @config_row ||= begin
            row = raw_rows.find { |fixture_name, _| fixture_name == "_fixture" }
            if row
              row.last
            else
              { 'model_class': nil, 'ignore': nil }
            end
          end
        end

        def raw_rows
          @raw_rows ||= begin
            data = ActiveSupport::ConfigurationFile.parse(@file, context:
              ActiveRecord::FixtureSet::RenderContext.create_subclass.new.get_binding)
            data ? validate(data).to_a : []
          rescue RuntimeError => error
            raise Fixture::FormatError, error.message
          end
        end

        # Validate our unmarshalled data.
        def validate(data)
          unless Hash === data || YAML::Omap === data
            raise Fixture::FormatError, "fixture is not a hash: #{@file}"
          end

          invalid = data.reject { |_, row| Hash === row }
          if invalid.any?
            raise Fixture::FormatError, "fixture key is not a hash: #{@file}, keys: #{invalid.keys.inspect}"
          end
          data
        end
    end
  end
end
