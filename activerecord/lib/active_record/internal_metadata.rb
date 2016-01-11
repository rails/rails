require 'active_record/scoping/default'
require 'active_record/scoping/named'

module ActiveRecord
  # This class is used to create a table that keeps track of values and keys such
  # as which environment migrations were run in.
  class InternalMetadata < ActiveRecord::Base # :nodoc:
    class << self
      def primary_key
        "key"
      end

      def table_name
        "#{table_name_prefix}#{ActiveRecord::Base.internal_metadata_table_name}#{table_name_suffix}"
      end

      def index_name
        "#{table_name_prefix}unique_#{ActiveRecord::Base.internal_metadata_table_name}#{table_name_suffix}"
      end

      def []=(key, value)
        first_or_initialize(key: key).update_attributes!(value: value)
      end

      def [](key)
        where(key: key).pluck(:value).first
      end

      def table_exists?
        ActiveSupport::Deprecation.silence { connection.table_exists?(table_name) }
      end

      # Creates an internal metadata table with columns +key+ and +value+
      def create_table
        unless table_exists?
          connection.create_table(table_name, id: false) do |t|
            t.column :key,   :string
            t.column :value, :string
            t.timestamps
            t.index  :key, unique: true, name: index_name
          end
        end
      end
    end
  end
end
