require 'rails/generators/active_record'

module ActiveRecord
  module Generators
    class MigrationGenerator < Base
      argument :attributes, :type => :array, :default => [], :banner => "field[:type][:index] field[:type][:index]"

      def create_migration_file
        set_local_assigns!
        migration_template "migration.rb", "db/migrate/#{file_name}.rb"
      end

      protected
        attr_reader :migration_action

        def set_local_assigns!
          if file_name =~ /^(add|remove)_.*_(?:to|from)_(.*)/
            @migration_action = $1
            @table_name       = $2.pluralize
          end
        end

    end
  end
end
