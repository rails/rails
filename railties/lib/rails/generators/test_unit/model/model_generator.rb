require 'rails/generators/test_unit'

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class ModelGenerator < Base # :nodoc:

      RESERVED_YAML_KEYWORDS = %w(y yes n no true false on off null)

      argument :attributes, type: :array, default: [], banner: "field:type field:type"
      class_option :fixture, type: :boolean

      check_class_collision suffix: "Test"

      def create_test_file
        template 'unit_test.rb', File.join('test/models', class_path, "#{file_name}_test.rb")
      end

      hook_for :fixture_replacement

      def create_fixture_file
        if options[:fixture] && options[:fixture_replacement].nil?
          template 'fixtures.yml', File.join('test/fixtures', class_path, "#{fixture_file_name}.yml")
        end
      end

      private
        def yaml_key_value(key, value)
          if RESERVED_YAML_KEYWORDS.include?(key.downcase)
            "'#{key}': #{value}"
          else
            "#{key}: #{value}"
          end
        end
    end
  end
end
