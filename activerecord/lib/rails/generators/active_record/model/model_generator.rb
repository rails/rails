require 'rails/generators/active_record'

module ActiveRecord
  module Generators # :nodoc:
    class ModelGenerator < Base # :nodoc:
      argument :attributes, :type => :array, :default => [], :banner => "field[:type][:index] field[:type][:index]"

      check_class_collision

      class_option :migration,  :type => :boolean
      class_option :timestamps, :type => :boolean
      class_option :parent,     :type => :string, :desc => "The parent class for the generated model"
      class_option :indexes,    :type => :boolean, :default => true, :desc => "Add indexes for references and belongs_to columns"

      
      # creates the migration file for the model.

      def create_migration_file
        return unless options[:migration] && options[:parent].nil?
        attributes.each { |a| a.attr_options.delete(:index) if a.reference? && !a.has_index? } if options[:indexes] == false
        ensure_migration_source_paths
        migration_template "create_table_migration.rb", "db/migrate/create_#{table_name}.rb"
      end

      def ensure_migration_source_paths
        return if @migration_source_paths_added
        Rails::Generators.templates_path.each do |path|
          source_paths << File.join(path, self.class.base_name, "migration")
        end
        path = File.expand_path(File.join(self.class.base_name, "migration", "templates"), self.class.base_root)
        source_paths << path
        @migration_source_paths_added = true
      end

      def create_model_file
        template 'model.rb', File.join('app/models', class_path, "#{file_name}.rb")
      end

      def create_module_file
        return if regular_class_path.empty?
        template 'module.rb', File.join('app/models', "#{class_path.join('/')}.rb") if behavior == :invoke
      end

      def attributes_with_index
        attributes.select { |a| !a.reference? && a.has_index? }
      end

      def accessible_attributes
        attributes.reject(&:reference?)
      end

      hook_for :test_framework

      protected

        # Used by the migration template to determine the parent name of the model
        def parent_class_name
          options[:parent] || "ActiveRecord::Base"
        end

    end
  end
end
