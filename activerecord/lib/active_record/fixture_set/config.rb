# frozen_string_literal: true

require "active_support/configuration_file"

module ActiveRecord
  class FixtureSet
    Config = Struct.new(:table_name, :ignored_fixtures, :model_class, :rows, keyword_init: true) do # :nodoc:
      def self.read_fixture_file(file)
        data = ActiveSupport::ConfigurationFile.parse(file,
          context: ActiveRecord::FixtureSet::RenderContext.create_subclass.new.get_binding)

        # Validate our unmarshalled data.
        data ? validate_data_format(file, data).to_a : nil
      end

      def self.validate_data_format(file, data)
        unless Hash === data || YAML::Omap === data
          raise Fixture::FormatError, "fixture is not a hash: #{file}"
        end

        invalid = data.reject { |_, row| Hash === row }
        if invalid.any?
          raise Fixture::FormatError, "fixture key is not a hash: #{file}, keys: #{invalid.keys.inspect}"
        end
        data
      end

      def self.validate_config_row(file, data)
        unless Hash === data
          raise Fixture::FormatError, "Invalid `_fixture` section: `_fixture` must be a hash: #{file}"
        end

        begin
          data.assert_valid_keys("model_class", "ignore")
        rescue ArgumentError => error
          raise Fixture::FormatError, "Invalid `_fixture` section: #{error.message}: #{file}"
        end
        data
      end

      def +(other_config)
        self.rows ||= {}
        self.class.new(
          table_name: table_name || other_config.table_name,
          model_class: model_class || other_config.model_class,
          ignored_fixtures: ignored_fixtures || other_config.ignored_fixtures,
          rows: rows.merge(other_config.rows),
        )
      end
    end
  end
end
