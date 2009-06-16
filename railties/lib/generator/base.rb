require File.dirname(__FILE__) + '/actions'

# TODO Use vendored Thor
require 'rubygems'
gem 'josevalim-thor'
require 'thor'

module Rails
  module Generators
    class Base < Thor::Group
      include Rails::Generators::Actions
      include Thor::Actions

      # Make aliases for backwards compatibily. Usa no_tasks to avoid aliases
      # from becoming tasks.
      #
      no_tasks {
        alias :file :create_file
        alias :log  :say_status
      }

      # Automatically sets the source root based on the class name.
      #
      def self.source_root
        @source_root ||= begin
          klass_name = self.name
          klass_name.gsub!(/^Rails::Generators::/, '')
          klass_name.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
          klass_name.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
          File.join(File.dirname(__FILE__), 'templates', klass_name.downcase)
        end
      end

    end
  end
end
