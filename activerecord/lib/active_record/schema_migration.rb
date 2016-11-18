require "active_record/scoping/default"
require "active_record/scoping/named"

module ActiveRecord
  # This class is used to create a table that keeps track of which migrations
  # have been applied to a given database. When a migration is run, its schema
  # number is inserted in to the `SchemaMigration.table_name` so it doesn't need
  # to be executed the next time.
  class SchemaMigration < ActiveRecord::Base # :nodoc:
    class << self
      def primary_key
        "version"
      end

      def table_name
        "#{table_name_prefix}#{ActiveRecord::Base.schema_migrations_table_name}#{table_name_suffix}"
      end

      def table_exists?
        ActiveSupport::Deprecation.silence { connection.table_exists?(table_name) }
      end

      def create_table
        unless table_exists?
          version_options = connection.internal_string_options_for_primary_key

          connection.create_table(table_name, id: false) do |t|
            t.string :version, version_options
          end
        end
      end

      def drop_table
        connection.drop_table table_name, if_exists: true
      end

      def normalize_migration_number(number)
        "%.3d" % number.to_i
      end

      def normalized_versions
        pluck(:version).map { |v| normalize_migration_number v }
      end
    end

    def version
      super.to_i
    end
  end
end
