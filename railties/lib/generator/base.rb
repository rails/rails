# Load ActiveSupport mini
activesupport_path = "#{File.dirname(__FILE__)}/../../../activesupport/lib"
$:.unshift(activesupport_path) if File.directory?(activesupport_path)
require 'active_support/all'

# TODO Use vendored Thor
require 'rubygems'
gem 'josevalim-thor'
require 'thor'

require File.dirname(__FILE__) + '/../rails/version' unless defined?(Rails::VERSION)
require File.dirname(__FILE__) + '/actions'

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
        @source_root ||= begin
          klass_name = self.name.gsub(/^Rails::Generators::/, '')
          File.expand_path(File.join(File.dirname(__FILE__), 'generators', klass_name.underscore, 'templates'))
        end
      end

    protected

      # Use Rails default banner.
      #
      def self.banner
        "#{$0} #{self.arguments.map(&:usage).join(' ')} [options]"
      end

      # Small macro to ruby as an option to the generator with proper default
      # value plus an instance helper method.
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
