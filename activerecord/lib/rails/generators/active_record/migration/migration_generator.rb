require 'rails/generators/active_record'

module ActiveRecord
  module Generators
    class MigrationGenerator < Base
      class_option :editor, :type => :string, :lazy_default => ENV['EDITOR'], :required => false, :banner => "/path/to/your/editor", :desc => "Open migration using specified editor (defaults to EDITOR)"
      argument :attributes, :type => :array, :default => [], :banner => "field[:type][:index] field[:type][:index]"

      def create_migration_file
        set_local_assigns!
        path = migration_template "migration.rb", "db/migrate/#{file_name}.rb"

        if options[:editor].present?
          run("#{options[:editor]} #{path}")
        end
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
