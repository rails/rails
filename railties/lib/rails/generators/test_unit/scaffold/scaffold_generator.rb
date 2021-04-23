# frozen_string_literal: true

require "rails/generators/test_unit"
require "rails/generators/resource_helpers"

module TestUnit # :nodoc:
  module Generators # :nodoc:
    class ScaffoldGenerator < Base # :nodoc:
      include Rails::Generators::ResourceHelpers

      check_class_collision suffix: "ControllerTest"

      class_option :api, type: :boolean,
                         desc: "Generates API functional tests"

      class_option :system_tests, type: :string,
                         desc: "Skip system test files"

      argument :attributes, type: :array, default: [], banner: "field:type field:type"

      def create_test_files
        template_file = options.api? ? "api_functional_test.rb" : "functional_test.rb"
        template template_file,
                 File.join("test/controllers", controller_class_path, "#{controller_file_name}_controller_test.rb")

        if !options.api? && options[:system_tests]
          template "system_test.rb", File.join("test/system", class_path, "#{file_name.pluralize}_test.rb")
        end
      end

      def fixture_name
        @fixture_name ||=
          if mountable_engine?
            (namespace_dirs + [table_name]).join("_")
          else
            table_name
          end
      end

      private
        def attributes_string
          attributes_hash.map { |k, v| "#{k}: #{v}" }.join(", ")
        end

        def attributes_hash
          return {} if attributes_names.empty?

          attributes_names.filter_map do |name|
            if %w(password password_confirmation).include?(name) && attributes.any?(&:password_digest?)
              ["#{name}", "'secret'"]
            elsif !virtual?(name)
              ["#{name}", "@#{singular_table_name}.#{name}"]
            end
          end.sort.to_h
        end

        def boolean?(name)
          attribute = attributes.find { |attr| attr.name == name }
          attribute&.type == :boolean
        end

        def virtual?(name)
          attribute = attributes.find { |attr| attr.name == name }
          attribute&.virtual?
        end
    end
  end
end
