module Rails
  module Generators
    class GeneratorGenerator < NamedBase # :nodoc:
      check_class_collision suffix: "Generator"

      class_option :namespace, type: :boolean, default: true,
                               desc: "Namespace generator under lib/generators/name"

      def create_generator_files
        directory ".", generator_dir
      end

      hook_for :test_framework

      protected

        def generator_dir
          if options[:namespace]
            File.join("lib", "generators", regular_class_path, file_name)
          else
            File.join("lib", "generators", regular_class_path)
          end
        end

    end
  end
end
