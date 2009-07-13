module Rails
  module Generators
    class GeneratorGenerator < NamedBase
      check_class_collision :suffix => "Generator"

      def copy_generator_file
        template "generator.rb", generator_dir("#{file_name}_generator.rb")
      end

      def copy_usage_file
        template "USAGE", generator_dir("USAGE")
      end

      def create_templates_dir
        empty_directory generator_dir("templates")
      end

      protected

        def generator_dir(join)
          File.join("lib", "generators", file_name, join)
        end

    end
  end
end
