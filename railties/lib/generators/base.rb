require 'generators/actions'

module Rails
  module Generators
    DEFAULTS = {
      :fixture => true,
      :helper => true,
      :migration => true,
      :orm => 'active_record',
      :resource_controller => 'controller',
      :test_framework => 'test_unit',
      :template_engine => 'erb',
      :timestamps => true
    }

    ALIASES = {
      :fixture_replacement => '-r',
      :orm => '-o',
      :resource_controller => '-c',
      :test_framework => '-t',
      :template_engine => '-e'
    }

    class Error < Thor::Error
    end

    class Base < Thor::Group
      include Rails::Generators::Actions
      include Thor::Actions

      # Automatically sets the source root based on the class name.
      #
      def self.source_root
        @source_root ||= File.expand_path(File.join(File.dirname(__FILE__), base_name, generator_name, 'templates'))
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
      # is invoked and you can set a hash to customize it, although type and
      # default values cannot be given.
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
      # ==== Custom invocations
      #
      # You can also supply a block to hook for to customize how the hook is
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
        default_class_options(*names)
        options = names.extract_options!
        verbose = options.fetch(:verbose, :blue)

        names.each do |name|
          invocations << [ name, base_name, generator_name ]
          invocation_blocks[name] = block if block_given?

          class_eval <<-METHOD, __FILE__, __LINE__
            def invoke_for_#{name}
              return unless options[#{name.inspect}]

              klass = Rails::Generators.find_by_namespace(options[#{name.inspect}],
                                                          #{base_name.inspect}, #{generator_name.inspect})

              if klass
                say_status :invoke, options[#{name.inspect}], #{verbose.inspect}
                invoke_class_with_block #{name.inspect}, klass
              else
                say "Could not find and invoke '\#{options[#{name.inspect}]}'."
              end
            end
          METHOD
        end
      end

      # Invoke a generator with the given name if the user requires it. The
      # difference to hook_for is that the class option here is boolean
      # and the generator invoked is not based on user input.
      #
      # A class option is created when this method is invoked and you can set
      # a hash to customize it, although type and default values cannot be
      # given.
      #
      # ==== Examples
      #
      #   class ControllerGenerator < Rails::Generators::Base
      #     invoke_if :webrat, :aliases => "-w"
      #   end
      #
      # The example above will create a helper option and will be invoked
      # when the user requires so:
      #
      #   ruby script/generate controller Account --webrat
      #
      # The controller generator will then try to invoke the following generators:
      #
      #   "rails:generators:webrat", "webrat:generators:controller", "webrat"
      #
      # ==== Custom invocations
      #
      # This method accepts custom invocations as in hook_for. Check hook_for
      # for usage and examples.
      #
      def self.invoke_if(*names, &block)
        conditional_class_options(*names)
        options = names.extract_options!
        verbose = options.fetch(:verbose, :blue)

        names.each do |name|
          invocations << [ name, base_name, generator_name ]
          invocation_blocks[name] = block if block_given?

          class_eval <<-METHOD, __FILE__, __LINE__
            def invoke_if_#{name}
              return unless options[#{name.inspect}]

              klass = Rails::Generators.find_by_namespace(#{name.inspect},
                                                          #{base_name.inspect}, #{generator_name.inspect})

              if klass
                say_status :invoke, #{name.inspect}, #{verbose.inspect}
                invoke_class_with_block #{name.inspect}, klass
              else
                say "Could not find and invoke '#{name}'."
              end
            end
          METHOD
        end
      end

      # Remove a previously added hook.
      #
      # ==== Examples
      #
      #   remove_hook_for :orm
      #
      def self.remove_hook_for(*names)
        names.each do |name|
          remove_class_option name
          remove_task name
          invocations.delete_if { |i| i[0] == name }
          invocation_blocks.delete(name)
        end
      end

      protected

        # This is the common method that both hook_for and invoke_if use to
        # invoke a class. It searches for a block in the invocation blocks
        # in case the user wants to customize how the class is invoked.
        #
        def invoke_class_with_block(name, klass) #:nodoc:
          if block = self.class.invocation_blocks[name]
            block.call(self, klass)
          else
            invoke klass
          end
        end

        # Check whether the given class names are already taken by user
        # application or Ruby on Rails.
        #
        def class_collisions(*class_names)
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
          "#{$0} #{generator_name} #{self.arguments.map(&:usage).join(' ')} [options]"
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

        # Stores invocations for this class merging with superclass values.
        #
        def self.invocations #:nodoc:
          @invocations ||= from_superclass(:invocations, [])
        end

        # Stores invocation blocks used on hook_for and invoke_if.
        #
        def self.invocation_blocks #:nodoc:
          @invocation_blocks ||= from_superclass(:invocation_blocks, {})
        end

        # Creates a conditional class option with type boolean, default value
        # lookup and default description.
        #
        def self.conditional_class_options(*names)
          default_options = names.extract_options!

          names.each do |name|
            options = default_options.dup
            options[:desc] ||= "Indicates when to generate #{name.to_s.humanize.downcase}"
            class_option name, options.merge!(:type => :boolean, :default => DEFAULTS[name] || false)
          end
        end

        # Creates a class option with type default, banner, alias lookup and
        # description. Used internally by hook_for (ie, not part of plugin API).
        #
        def self.default_class_options(*names) #:nodoc:
          default_options = names.extract_options!

          names.each do |name|
            options = default_options.dup
            options[:desc]    ||= "#{name.to_s.humanize} to be invoked"
            options[:banner]  ||= "NAME"
            options[:aliases] ||= ALIASES[name]
            class_option name, options.merge!(:type => :default, :default => DEFAULTS[name])
          end
        end

        # Overwrite class options help to allow invoked generators options to be
        # shown when invoking a generator. Only first level options and options
        # that belongs to the default group are shown.
        #
        def self.class_options_help(shell, ungrouped_name=nil, extra_group=nil)
          klass_options = Thor::CoreExt::OrderedHash.new

          invocations.each do |args|
            name, base, generator = args
            option = class_options[name]

            klass_name = option.type == :boolean ? name : option.default
            next unless klass_name

            klass = Rails::Generators.find_by_namespace(klass_name, base, generator)
            next unless klass

            human_name = klass_name.to_s.classify

            klass_options[human_name] ||= []
            klass_options[human_name] += klass.class_options.values.select do |option|
              class_options[option.human_name.to_sym].nil? && option.group.nil?
            end
          end

          klass_options.merge!(extra_group) if extra_group
          super(shell, ungrouped_name, klass_options)
        end

        # Small macro to add ruby as an option to the generator with proper
        # default value plus an instance helper method called shebang.
        #
        def self.add_shebang_option!
          require 'rbconfig'
          default = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])

          class_option :ruby, :type => :string, :aliases => "-r", :default => default,
                              :desc => "Path to the Ruby binary of your choice", :banner => "PATH"

          class_eval <<-METHOD, __FILE__, __LINE__
            protected
            def shebang
              "#!\#{options[:ruby] || "/usr/bin/env ruby"}"
            end
          METHOD
        end

    end
  end
end
