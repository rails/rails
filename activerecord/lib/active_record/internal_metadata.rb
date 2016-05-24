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

      def original_table_name
        "#{table_name_prefix}active_record_internal_metadatas#{table_name_suffix}"
      end

      def []=(key, value)
        find_or_initialize_by(key: key).update_attributes!(value: value)
      end

      def [](key)
        where(key: key).pluck(:value).first
      end

      def table_exists?
        ActiveSupport::Deprecation.silence { connection.table_exists?(table_name) }
      end

      def original_table_exists?
        # This method will be removed in Rails 5.1
        # Since it is only necessary when `active_record_internal_metadatas` could exist
        ActiveSupport::Deprecation.silence { connection.table_exists?(original_table_name) }
      end

      # Creates an internal metadata table with columns +key+ and +value+
      def create_table
        if original_table_exists?
          connection.rename_table(original_table_name, table_name)
        end
        unless table_exists?
          key_options = connection.internal_string_options_for_primary_key

          connection.create_table(table_name, id: false) do |t|
            t.string :key, key_options
            t.string :value
            t.timestamps
          end
        end
      end
    end
  end
end
