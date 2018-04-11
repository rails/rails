# frozen_string_literal: true

require "rails/generators/active_record"
require "rails/generators/primary_file_helpers"

module ActiveRecord
  module Generators # :nodoc:
    class MigrationGenerator < Base # :nodoc:
      include Rails::Generators::PrimaryFileHelpers

      argument :attributes, type: :array, default: [], banner: "field[:type][:index] field[:type][:index]"

      class_option :primary_key_type, type: :string, desc: "The type for primary key"

      def create_migration_file
        set_local_assigns!
        validate_file_name!
        destination = migration_template @migration_template, File.join(db_migrate_path, "#{file_name}.rb")
        primary_file(destination)
      end

      private
        attr_reader :migration_action, :join_tables

        # Sets the default migration template that is being used for the generation of the migration.
        # Depending on command line arguments, the migration template and the table name instance
        # variables are set up.
        def set_local_assigns!
          @migration_template = "migration.rb"
          case file_name
          when /^(add)_.*_to_(.*)/, /^(remove)_.*?_from_(.*)/
            @migration_action = $1
            @table_name       = normalize_table_name($2)
          when /join_table/
            if attributes.length == 2
              @migration_action = "join"
              @join_tables      = pluralize_table_names? ? attributes.map(&:plural_name) : attributes.map(&:singular_name)

              set_index_names
            end
          when /^create_(.+)/
            @table_name = normalize_table_name($1)
            @migration_template = "create_table_migration.rb"
          end
        end

        def set_index_names
          attributes.each_with_index do |attr, i|
            attr.index_name = [attr, attributes[i - 1]].map { |a| index_name_for(a) }
          end
        end

        def index_name_for(attribute)
          if attribute.foreign_key?
            attribute.name
          else
            attribute.name.singularize.foreign_key
          end.to_sym
        end

        def attributes_with_index
          attributes.select { |a| !a.reference? && a.has_index? }
        end

        # A migration file name can only contain underscores (_), lowercase characters,
        # and numbers 0-9. Any other file name will raise an IllegalMigrationNameError.
        def validate_file_name!
          unless /^[_a-z0-9]+$/.match?(file_name)
            raise IllegalMigrationNameError.new(file_name)
          end
        end

        def normalize_table_name(_table_name)
          pluralize_table_names? ? _table_name.pluralize : _table_name.singularize
        end

        def primary_file?
          shell.base.class.to_s == "Rails::Generators::MigrationGenerator"
        end
    end
  end
end
