require 'generator/actions'

module Rails
  module Generators
    class Error < Thor::Error
    end

    class Base < Thor::Group
      include Rails::Generators::Actions
      include Thor::Actions

      # Automatically sets the source root based on the class name.
      #
      def self.source_root
        @source_root ||= File.expand_path(File.join(File.dirname(__FILE__), 'generators', generator_name, 'templates'))
      end

      # Convenience method to get the namespace from the class name.
      #
      def self.namespace(name=nil)
        if name
          super
        else
          @namespace ||= "rails:generators:#{generator_name}"
        end
      end

    protected

      # Use Rails default banner.
      #
      def self.banner
        "#{$0} #{generator_name} #{self.arguments.map(&:usage).join(' ')} [options]"
      end

      # Removes the namespaces and get the generator name. For example,
      # Rails::Generators::MetalGenerator will return "metal" as generator name.
      #
      # The name is used to set the namespace (in this case "rails:generators:metal")
      # and to set the source root ("generators/metal/templates").
      #
      def self.generator_name
        @generator_name ||= begin
          klass_name = self.name
          klass_name.gsub!(/^Rails::Generators::/, '')
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
                            :desc => "Path to the Ruby binary of your choice"

        class_eval do
          protected
          def shebang
            "#!#{options[:ruby] || "/usr/bin/env ruby"}"
          end
        end
      end

    end
  end
end
