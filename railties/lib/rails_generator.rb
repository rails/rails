require 'fileutils'

module Rails
  module Generator
    class GeneratorError < StandardError; end
    class UsageError < GeneratorError; end

    CONTRIB_ROOT = "#{RAILS_ROOT}/script/generators"
    BUILTIN_ROOT = "#{File.dirname(__FILE__)}/../generators"
    DEFAULT_SEARCH_PATHS = [CONTRIB_ROOT, BUILTIN_ROOT]

    class << self
      def instance(name, args = [], search_paths = DEFAULT_SEARCH_PATHS)
        # RAILS_ROOT constant must be set.
        unless Object.const_get(:RAILS_ROOT)
          raise GeneratorError, "RAILS_ROOT must be set.  Did you require 'config/environment'?"
        end

        # Force canonical name.
        name = Inflector.underscore(name.downcase)

        # Search for filesystem path to requested generator.
        unless path = find_generator_path(name, search_paths)
          raise GeneratorError, "#{name} generator not found."
        end

        # Check for templates directory.
        template_root = "#{path}/templates"
        unless File.directory?(template_root)
          raise GeneratorError, "missing template directory #{template_root}"
        end

        # Require class file according to naming convention.
        require "#{path}/#{name}_generator.rb"

        # Find class according to naming convention.  Allow Nesting::In::Modules.
        class_name = Inflector.classify("#{name}_generator")
        unless klass = find_generator_class(name)
          raise GeneratorError, "no #{class_name} class defined in #{path}/#{name}_generator.rb"
        end

        # Instantiate and return generator.
        klass.new(template_root, RAILS_ROOT, search_paths, args)
      end


      def builtin_generators
        generators([BUILTIN_ROOT])
      end

      def contrib_generators
        generators([CONTRIB_ROOT])
      end

      def generators(search_paths)
        generator_paths(search_paths).keys.uniq.sort
      end

      # Find all generator paths.
      def generator_paths(search_paths)
        @paths ||= {}
        unless @paths[search_paths]
          paths = Hash.new { |h,k| h[k] = [] }
          search_paths.each do |path|
            Dir["#{path}/[a-z]*"].each do |dir|
              paths[File.basename(dir)] << dir if File.directory?(dir)
            end
          end
          @paths[search_paths] = paths
        end
        @paths[search_paths]
      end

      def find_generator_path(name, search_paths)
        generator_paths(search_paths)[name].first
      end

      # Find all generator classes.
      def generator_classes
        classes = Hash.new { |h,k| h[k] = [] }
        class_re = /([^:]+)Generator$/
        ObjectSpace.each_object(Class) do |object|
          if md = class_re.match(object.name) and object < Rails::Generator::Base
            classes[Inflector.underscore(md.captures.first)] << object
          end
        end
        classes
      end

      def find_generator_class(name)
        generator_classes[name].first
      end
    end


    # Talk about generators.
    class Base
      attr_reader :template_root, :destination_root, :args, :options,
                  :class_name, :singular_name, :plural_name

      alias_method :file_name,  :singular_name
      alias_method :table_name, :plural_name

      def self.generator_name
        Inflector.underscore(name.gsub('Generator', ''))
      end

      def initialize(template_root, destination_root, search_paths, args)
        @template_root, @destination_root = template_root, destination_root
        usage if args.empty?
        @search_paths, @original_args = search_paths, args.dup
        @class_name, @singular_name, @plural_name = inflect_names(args.shift)
        @options = extract_options!(args)
        @args = args
      end

      # Checks whether the class name that was assigned to this generator
      # would cause a collision with a Class, Module or other constant
      # that is already used up by Ruby or RubyOnRails.
      def collision_with_builtin?
        builtin = Object.const_get(full_class_name) rescue nil
        type = case builtin
          when Class: "Class"
          when Module: "Module"
          else "Constant"
        end

        if builtin then
          "Sorry, you can't have a #{self.class.generator_name} named " +
          "'#{full_class_name}' because Ruby or Rails already has a #{type} with that name.\n" + 
          "Please rerun the generator with a different name."
        end
      end

      # Returns the complete name that the resulting Class would have.
      # Used in collision_with_builtin(). The default guess is that it is
      # the same as class_name. Override this in your generator in case
      # it is wrong.
      def full_class_name
        class_name
      end

      protected
        # Look up another generator with the same arguments.
        def generator(name)
          Rails::Generator.instance(name, @original_args, @search_paths)
        end

        # Generate a file for a Rails application using an ERuby template.
        # Looks up and evalutes a template by name and writes the result
        # to a file relative to +destination_root+.  The template
        # is evaluated in the context of the optional eval_binding argument.
        #
        # The ERB template uses explicit trim mode to best control the
        # proliferation of whitespace in generated code.  <%- trims leading
        # whitespace; -%> trims trailing whitespace including one newline.
        def template(template_name, destination_path, eval_binding = nil)
          # Determine full paths for source and destination files.
          template_path     = find_template_path(template_name)
          destination_path  = File.join(destination_root, destination_path)

          # Create destination directories.
          FileUtils.mkdir_p(File.dirname(destination_path))

          # Render template and write result.
          eval_binding ||= binding
          contents = ERB.new(File.read(template_path), nil, '-').result(eval_binding)
          File.open(destination_path, 'w') { |file| file.write(contents) }
        end

        def usage
          raise UsageError.new, File.read(usage_path)
        end

      private
        def find_template_path(template_name)
          name, path = template_name.split('/', 2)
          if path.nil?
            File.join(template_root, name)
          elsif generator_path = Rails::Generator.find_generator_path(name, @search_paths)
            File.join(generator_path, 'templates', path)
          end
        end

        def inflect_names(name)
          camel  = Inflector.camelize(Inflector.underscore(name))
          under  = Inflector.underscore(camel)
          plural = Inflector.pluralize(under)
          [camel, under, plural]
        end

        def extract_options!(args)
          if args.last.is_a?(Hash) then args.pop else {} end
        end

        def usage_path
          "#{template_root}/../USAGE"
        end
    end
  end
end
