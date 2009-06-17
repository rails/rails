require File.dirname(__FILE__) + '/actions'

# TODO Use vendored Thor
require 'rubygems'
gem 'josevalim-thor'
require 'thor'

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
          klass_name = self.name
          klass_name.gsub!(/^Rails::Generators::/, '')
          klass_name.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
          klass_name.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
          File.expand_path(File.join(File.dirname(__FILE__), 'templates', klass_name.downcase))
        end
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
