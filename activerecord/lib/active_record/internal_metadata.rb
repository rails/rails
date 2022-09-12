# frozen_string_literal: true

require "active_record/scoping/default"
require "active_record/scoping/named"

module ActiveRecord
  # This class is used to create a table that keeps track of values and keys such
  # as which environment migrations were run in.
  #
  # This is enabled by default. To disable this functionality set
  # `use_metadata_table` to false in your database configuration.
  class InternalMetadata # :nodoc:
    class NullInternalMetadata
    end

    attr_reader :connection, :arel_table

    def initialize(connection)
      @connection = connection
      @arel_table = Arel::Table.new(table_name)
    end

    def enabled?
      connection.use_metadata_table?
    end

    def primary_key
      "key"
    end

    def value_key
      "value"
    end

    def table_name
      "#{ActiveRecord::Base.table_name_prefix}#{ActiveRecord::Base.internal_metadata_table_name}#{ActiveRecord::Base.table_name_suffix}"
    end

    def []=(key, value)
      return unless enabled?

      update_or_create_entry(key, value)
    end

    def [](key)
      return unless enabled?

      if entry = select_entry(key)
        entry[value_key]
      end
    end

    def delete_all_entries
      dm = Arel::DeleteManager.new(arel_table)

      connection.delete(dm, "#{self} Destroy")
    end

    def count
      sm = Arel::SelectManager.new(arel_table)
      sm.project(*Arel::Nodes::Count.new([Arel.star]))
      connection.select_values(sm).first
    end

    def create_table_and_set_flags(environment, schema_sha1 = nil)
      create_table
      update_or_create_entry(:environment, environment)
      update_or_create_entry(:schema_sha1, schema_sha1) if schema_sha1
    end

    # Creates an internal metadata table with columns +key+ and +value+
    def create_table
      return unless enabled?

      unless connection.table_exists?(table_name)
        connection.create_table(table_name, id: false) do |t|
          t.string :key, **connection.internal_string_options_for_primary_key
          t.string :value
          t.timestamps
        end
      end
    end

    def drop_table
      return unless enabled?

      connection.drop_table table_name, if_exists: true
    end

    def table_exists?
      connection.schema_cache.data_source_exists?(table_name)
    end

    private
      def update_or_create_entry(key, value)
        entry = select_entry(key)

        if entry
          update_entry(key, value)
        else
          create_entry(key, value)
        end
      end

      def current_time
        connection.default_timezone == :utc ? Time.now.utc : Time.now
      end

      def create_entry(key, value)
        im = Arel::InsertManager.new(arel_table)
        im.insert [
          [arel_table[primary_key], key],
          [arel_table[value_key], value],
          [arel_table[:created_at], current_time],
          [arel_table[:updated_at], current_time]
        ]

        connection.insert(im, "#{self} Create", primary_key, key)
      end

      def update_entry(key, new_value)
        um = Arel::UpdateManager.new(arel_table)
        um.set [
          [arel_table[value_key], new_value],
          [arel_table[:updated_at], current_time]
        ]

        um.where(arel_table[primary_key].eq(key))

        connection.update(um, "#{self} Update")
      end

      def select_entry(key)
        sm = Arel::SelectManager.new(arel_table)
        sm.project(Arel::Nodes::SqlLiteral.new("*"))
        sm.where(arel_table[primary_key].eq(Arel::Nodes::BindParam.new(key)))
        sm.order(arel_table[primary_key].asc)
        sm.limit = 1

        connection.select_all(sm).first
      end
  end
end
