require 'active_record/scoping/default'
require 'active_record/scoping/named'

module ActiveRecord
  # This class is used to create a table that keeps track of which environment
  # migrations were run in. When a migration is run, its env value such as RAILS_ENV
  # is inserted in to the `EnvironmentCheck.table_name` we can later check aginst
  # this value before performing destructive actions.
  class EnvironmentCheck < ActiveRecord::Base
    class << self
      def primary_key
        nil
      end

      def table_name
        "#{table_name_prefix}#{ActiveRecord::Base.environment_check_table_name}#{table_name_suffix}"
      end

      def index_name
        "#{table_name_prefix}unique_#{ActiveRecord::Base.environment_check_table_name}#{table_name_suffix}"
      end

      def table_exists?
        ActiveSupport::Deprecation.silence { connection.table_exists?(table_name) }
      end

      # Creates a schema table with columns +environment+ and +version+
      def create_table
        unless table_exists?

          connection.create_table(table_name, id: false) do |t|
            t.column :environment, :string
            t.timestamps
          end
        end
      end

      def drop_table
        if table_exists?
          connection.remove_index table_name, name: index_name
          connection.drop_table(table_name)
        end
      end
    end
  end
end
