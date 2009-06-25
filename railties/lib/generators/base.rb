require 'generators/actions'

module Rails
  module Generators
    DEFAULTS = {
      :test_framework => 'test_unit',
      :template_engine => 'erb'
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
        @namespace ||= "#{base_name}:generators:#{generator_name}"
      end

      protected

        # Check whether the given class names are already taken by Ruby or Rails.
        # In the future, expand to check other namespaces such as the rest of
        # the user's app.
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
            klass_name.gsub!(/Generator$/, '')
            klass_name.underscore
          end
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

        # Invoke a generator based on the given name. If a class option does not
        # exist for the current name, it's created.
        #
        def self.invoke_for(*names)
          names.each do |name|
            unless class_options[name]
              aliases = "-" + name.to_s.gsub(/_framework$/, '').split('_').last[0,1]
              class_option name, :type => :string, :default => DEFAULTS[name], :banner => "NAME", :aliases => aliases,
                                 :desc => "#{name.to_s.humanize} to be used"
            end

            class_eval <<-METHOD, __FILE__, __LINE__
              def invoke_#{name}
                return unless options[#{name.inspect}]
                task = "\#{options[#{name.inspect}]}:generators:\#{self.class.generator_name}"

                begin
                  invoke task
                rescue Thor::UndefinedTaskError
                  say "Could not find and invoke '\#{task}'."
                end
              end
            METHOD
          end
        end

    end
  end
end
