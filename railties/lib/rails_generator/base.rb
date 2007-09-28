require File.dirname(__FILE__) + '/options'
require File.dirname(__FILE__) + '/manifest'
require File.dirname(__FILE__) + '/spec'
require File.dirname(__FILE__) + '/generated_attribute'

module Rails
  # Rails::Generator is a code generation platform tailored for the Rails
  # web application framework.  Generators are easily invoked within Rails
  # applications to add and remove components such as models and controllers.
  # New generators are easy to create and may be distributed as RubyGems,
  # tarballs, or Rails plugins for inclusion system-wide, per-user, 
  # or per-application.
  #
  # For actual examples see the rails_generator/generators directory in the
  # Rails source (or the +railties+ directory if you have frozen the Rails
  # source in your application).
  #
  # Generators may subclass other generators to provide variations that
  # require little or no new logic but replace the template files.
  #
  # For a RubyGem, put your generator class and templates in the +lib+
  # directory. For a Rails plugin, make a +generators+ directory at the 
  # root of your plugin.
  #
  # The layout of generator files can be seen in the built-in 
  # +controller+ generator:
  #   
  #   generators/
  #     controller/
  #       controller_generator.rb
  #       templates/
  #         controller.rb
  #         functional_test.rb
  #         helper.rb
  #         view.rhtml
  #
  # The directory name (+controller+) matches the name of the generator file
  # (controller_generator.rb) and class (+ControllerGenerator+). The files
  # that will be copied or used as templates are stored in the +templates+
  # directory.
  #
  # The filenames of the templates don't matter, but choose something that
  # will be self-explanatory since you will be referencing these in the 
  # +manifest+ method inside your generator subclass.
  #
  # 
  module Generator
    class GeneratorError < StandardError; end
    class UsageError < GeneratorError; end


    # The base code generator is bare-bones.  It sets up the source and
    # destination paths and tells the logger whether to keep its trap shut.
    #
    # It's useful for copying files such as stylesheets, images, or 
    # javascripts.
    #
    # For more comprehensive template-based passive code generation with
    # arguments, you'll want Rails::Generator::NamedBase. 
    #
    # Generators create a manifest of the actions they perform then hand
    # the manifest to a command which replays the actions to do the heavy
    # lifting (such as checking for existing files or creating directories
    # if needed). Create, destroy, and list commands are included.  Since a
    # single manifest may be used by any command, creating new generators is
    # as simple as writing some code templates and declaring what you'd like
    # to do with them.
    #
    # The manifest method must be implemented by subclasses, returning a
    # Rails::Generator::Manifest.  The +record+ method is provided as a
    # convenience for manifest creation.  Example:
    #
    #   class StylesheetGenerator < Rails::Generator::Base
    #     def manifest
    #       record do |m|
    #         m.directory('public/stylesheets')
    #         m.file('application.css', 'public/stylesheets/application.css')
    #       end
    #     end
    #   end
    #
    # See Rails::Generator::Commands::Create for a list of methods available
    # to the manifest.
    class Base
      include Options

      # Declare default options for the generator.  These options
      # are inherited to subclasses.
      default_options :collision => :ask, :quiet => false

      # A logger instance available everywhere in the generator.
      cattr_accessor :logger

      # Every generator that is dynamically looked up is tagged with a
      # Spec describing where it was found.
      class_inheritable_accessor :spec

      attr_reader :source_root, :destination_root, :args

      def initialize(runtime_args, runtime_options = {})
        @args = runtime_args
        parse!(@args, runtime_options)

        # Derive source and destination paths.
        @source_root = options[:source] || File.join(spec.path, 'templates')
        if options[:destination]
          @destination_root = options[:destination]
        elsif defined? ::RAILS_ROOT
          @destination_root = ::RAILS_ROOT
        end

        # Silence the logger if requested.
        logger.quiet = options[:quiet]

        # Raise usage error if help is requested.
        usage if options[:help]
      end

      # Generators must provide a manifest.  Use the +record+ method to create
      # a new manifest and record your generator's actions.
      def manifest
        raise NotImplementedError, "No manifest for '#{spec.name}' generator."
      end

      # Return the full path from the source root for the given path.
      # Example for source_root = '/source':
      #   source_path('some/path.rb') == '/source/some/path.rb'
      #
      # The given path may include a colon ':' character to indicate that
      # the file belongs to another generator.  This notation allows any
      # generator to borrow files from another.  Example:
      #   source_path('model:fixture.yml') = '/model/source/path/fixture.yml'
      def source_path(relative_source)
        # Check whether we're referring to another generator's file.
        name, path = relative_source.split(':', 2)

        # If not, return the full path to our source file.
        if path.nil?
          File.join(source_root, name)

        # Otherwise, ask our referral for the file.
        else
          # FIXME: this is broken, though almost always true.  Others'
          # source_root are not necessarily the templates dir.
          File.join(self.class.lookup(name).path, 'templates', path)
        end
      end

      # Return the full path from the destination root for the given path.
      # Example for destination_root = '/dest':
      #   destination_path('some/path.rb') == '/dest/some/path.rb'
      def destination_path(relative_destination)
        File.join(destination_root, relative_destination)
      end

      protected
        # Convenience method for generator subclasses to record a manifest.
        def record
          Rails::Generator::Manifest.new(self) { |m| yield m }
        end

        # Override with your own usage banner.
        def banner
          "Usage: #{$0} #{spec.name} [options]"
        end

        # Read USAGE from file in generator base path.
        def usage_message
          File.read(File.join(spec.path, 'USAGE')) rescue ''
        end
    end


    # The base generator for named components: models, controllers, mailers,
    # etc.  The target name is taken as the first argument and inflected to
    # singular, plural, class, file, and table forms for your convenience.
    # The remaining arguments are aliased to +actions+ as an array for 
    # controller and mailer convenience.
    #
    # Several useful local variables and methods are populated in the 
    # +initialize+ method. See below for a list of Attributes and
    # External Aliases available to both the manifest and to all templates.    
    #
    # If no name is provided, the generator raises a usage error with content
    # optionally read from the USAGE file in the generator's base path.
    #
    # For example, the +controller+ generator takes the first argument as 
    # the name of the class and subsequent arguments as the names of
    # actions to be generated:
    #
    #   ./script/generate controller Article index new create
    #
    # See Rails::Generator::Base for a discussion of manifests, 
    # Rails::Generator::Commands::Create for methods available to the manifest,
    # and Rails::Generator for a general discussion of generators.
    class NamedBase < Base
      attr_reader   :name, :class_name, :singular_name, :plural_name, :table_name
      attr_reader   :class_path, :file_path, :class_nesting, :class_nesting_depth
      alias_method  :file_name,  :singular_name
      alias_method  :actions, :args

      def initialize(runtime_args, runtime_options = {})
        super

        # Name argument is required.
        usage if runtime_args.empty?

        @args = runtime_args.dup
        base_name = @args.shift
        assign_names!(base_name)
      end

      protected
        # Override with your own usage banner.
        def banner
          "Usage: #{$0} #{spec.name} #{spec.name.camelize}Name [options]"
        end
    
        def attributes
          @attributes ||= @args.collect do |attribute|
            Rails::Generator::GeneratedAttribute.new(*attribute.split(":"))
          end
        end


      private
        def assign_names!(name)
          @name = name
          base_name, @class_path, @file_path, @class_nesting, @class_nesting_depth = extract_modules(@name)
          @class_name_without_nesting, @singular_name, @plural_name = inflect_names(base_name)
          @table_name = (!defined?(ActiveRecord::Base) || ActiveRecord::Base.pluralize_table_names) ? plural_name : singular_name
          if @class_nesting.empty?
            @class_name = @class_name_without_nesting
          else
            @table_name = @class_nesting.underscore << "_" << @table_name
            @class_name = "#{@class_nesting}::#{@class_name_without_nesting}"
          end
        end

        # Extract modules from filesystem-style or ruby-style path:
        #   good/fun/stuff
        #   Good::Fun::Stuff
        # produce the same results.
        def extract_modules(name)
          modules = name.include?('/') ? name.split('/') : name.split('::')
          name    = modules.pop
          path    = modules.map { |m| m.underscore }
          file_path = (path + [name.underscore]).join('/')
          nesting = modules.map { |m| m.camelize }.join('::')
          [name, path, file_path, nesting, modules.size]
        end

        def inflect_names(name)
          camel  = name.camelize
          under  = camel.underscore
          plural = under.pluralize
          [camel, under, plural]
        end
    end
  end
end
