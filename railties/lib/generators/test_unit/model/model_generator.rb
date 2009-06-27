module TestUnit
  module Generators
    class ModelGenerator < Base
      argument :attributes, :type => :hash, :default => {}, :banner => "field:type, field:type"

      check_class_collision :suffix => "Test"

      # TODO Add DEFAULTS support
      class_option :skip_fixture, :type => :boolean, :default => false,
                   :desc => "Don't generate a fixture file"

      def create_test_file
        template 'unit_test.rb', File.join('test/unit', class_path, "#{file_name}_test.rb")
      end

      # TODO Add fixture replacement support
      def create_fixture_file
        unless options[:skip_fixture]
          template 'fixtures.yml', File.join('test/fixtures', "#{table_name}.yml")
        end
      end
    end
  end
end
