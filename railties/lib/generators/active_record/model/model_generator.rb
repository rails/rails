module ActiveRecord
  module Generators
    class ModelGenerator < Base
      argument :attributes, :type => :hash, :default => {}, :banner => "field:type, field:type"

      check_class_collision

      conditional_class_option :timestamps
      conditional_class_option :migration

      class_option :parent, :type => :string,
                   :desc => "The parent class for the generated model"

      def create_model_file
        template 'model.rb', File.join('app/models', class_path, "#{file_name}.rb")
      end

      # TODO Add migration support
      def create_migration_file
        if options[:migration] && options[:parent].nil?
#          m.migration_template 'migration.rb', 'db/migrate', :assigns => {
#            :migration_name => "Create#{class_name.pluralize.gsub(/::/, '')}"
#          }, :migration_file_name => "create_#{file_path.gsub(/\//, '_').pluralize}"
        end
      end

      protected

        def parent_class_name
          options[:parent] || "ActiveRecord::Base"
        end

    end
  end
end
