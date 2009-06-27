module TestUnit
  module Generators
    class ModelGenerator < Base
      argument :attributes, :type => :hash, :default => {}, :banner => "field:type, field:type"

      check_class_collision :suffix => "Test"
      conditional_class_option :fixture

      def create_test_file
        template 'unit_test.rb', File.join('test/unit', class_path, "#{file_name}_test.rb")
      end

      invoke_for :fixture_replacement

      def create_fixture_file
        if options[:fixture] && options[:fixture_replacement].nil?
          template 'fixtures.yml', File.join('test/fixtures', "#{table_name}.yml")
        end
      end
    end
  end
end
