require 'rails/generators/named_base'
require 'rails/generators/migration'
require 'rails/generators/active_model'
require 'rails/generators/active_record/migration'
require 'active_record'

module ActiveRecord
  module Generators
    class Base < Rails::Generators::NamedBase #:nodoc:
      include Rails::Generators::Migration
      extend ActiveRecord::Generators::Migration

      # Set the current directory as base for the inherited generators.
      def self.base_root
        File.dirname(__FILE__)
      end

      # Implement the required interface for Rails::Generators::Migration.
      def self.next_migration_number(dirname) #:nodoc:
        next_migration_number = current_migration_number(dirname) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end
    end
  end
end
