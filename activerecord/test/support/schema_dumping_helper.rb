# frozen_string_literal: true

module SchemaDumpingHelper
  def dump_table_schema(*tables)
    pool = ActiveRecord::Base.connection_pool
    old_ignore_tables = ActiveRecord.schema_ignored_tables
    pool.with_connection do |connection|
      ActiveRecord.schema_ignored_tables = connection.data_sources - tables
    end

    output, = capture_io do
      ActiveRecord::SchemaDumper.dump(pool)
    end
    output
  ensure
    ActiveRecord.schema_ignored_tables = old_ignore_tables
  end

  def dump_all_table_schema(ignore_tables = [], pool: ActiveRecord::Base.connection_pool)
    old_ignore_tables, ActiveRecord.schema_ignored_tables = ActiveRecord.schema_ignored_tables, ignore_tables
    output, = capture_io do
      ActiveRecord::SchemaDumper.dump(pool)
    end
    output
  ensure
    ActiveRecord.schema_ignored_tables = old_ignore_tables
  end
end
