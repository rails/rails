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
      attr_reader :migration_action, :join_tables

      def set_local_assigns!
        case file_name
        when /^(add|remove)_.*_(?:to|from)_(.*)/
          @migration_action = $1
          @table_name       = $2.pluralize
        when /^drop_(.*)/
          @migration_action = "drop"
          @table_name       = $1.pluralize
        when /join_table/
          if attributes.length == 2
            @migration_action = 'join'
            @join_tables      = attributes.map(&:plural_name)

            set_index_names
          end
        end
      end

      def set_index_names
        attributes.each_with_index do |attr, i|
          attr.index_name = [attr, attributes[i - 1]].map{ |a| index_name_for(a) }
        end
      end

      def index_name_for(attribute)
        if attribute.foreign_key?
          attribute.name
        else
          attribute.name.singularize.foreign_key
        end.to_sym
      end
    end
  end
end
