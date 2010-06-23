require 'rails/generators/test_unit'

module TestUnit
  module Generators
    class ModelGenerator < Base
      argument :attributes, :type => :array, :default => [], :banner => "field:type field:type"
      class_option :fixture, :type => :boolean

      check_class_collision :suffix => "Test"

      def create_test_file
        template 'unit_test.rb', File.join('test/unit', class_path, "#{file_name}_test.rb")
      end

      hook_for :fixture_replacement

      def create_fixture_file
        if options[:fixture] && options[:fixture_replacement].nil?
          template 'fixtures.yml', File.join('test/fixtures', class_path, "#{plural_file_name}.yml")
        end
      end
    end
  end
end
