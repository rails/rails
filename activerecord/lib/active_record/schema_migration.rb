# frozen_string_literal: true

module ActiveRecord
  # This class is used to create a table that keeps track of which migrations
  # have been applied to a given database. When a migration is run, its schema
  # number is inserted in to the schema migrations table so it doesn't need
  # to be executed the next time.
  class SchemaMigration # :nodoc:
    class NullSchemaMigration # :nodoc:
    end

    attr_reader :arel_table

    def initialize(pool)
      @pool = pool
      @arel_table = Arel::Table.new(table_name)
    end

    def create_version(version)
      im = Arel::InsertManager.new(arel_table)
      im.insert(arel_table[primary_key] => version)
      @pool.with_connection do |connection|
        connection.insert(im, "#{self.class} Create", primary_key, version)
      end
    end

    def delete_version(version)
      dm = Arel::DeleteManager.new(arel_table)
      dm.wheres = [arel_table[primary_key].eq(version)]

      @pool.with_connection do |connection|
        connection.delete(dm, "#{self.class} Destroy")
      end
    end

    def delete_all_versions
      # Eagerly check in connection to avoid checking in/out many times in the called method.
      @pool.with_connection do
        versions.each do |version|
          delete_version(version)
        end
      end
    end

    def primary_key
      "version"
    end

    def table_name
      "#{ActiveRecord::Base.table_name_prefix}#{ActiveRecord::Base.schema_migrations_table_name}#{ActiveRecord::Base.table_name_suffix}"
    end

    def create_table
      @pool.with_connection do |connection|
        unless connection.table_exists?(table_name)
          connection.create_table(table_name, id: false) do |t|
            t.string :version, **connection.internal_string_options_for_primary_key
          end
        end
      end
    end

    def drop_table
      @pool.with_connection do |connection|
        connection.drop_table table_name, if_exists: true
      end
    end

    def normalize_migration_number(number)
      "%.3d" % number.to_i
    end

    def normalized_versions
      versions.map { |v| normalize_migration_number v }
    end

    def versions
      sm = Arel::SelectManager.new(arel_table)
      sm.project(arel_table[primary_key])
      sm.order(arel_table[primary_key].asc)

      @pool.with_connection do |connection|
        connection.select_values(sm, "#{self.class} Load")
      end
    end

    def integer_versions
      versions.map(&:to_i)
    end

    def count
      sm = Arel::SelectManager.new(arel_table)
      sm.project(*Arel::Nodes::Count.new([Arel.star]))

      @pool.with_connection do |connection|
        connection.select_values(sm, "#{self.class} Count").first
      end
    end

    def table_exists?
      @pool.with_connection do |connection|
        connection.data_source_exists?(table_name)
      end
    end
  end
end
