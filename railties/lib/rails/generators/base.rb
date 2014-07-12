begin
  require 'thor/group'
rescue LoadError
  puts "Thor is not available.\nIf you ran this command from a git checkout " \
       "of Rails, please make sure thor is installed,\nand run this command " \
       "as `ruby #{$0} #{(ARGV | ['--dev']).join(" ")}`"
  exit
end

module Rails
  module Generators
    class Error < Thor::Error # :nodoc:
    end

    class Base < Thor::Group
      include Thor::Actions
      include Rails::Generators::Actions

      add_runtime_options!
      strict_args_position!

      # Returns the source root for this generator using default_source_root as default.
      def self.source_root(path=nil)
        @_source_root = path if path
        @_source_root ||= default_source_root
      end

      # Tries to get the description from a USAGE file one folder above the source
      # root otherwise uses a default description.
      def self.desc(description=nil)
        return super if description

        @desc ||= if usage_path
          ERB.new(File.read(usage_path)).result(binding)
        else
          "Description:\n    Create #{base_name.humanize.downcase} files for #{generator_name} generator."
        end
      end

      # Convenience method to get the namespace from the class name. It's the
      # same as Thor default except that the Generator at the end of the class
      # is removed.
      def self.namespace(name=nil)
        return super if name
        @namespace ||= super.sub(/_generator$/, '').sub(/:generators:/, ':')
      end

      # Convenience method to hide this generator from the available ones when
      # running rails generator command.
      def self.hide!
        Rails::Generators.hide_namespace self.namespace
      end

      # Invoke a generator based on the value supplied by the user to the
      # given option named "name". A class option is created when this method
      # is invoked and you can set a hash to customize it.
      #
      # ==== Examples
      #
      #   module Rails::Generators
      #     class ControllerGenerator < Base
      #       hook_for :test_framework, aliases: "-t"
      #     end
      #   end
      #
      # The example above will create a test framework option and will invoke
      # a generator based on the user supplied value.
      #
      # For example, if the user invoke the controller generator as:
      #
      #   rails generate controller Account --test-framework=test_unit
      #
      # The controller generator will then try to invoke the following generators:
      #
      #   "rails:test_unit", "test_unit:controller", "test_unit"
      #
      # Notice that "rails:generators:test_unit" could be loaded as well, what
      # Rails looks for is the first and last parts of the namespace. This is what
      # allows any test framework to hook into Rails as long as it provides any
      # of the hooks above.
      #
      # ==== Options
      #
      # The first and last part used to find the generator to be invoked are
      # guessed based on class invokes hook_for, as noticed in the example above.
      # This can be customized with two options: :in and :as.
      #
      # Let's suppose you are creating a generator that needs to invoke the
      # controller generator from test unit. Your first attempt is:
      #
      #   class AwesomeGenerator < Rails::Generators::Base
      #     hook_for :test_framework
      #   end
      #
      # The lookup in this case for test_unit as input is:
      #
      #   "test_unit:awesome", "test_unit"
      #
      # Which is not the desired lookup. You can change it by providing the
      # :as option:
      #
      #   class AwesomeGenerator < Rails::Generators::Base
      #     hook_for :test_framework, as: :controller
      #   end
      #
      # And now it will lookup at:
      #
      #   "test_unit:controller", "test_unit"
      #
      # Similarly, if you want it to also lookup in the rails namespace, you just
      # need to provide the :in value:
      #
      #   class AwesomeGenerator < Rails::Generators::Base
      #     hook_for :test_framework, in: :rails, as: :controller
      #   end
      #
      # And the lookup is exactly the same as previously:
      #
      #   "rails:test_unit", "test_unit:controller", "test_unit"
      #
      # ==== Switches
      #
      # All hooks come with switches for user interface. If you do not want
      # to use any test framework, you can do:
      #
      #   rails generate controller Account --skip-test-framework
      #
      # Or similarly:
      #
      #   rails generate controller Account --no-test-framework
      #
      # ==== Boolean hooks
      #
      # In some cases, you may want to provide a boolean hook. For example, webrat
      # developers might want to have webrat available on controller generator.
      # This can be achieved as:
      #
      #   Rails::Generators::ControllerGenerator.hook_for :webrat, type: :boolean
      #
      # Then, if you want webrat to be invoked, just supply:
      #
      #   rails generate controller Account --webrat
      #
      # The hooks lookup is similar as above:
      #
      #   "rails:generators:webrat", "webrat:generators:controller", "webrat"
      #
      # ==== Custom invocations
      #
      # You can also supply a block to hook_for to customize how the hook is
      # going to be invoked. The block receives two arguments, an instance
      # of the current class and the class to be invoked.
      #
      # For example, in the resource generator, the controller should be invoked
      # with a pluralized class name. But by default it is invoked with the same
      # name as the resource generator, which is singular. To change this, we
      # can give a block to customize how the controller can be invoked.
      #
      #   hook_for :resource_controller do |instance, controller|
      #     instance.invoke controller, [ instance.name.pluralize ]
      #   end
      #
      def self.hook_for(*names, &block)
        options = names.extract_options!
        in_base = options.delete(:in) || base_name
        as_hook = options.delete(:as) || generator_name

        names.each do |name|
          unless class_options.key?(name)
            defaults = if options[:type] == :boolean
              { }
            elsif [true, false].include?(default_value_for_option(name, options))
              { banner: "" }
            else
              { desc: "#{name.to_s.humanize} to be invoked", banner: "NAME" }
            end

            class_option(name, defaults.merge!(options))
          end

          hooks[name] = [ in_base, as_hook ]
          invoke_from_option(name, options, &block)
        end
      end

      # Remove a previously added hook.
      #
      #   remove_hook_for :orm
      def self.remove_hook_for(*names)
        remove_invocation(*names)

        names.each do |name|
          hooks.delete(name)
        end
      end

      # Make class option aware of Rails::Generators.options and Rails::Generators.aliases.
      def self.class_option(name, options={}) #:nodoc:
        options[:desc]    = "Indicates when to generate #{name.to_s.humanize.downcase}" unless options.key?(:desc)
        options[:aliases] = default_aliases_for_option(name, options)
        options[:default] = default_value_for_option(name, options)
        super(name, options)
      end

      # Returns the default source root for a given generator. This is used internally
      # by rails to set its generators source root. If you want to customize your source
      # root, you should use source_root.
      def self.default_source_root
        return unless base_name && generator_name
        return unless default_generator_root
        path = File.join(default_generator_root, 'templates')
        path if File.exist?(path)
      end

      # Returns the base root for a common set of generators. This is used to dynamically
      # guess the default source root.
      def self.base_root
        File.dirname(__FILE__)
      end

      # Cache source root and add lib/generators/base/generator/templates to
      # source paths.
      def self.inherited(base) #:nodoc:
        super

        # Invoke source_root so the default_source_root is set.
        base.source_root

        if base.name && base.name !~ /Base$/
          Rails::Generators.subclasses << base

          Rails::Generators.templates_path.each do |path|
            if base.name.include?('::')
              base.source_paths << File.join(path, base.base_name, base.generator_name)
            else
              base.source_paths << File.join(path, base.generator_name)
            end
          end
        end
      end

      protected

        # Check whether the given class names are already taken by user
        # application or Ruby on Rails.
        def class_collisions(*class_names) #:nodoc:
          return unless behavior == :invoke

          class_names.flatten.each do |class_name|
            class_name = class_name.to_s
            next if class_name.strip.empty?

            # Split the class from its module nesting
            nesting = class_name.split('::')
            last_name = nesting.pop
            last = extract_last_module(nesting)

            if last && last.const_defined?(last_name.camelize, false)
              raise Error, "The name '#{class_name}' is either already used in your application " <<
                           "or reserved by Ruby on Rails. Please choose an alternative and run "  <<
                           "this generator again."
            end
          end
        end

        # Takes in an array of nested modules and extracts the last module
        def extract_last_module(nesting)
          nesting.inject(Object) do |last_module, nest|
            break unless last_module.const_defined?(nest, false)
            last_module.const_get(nest)
          end
        end

        # Use Rails default banner.
        def self.banner
          "rails generate #{namespace.sub(/^rails:/,'')} #{self.arguments.map{ |a| a.usage }.join(' ')} [options]".gsub(/\s+/, ' ')
        end

        # Sets the base_name taking into account the current class namespace.
        def self.base_name
          @base_name ||= begin
            if base = name.to_s.split('::').first
              base.underscore
            end
          end
        end

        # Removes the namespaces and get the generator name. For example,
        # Rails::Generators::ModelGenerator will return "model" as generator name.
        def self.generator_name
          @generator_name ||= begin
            if generator = name.to_s.split('::').last
              generator.sub!(/Generator$/, '')
              generator.underscore
            end
          end
        end

        # Returns the default value for the option name given doing a lookup in
        # Rails::Generators.options.
        def self.default_value_for_option(name, options)
          default_for_option(Rails::Generators.options, name, options, options[:default])
        end

        # Return default aliases for the option name given doing a lookup in
        # Rails::Generators.aliases.
        def self.default_aliases_for_option(name, options)
          default_for_option(Rails::Generators.aliases, name, options, options[:aliases])
        end

        # Return default for the option name given doing a lookup in config.
        def self.default_for_option(config, name, options, default)
          if generator_name and c = config[generator_name.to_sym] and c.key?(name)
            c[name]
          elsif base_name and c = config[base_name.to_sym] and c.key?(name)
            c[name]
          elsif config[:rails].key?(name)
            config[:rails][name]
          else
            default
          end
        end

        # Keep hooks configuration that are used on prepare_for_invocation.
        def self.hooks #:nodoc:
          @hooks ||= from_superclass(:hooks, {})
        end

        # Prepare class invocation to search on Rails namespace if a previous
        # added hook is being used.
        def self.prepare_for_invocation(name, value) #:nodoc:
          return super unless value.is_a?(String) || value.is_a?(Symbol)

          if value && constants = self.hooks[name]
            value = name if TrueClass === value
            Rails::Generators.find_by_namespace(value, *constants)
          elsif klass = Rails::Generators.find_by_namespace(value)
            klass
          else
            super
          end
        end

        # Small macro to add ruby as an option to the generator with proper
        # default value plus an instance helper method called shebang.
        def self.add_shebang_option!
          class_option :ruby, type: :string, aliases: "-r", default: Thor::Util.ruby_command,
                              desc: "Path to the Ruby binary of your choice", banner: "PATH"

          no_tasks {
            define_method :shebang do
              @shebang ||= begin
                command = if options[:ruby] == Thor::Util.ruby_command
                  "/usr/bin/env #{File.basename(Thor::Util.ruby_command)}"
                else
                  options[:ruby]
                end
                "#!#{command}"
              end
            end
          }
        end

        def self.usage_path
          paths = [
            source_root && File.expand_path("../USAGE", source_root),
            default_generator_root && File.join(default_generator_root, "USAGE")
          ]
          paths.compact.detect { |path| File.exist? path }
        end

        def self.default_generator_root
          path = File.expand_path(File.join(base_name, generator_name), base_root)
          path if File.exist?(path)
        end

    end
  end
end
