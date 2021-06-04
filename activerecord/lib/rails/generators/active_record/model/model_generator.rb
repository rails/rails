# frozen_string_literal: true

require "rails/generators/active_record"

module ActiveRecord
  module Generators # :nodoc:
    class ModelGenerator < Base # :nodoc:
      argument :attributes, type: :array, default: [], banner: "field[:type][:index] field[:type][:index]"

      check_class_collision

      class_option :migration, type: :boolean
      class_option :timestamps, type: :boolean
      class_option :parent, type: :string, desc: "The parent class for the generated model"
      class_option :indexes, type: :boolean, default: true, desc: "Add indexes for references and belongs_to columns"
      class_option :primary_key_type, type: :string, desc: "The type for primary key"
      class_option :database, type: :string, aliases: %i(--db), desc: "The database for your model's migration. By default, the current environment's primary database is used."

      # creates the migration file for the model.
      def create_migration_file
        return if skip_migration_creation?
        attributes.each { |a| a.attr_options.delete(:index) if a.reference? && !a.has_index? } if options[:indexes] == false
        migration_template "../../migration/templates/create_table_migration.rb", File.join(db_migrate_path, "create_#{table_name}.rb")
      end

      def create_model_file
        generate_abstract_class if database && !parent
        template "model.rb", File.join("app/models", class_path, "#{file_name}.rb")
      end

      def create_module_file
        return if regular_class_path.empty?
        template "module.rb", File.join("app/models", "#{class_path.join('/')}.rb") if behavior == :invoke
      end

      hook_for :test_framework

      private
        # Skip creating migration file if:
        #   - options parent is present and database option is not present
        #   - migrations option is nil or false
        def skip_migration_creation?
          parent && !database || !migration
        end

        def attributes_with_index
          attributes.select { |a| !a.reference? && a.has_index? }
        end

        # Used by the migration template to determine the parent name of the model
        def parent_class_name
          if parent
            parent
          elsif database
            abstract_class_name
          else
            "ApplicationRecord"
          end
        end

        def generate_abstract_class
          path = File.join("app/models", "#{database.underscore}_record.rb")
          return if File.exist?(path)

          template "abstract_base_class.rb", path
        end

        def abstract_class_name
          "#{database.camelize}Record"
        end

        def database
          options[:database]
        end

        def parent
          options[:parent]
        end

        def migration
          options[:migration]
        end
    end
  end
end
