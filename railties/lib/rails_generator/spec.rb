module Rails
  module Generator
    # A spec knows where a generator was found and how to instantiate it.
    # Metadata include the generator's name, its base path, and the source
    # which yielded it (PathSource, GemPathSource, etc.)
    class Spec
      attr_reader :name, :path, :source

      def initialize(name, path, source)
        @name, @path, @source = name, path, source
      end

      # Look up the generator class.  Require its class file, find the class
      # in ObjectSpace, tag it with this spec, and return.
      def klass
        unless @klass
          require class_file
          @klass = lookup_class
          @klass.spec = self
        end
        @klass
      end

      def class_file
        "#{path}/#{name}_generator.rb"
      end

      def class_name
        "#{name.camelize}Generator"
      end

      private
        # Search for the first Class descending from Rails::Generator::Base
        # whose name matches the requested class name.
        def lookup_class
          ObjectSpace.each_object(Class) do |obj|
            return obj if obj.ancestors.include?(Rails::Generator::Base) and
                          obj.name.split('::').last == class_name
          end
          raise NameError, "Missing #{class_name} class in #{class_file}"
        end
    end
  end
end
