require 'generators/actions'

module Rails
  module Generators
    DEFAULTS = {
      :fixture => true,
      :helper => true,
      :orm => 'active_record',
      :test_framework => 'test_unit',
      :template_engine => 'erb'
    }

    ALIASES = {
      :fixture_replacement => '-r',
      :helper => '-l',
      :orm => '-o',
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
        usage = File.join(source_root, "..", "USAGE")

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
      #     invoke_for :test_framework, :aliases => "-t"
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
      # ==== Another example
      #
      # Another example of invoke_for hooks is fixture replacement tools.
      # Consider this TestUnit model generator:
      #
      #   class ModelGenerator < TestUnit::Generators::Base
      #     invoke_for :fixture_replacement, :aliases => "-r"
      #   end
      #
      # When invoked as:
      #
      #   ruby script/generate test_unit:model Account -r fixjour
      #
      # It will lookup for any of these generators:
      #
      #   "test_unit:generators:fixjour", "fixjour:generators:model", "fixjour"
      #
      # Fixjour can choose any of these hooks to implement. For example, if
      # Fixjour has different output for rspec and test_unit, it will likely
      # implement the first hook. However if the output is the same for both,
      # it will implement the second or the third depending on the number of
      # generators it has.
      #
      def self.invoke_for(*names)
        default_options = names.extract_options!

        names.each do |name|
          options = default_options.dup
          options[:desc]    ||= "#{name.to_s.humanize} to be invoked"
          options[:banner]  ||= "NAME"
          options[:aliases] ||= ALIASES[name]

          class_option name, options.merge!(:type => :default, :default => DEFAULTS[name])

          class_eval <<-METHOD, __FILE__, __LINE__
            def invoke_for_#{name}
              return unless options[#{name.inspect}]

              klass = Rails::Generators.find_by_namespace(options[#{name.inspect}],
                                                          self.class.base_name, self.class.generator_name)

              if klass
                invoke klass
              else
                say "Could not find and invoke '\#{options[#{name.inspect}]}'."
              end
            end
          METHOD
        end
      end

      # Invoke a generator with the given name if the user requires it. The
      # difference to invoke_for is that the class option here is boolean
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
      def self.invoke_if(*names)
        default_options = names.extract_options!

        names.each do |name|
          conditional_class_option name, default_options.dup

          class_eval <<-METHOD, __FILE__, __LINE__
            def invoke_if_#{name}
              return unless options[#{name.inspect}]

              klass = Rails::Generators.find_by_namespace(#{name.inspect},
                                                          self.class.base_name, self.class.generator_name)

              if klass
                invoke klass
              else
                say "Could not find and invoke '#{name}'."
              end
            end
          METHOD
        end
      end

      protected

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

        # Creates a conditional class option with type boolean, default value
        # lookup and default description.
        #
        def self.conditional_class_option(name, options={})
          options[:desc] ||= "Indicates when to generate #{name.to_s.humanize.downcase}"
          class_option name, options.merge!(:type => :boolean, :default => DEFAULTS[name] || false)
        end

        # Small macro to add ruby as an option to the generator with proper
        # default value plus an instance helper method called shebang.
        #
        def self.add_shebang_option!
          require 'rbconfig'
          default = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])

          class_option :ruby, :type => :string, :aliases => "-r", :default => default,
                              :desc => "Path to the Ruby binary of your choice", :banner => "PATH"

          no_tasks do
            define_method :shebang do
              "#!#{options[:ruby] || "/usr/bin/env ruby"}"
            end
          end
        end

    end
  end
end
