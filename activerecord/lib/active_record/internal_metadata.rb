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
    class NullInternalMetadata # :nodoc:
    end

    attr_reader :arel_table

    def initialize(pool)
      @pool = pool
      @arel_table = Arel::Table.new(table_name)
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

    def enabled?
      @pool.db_config.use_metadata_table?
    end

    def []=(key, value)
      return unless enabled?

      @pool.with_connection do |connection|
        update_or_create_entry(connection, key, value)
      end
    end

    def [](key)
      return unless enabled?

      @pool.with_connection do |connection|
        if entry = select_entry(connection, key)
          entry[value_key]
        end
      end
    end

    def delete_all_entries
      dm = Arel::DeleteManager.new(arel_table)

      @pool.with_connection do |connection|
        connection.delete(dm, "#{self.class} Destroy")
      end
    end

    def count
      sm = Arel::SelectManager.new(arel_table)
      sm.project(*Arel::Nodes::Count.new([Arel.star]))

      @pool.with_connection do |connection|
        connection.select_values(sm, "#{self.class} Count").first
      end
    end

    def create_table_and_set_flags(environment, schema_sha1 = nil)
      return unless enabled?

      @pool.with_connection do |connection|
        create_table
        update_or_create_entry(connection, :environment, environment)
        update_or_create_entry(connection, :schema_sha1, schema_sha1) if schema_sha1
      end
    end

    # Creates an internal metadata table with columns +key+ and +value+
    def create_table
      return unless enabled?

      @pool.with_connection do |connection|
        unless connection.table_exists?(table_name)
          connection.create_table(table_name, id: false) do |t|
            t.string :key, **connection.internal_string_options_for_primary_key
            t.string :value
            t.timestamps
          end
        end
      end
    end

    def drop_table
      return unless enabled?

      @pool.with_connection do |connection|
        connection.drop_table table_name, if_exists: true
      end
    end

    def table_exists?
      @pool.schema_cache.data_source_exists?(table_name)
    end

    private
      def update_or_create_entry(connection, key, value)
        entry = select_entry(connection, key)

        if entry
          if entry[value_key] != value
            update_entry(connection, key, value)
          else
            entry[value_key]
          end
        else
          create_entry(connection, key, value)
        end
      end

      def current_time(connection)
        connection.default_timezone == :utc ? Time.now.utc : Time.now
      end

      def create_entry(connection, key, value)
        im = Arel::InsertManager.new(arel_table)
        im.insert [
          [arel_table[primary_key], key],
          [arel_table[value_key], value],
          [arel_table[:created_at], current_time(connection)],
          [arel_table[:updated_at], current_time(connection)]
        ]

        connection.insert(im, "#{self.class} Create", primary_key, key)
      end

      def update_entry(connection, key, new_value)
        um = Arel::UpdateManager.new(arel_table)
        um.set [
          [arel_table[value_key], new_value],
          [arel_table[:updated_at], current_time(connection)]
        ]

        um.where(arel_table[primary_key].eq(key))

        connection.update(um, "#{self.class} Update")
      end

      def select_entry(connection, key)
        sm = Arel::SelectManager.new(arel_table)
        sm.project(Arel::Nodes::SqlLiteral.new("*", retryable: true))
        sm.where(arel_table[primary_key].eq(Arel::Nodes::BindParam.new(key)))
        sm.order(arel_table[primary_key].asc)
        sm.limit = 1

        connection.select_all(sm, "#{self.class} Load").first
      end
  end
end
