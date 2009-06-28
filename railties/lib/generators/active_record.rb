require 'generators/named_base'
require 'active_record'

module ActiveRecord
  module Generators
    module Migration

      # Creates a migration template at the given destination. The difference
      # to the default template method is that the migration number is appended
      # to the destination file name.
      #
      # The migration number, migration file name, migration class name are
      # available as instance variables in the template to be rendered.
      #
      # ==== Examples
      #
      #   migration_template "migrate.rb", "db/migrate/add_foo_to_bar"
      #
      def migration_template(source, destination=nil, log_status=true)
        destination = File.expand_path(destination || source, self.destination_root)

        migration_dir = File.dirname(destination)
        @migration_number     = next_migration_number(migration_dir)
        @migration_file_name  = File.basename(destination).sub(/\.rb$/, '')
        @migration_class_name = @migration_file_name.camelize

        if existing = migration_exists?(migration_dir, @migration_file_name)
          raise Rails::Generators::Error, "Another migration is already named #{@migration_file_name}: #{existing}"
        end

        destination = File.join(migration_dir, "#{@migration_number}_#{@migration_file_name}.rb")
        template(source, destination, log_status)
      end

      protected

        def migration_exists?(dirname, file_name) #:nodoc:
          Dir.glob("#{dirname}/[0-9]*_*.rb").grep(/\d+_#{file_name}.rb$/).first
        end

        def current_migration_number(dirname) #:nodoc:
          Dir.glob("#{dirname}/[0-9]*_*.rb").collect{ |f| f.split("_").first.to_i }.max
        end

        def next_migration_number(dirname) #:nodoc:
          if ActiveRecord::Base.timestamped_migrations
            Time.now.utc.strftime("%Y%m%d%H%M%S")
          else
            "%.3d" % (current_migration_number(dirname) + 1)
          end
        end
    end

    class Base < Rails::Generators::NamedBase
      include Migration
    end
  end
end
