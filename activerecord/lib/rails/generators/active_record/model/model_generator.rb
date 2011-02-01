require 'rails/generators/active_record'

module ActiveRecord
  module Generators
    class ModelGenerator < Base
      argument :attributes, :type => :array, :default => [], :banner => "field:type field:type"

      check_class_collision

      class_option :migration,  :type => :boolean
      class_option :timestamps, :type => :boolean
      class_option :parent,     :type => :string, :desc => "The parent class for the generated model"
      class_option :indexes,    :type => :boolean, :default => true, :desc => "Add indexes for references and belongs_to columns"

      def create_migration_file
        return unless options[:migration] && options[:parent].nil?
        migration_template "migration.rb", "db/migrate/create_#{table_name}.rb"
      end

      def create_model_file
        template 'model.rb', File.join('app/models', class_path, "#{file_name}.rb")
      end

      def create_module_file
        return if regular_class_path.empty?
        template 'module.rb', File.join('app/models', "#{class_path.join('/')}.rb") if behavior == :invoke
      end

      hook_for :test_framework

      protected

        def parent_class_name
          options[:parent] || "ActiveRecord::Base"
        end

    end
  end
end
