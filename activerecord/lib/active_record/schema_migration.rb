require 'active_record/scoping/default'
require 'active_record/scoping/named'
require 'active_record/base'

module ActiveRecord
  class SchemaMigration < ActiveRecord::Base
    class << self
      def table_name
        "#{table_name_prefix}#{schema_migrations_table_name}#{table_name_suffix}"
      end

      def index_name
        "#{table_name_prefix}unique_#{schema_migrations_table_name}#{table_name_suffix}"
      end

      def table_exists?(conn = connection)
        conn.table_exists?(table_name)
      end

      def create_table(options = {})
        conn = fetch_connection(options)
        unless table_exists? conn
          version_options = { null: false }
          version_options[:limit] = options[:limit] if options[:limit]

          conn.create_table(table_name, id: false) do |t|
            t.column :version, :string, version_options
          end
          conn.add_index table_name, :version, unique: true, name: index_name
        end
      end

      def drop_table(options = {})
        conn = fetch_connection(options)
        if table_exists? conn
          conn.remove_index table_name, name: index_name
          conn.drop_table(table_name)
        end
      end

      def fetch_connection(options = {})
        options.fetch :connection, connection
      end
    end

    def version
      super.to_i
    end
  end
end
