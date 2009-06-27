module ActiveRecord
  module Generators
    class ModelGenerator < Base
      argument :attributes, :type => :hash, :default => {}, :banner => "field:type, field:type"

      check_class_collision

      # TODO Add parent support

      # TODO Add DEFAULTS support
      class_option :skip_timestamps, :type => :boolean, :default => false,
                   :desc => "Don't add timestamps to the migration file"

      # TODO Make this a invoke_if
      # TODO Add DEFAULTS support
      class_option :skip_migration, :type => :boolean, :default => false,
                   :desc => "Don't generate a migration file"

      def create_model_file
        template 'model.rb', File.join('app/models', class_path, "#{file_name}.rb")
      end

      # TODO Add migration support
      def create_migration_file
#        unless options[:skip_migration]
#          m.migration_template 'migration.rb', 'db/migrate', :assigns => {
#            :migration_name => "Create#{class_name.pluralize.gsub(/::/, '')}"
#          }, :migration_file_name => "create_#{file_path.gsub(/\//, '_').pluralize}"
#        end
      end
    end
  end
end
