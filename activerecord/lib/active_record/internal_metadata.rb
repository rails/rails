# frozen_string_literal: true

require 'active_record/scoping/default'
require 'active_record/scoping/named'

module ActiveRecord
  # This class is used to create a table that keeps track of values and keys such
  # as which environment migrations were run in.
  #
  # This is enabled by default. To disable this functionality set
  # `use_metadata_table` to false in your database configuration.
  class InternalMetadata < ActiveRecord::Base # :nodoc:
    class << self
      def enabled?
        ActiveRecord::Base.connection.use_metadata_table?
      end

      def _internal?
        true
      end

      def primary_key
        'key'
      end

      def table_name
        "#{table_name_prefix}#{internal_metadata_table_name}#{table_name_suffix}"
      end

      def []=(key, value)
        return unless enabled?

        find_or_initialize_by(key: key).update!(value: value)
      end

      def [](key)
        return unless enabled?

        where(key: key).pluck(:value).first
      end

      # Creates an internal metadata table with columns +key+ and +value+
      def create_table
        return unless enabled?

        unless table_exists?
          key_options = connection.internal_string_options_for_primary_key

          connection.create_table(table_name, id: false) do |t|
            t.string :key, **key_options
            t.string :value
            t.timestamps
          end
        end
      end

      def drop_table
        return unless enabled?

        connection.drop_table table_name, if_exists: true
      end
    end
  end
end
