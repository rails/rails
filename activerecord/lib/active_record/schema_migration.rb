require 'active_record/scoping/default'
require 'active_record/scoping/named'
require 'active_record/base'

module ActiveRecord
  class SchemaMigration < ActiveRecord::Base

    def self.table_name
      "#{Base.table_name_prefix}schema_migrations#{Base.table_name_suffix}"
    end

    def self.index_name
      "#{Base.table_name_prefix}unique_schema_migrations#{Base.table_name_suffix}"
    end

    def self.create_table(limit=nil)
      unless connection.table_exists?(table_name)
        version_options = {null: false}
        version_options[:limit] = limit if limit

        connection.create_table(table_name, id: false) do |t|
          t.column :version, :string, version_options
        end
        connection.add_index table_name, :version, unique: true, name: index_name
      end
    end

    def self.drop_table
      if connection.table_exists?(table_name)
        connection.remove_index table_name, name: index_name
        connection.drop_table(table_name)
      end
    end

    def version
      super.to_i
    end
  end
end
