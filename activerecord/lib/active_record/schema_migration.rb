require 'active_record/scoping/default'
require 'active_record/scoping/named'

module ActiveRecord
  # This class is used to create a table that keeps track of which migrations
  # have been applied to a given database. When a migration is run, its schema
  # number is inserted in to the `SchemaMigration.table_name` so it doesn't need
  # to be executed the next time.
  class SchemaMigration < ActiveRecord::Base # :nodoc:
    class << self
      def primary_key
        nil
      end

      def table_name
        "#{table_name_prefix}#{ActiveRecord::Base.schema_migrations_table_name}#{table_name_suffix}"
      end

      def index_name
        "#{table_name_prefix}unique_#{ActiveRecord::Base.schema_migrations_table_name}#{table_name_suffix}"
      end

      def created_at_index_name
        "#{table_name_prefix}created_at_#{ActiveRecord::Base.schema_migrations_table_name}#{table_name_suffix}"
      end

      def table_exists?
        connection.table_exists?(table_name)
      end

      def create_table(limit=nil)
        unless table_exists?
          version_options = {null: false}
          version_options[:limit] = limit if limit

          connection.create_table(table_name, id: false) do |t|
            t.column :version, :string, version_options
            t.column :created_at, :datetime, null: false
          end
          connection.add_index table_name, :version, unique: true, name: index_name
          connection.add_index table_name, :created_at, name: created_at_index_name
        end
      end

      def drop_table
        if table_exists?
          connection.remove_index table_name, name: index_name
          connection.drop_table(table_name)
        end
      end

      def normalize_migration_number(number)
        "%.3d" % number.to_i
      end

      def normalized_versions
        pluck(:version).map { |v| normalize_migration_number v }
      end

      def sorter(a, b)
        if ActiveRecord::Base.schema_migrations_by_invocation_time
          if a.created_at.nil?
            if b.created_at.nil?
              a.version <=> b.version
            else
              1
            end
          else
            if b.created_at.nil?
              -1
            else
              if a.created_at == b.created_at
                a.version <=> b.version
              else
                a.created_at <=> b.created_at
              end
            end
          end
        else
          a.version <=> b.version
        end
      end
    end

    def normalized_version
      self.class.normalize_migration_number(version)
    end

    def version
      super.to_i
    end
  end
end
