module Rails
  module Generators
    class GeneratorGenerator < NamedBase
      check_class_collision :suffix => "Generator"

      class_option :namespace, :type => :boolean, :default => true,
                               :desc => "Namespace generator under lib/generators/name"

      def create_generator_files
        directory '.', generator_dir
      end

      protected

        def generator_dir
          if options[:namespace]
            File.join("lib", "generators", file_name)
          else
            File.join("lib", "generators")
          end
        end

    end
  end
end
