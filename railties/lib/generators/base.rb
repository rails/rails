require 'generators/actions'

module Rails
  module Generators
    class Error < Thor::Error
    end

    class Base < Thor::Group
      include Thor::Actions
      include Rails::Generators::Actions

      # Automatically sets the source root based on the class name.
      #
      def self.source_root
        @_rails_source_root ||= File.expand_path(File.join(File.dirname(__FILE__),
                                                 base_name, generator_name, 'templates'))
      end

      # Tries to get the description from a USAGE file one folder above the source
      # root otherwise uses a default description.
      #
      def self.desc(description=nil)
        return super if description
        usage = File.expand_path(File.join(source_root, "..", "USAGE"))

        @desc ||= if File.exist?(usage)
          File.read(usage)
        else
          "Description:\n    Create #{base_name.humanize.downcase} files for #{generator_name} generator."
        end
      end

      # Convenience method to get the namespace from the class name. It's the
      # same as Thor default except that the Generator at the end of the class
      # is removed.
      #
      def self.namespace(name=nil)
        return super if name
        @namespace ||= super.sub(/_generator$/, '')
      end

      # Invoke a generator based on the value supplied by the user to the
      # given option named "name". A class option is created when this method
      # is invoked and you can set a hash to customize it.
      #
      # ==== Examples
      #
      #   class ControllerGenerator < Rails::Generators::Base
      #     hook_for :test_framework, :aliases => "-t"
      #   end
      #
      # The example above will create a test framework option and will invoke
      # a generator based on the user supplied value.
      #
      # For example, if the user invoke the controller generator as:
      #
      #   ruby script/generate controller Account --test-framework=test_unit
      #
      # The controller generator will then try to invoke the following generators:
      #
      #   "rails:generators:test_unit", "test_unit:generators:controller", "test_unit"
      #
      # In this case, the "test_unit:generators:controller" is available and is
      # invoked. This allows any test framework to hook into Rails as long as it
      # provides any of the hooks above.
      #
      # Finally, if the user don't want to use any test framework, he can do:
      #
      #   ruby script/generate controller Account --skip-test-framework
      #
      # Or similarly:
      #
      #   ruby script/generate controller Account --no-test-framework
      #
      # ==== Boolean hooks
      #
      # In some cases, you want to provide a boolean hook. For example, webrat
      # developers might want to have webrat available on controller generator.
      # This can be achieved as:
      #
      #   Rails::Generators::ControllerGenerator.hook_for :webrat, :type => :boolean
      #
      # Then, if you want, webrat to be invoked, just supply:
      #
      #   ruby script/generate controller Account --webrat
      #
      # The hooks lookup is similar as above:
      #
      #   "rails:generators:webrat", "webrat:generators:controller", "webrat"
      #
      # ==== Custom invocations
      #
      # You can also supply a block to hook_for to customize how the hook is
      # going to be invoked. The block receives two parameters, an instance
      # of the current class and the klass to be invoked.
      #
      # For example, in the resource generator, the controller should be invoked
      # with a pluralized class name. By default, it is invoked with the same
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
          defaults = if options[:type] == :boolean
            { }
          elsif [true, false].include?(default_value_for_option(name, options))
            { :banner => "" }
          else
            { :desc => "#{name.to_s.humanize} to be invoked", :banner => "NAME" }
          end

          unless class_options.key?(name)
            class_option name, defaults.merge!(options)
          end

          hooks[name] = [ in_base, as_hook ]
          invoke_from_option name, options, &block
        end
      end

      # Remove a previously added hook.
      #
      # ==== Examples
      #
      #   remove_hook_for :orm
      #
      def self.remove_hook_for(*names)
        remove_invocation *names

        names.each do |name|
          hooks.delete(name)
        end
      end

      # Make class option aware of Rails::Generators.options and Rails::Generators.aliases.
      #
      def self.class_option(name, options={}) #:nodoc:
        options[:desc]    = "Indicates when to generate #{name.to_s.humanize.downcase}" unless options.key?(:desc)
        options[:aliases] = default_aliases_for_option(name, options)
        options[:default] = default_value_for_option(name, options)
        super(name, options)
      end

      # Cache source root and add lib/generators/base/generator/templates to
      # source paths.
      #
      def self.inherited(base) #:nodoc:
        super
        base.source_root # Cache source root

        if defined?(RAILS_ROOT) && base.name !~ /Base$/
          path = File.expand_path(File.join(RAILS_ROOT, 'lib', 'templates'))
          if base.name.include?('::')
            base.source_paths << File.join(path, base.base_name, base.generator_name)
          else
            base.source_paths << File.join(path, base.generator_name)
          end
        end
      end

      protected

        # Check whether the given class names are already taken by user
        # application or Ruby on Rails.
        #
        def class_collisions(*class_names) #:nodoc:
          return unless behavior == :invoke

          class_names.flatten.each do |class_name|
            class_name = class_name.to_s
            next if class_name.strip.empty?

            # Split the class from its module nesting
            nesting = class_name.split('::')
            last_name = nesting.pop

            # Hack to limit const_defined? to non-inherited on 1.9
            extra = []
            extra << false unless Object.method(:const_defined?).arity == 1

            # Extract the last Module in the nesting
            last = nesting.inject(Object) do |last, nest|
              break unless last.const_defined?(nest, *extra)
              last.const_get(nest)
            end

            if last && last.const_defined?(last_name.camelize, *extra)
              raise Error, "The name '#{class_name}' is either already used in your application " <<
                           "or reserved by Ruby on Rails. Please choose an alternative and run "  <<
                           "this generator again."
            end
          end
        end

        # Use Rails default banner.
        #
        def self.banner
          "#{$0} #{generator_name} #{self.arguments.map{ |a| a.usage }.join(' ')} [options]"
        end

        # Sets the base_name taking into account the current class namespace.
        #
        def self.base_name
          @base_name ||= self.name.split('::').first.underscore
        end

        # Removes the namespaces and get the generator name. For example,
        # Rails::Generators::MetalGenerator will return "metal" as generator name.
        #
        def self.generator_name
          @generator_name ||= begin
            klass_name = self.name.split('::').last
            klass_name.sub!(/Generator$/, '')
            klass_name.underscore
          end
        end

        # Return the default value for the option name given doing a lookup in
        # Rails::Generators.options.
        #
        def self.default_value_for_option(name, options)
          config = Rails::Generators.options
          generator, base = generator_name.to_sym, base_name.to_sym

          if config[generator] && config[generator].key?(name)
            config[generator][name]
          elsif config[base] && config[base].key?(name)
            config[base][name]
          elsif config[:rails].key?(name)
            config[:rails][name]
          else
            options[:default]
          end
        end

        # Return default aliases for the option name given doing a lookup in
        # Rails::Generators.aliases.
        #
        def self.default_aliases_for_option(name, options)
          config = Rails::Generators.aliases
          generator, base = generator_name.to_sym, base_name.to_sym

          if config[generator] && config[generator].key?(name)
            config[generator][name]
          elsif config[base] && config[base].key?(name)
            config[base][name]
          elsif config[:rails].key?(name)
            config[:rails][name]
          else
            options[:aliases]
          end
        end

        # Keep hooks configuration that are used on prepare_for_invocation.
        #
        def self.hooks #:nodoc:
          @hooks ||= from_superclass(:hooks, {})
        end

        # Prepare class invocation to search on Rails namespace if a previous
        # added hook is being used.
        #
        def self.prepare_for_invocation(name, value) #:nodoc:
          if value && constants = self.hooks[name]
            Rails::Generators.find_by_namespace(value, *constants)
          else
            super
          end
        end

        # Small macro to add ruby as an option to the generator with proper
        # default value plus an instance helper method called shebang.
        #
        def self.add_shebang_option!
          class_option :ruby, :type => :string, :aliases => "-r", :default => Thor::Util.ruby_command,
                              :desc => "Path to the Ruby binary of your choice", :banner => "PATH"

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

    end
  end
end
