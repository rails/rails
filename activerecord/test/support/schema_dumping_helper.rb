# frozen_string_literal: true

module SchemaDumpingHelper
  def dump_table_schema(*tables)
    connection = ActiveRecord::Base.connection
    old_ignore_tables = ActiveRecord::SchemaDumper.ignore_tables
    ActiveRecord::SchemaDumper.ignore_tables = connection.data_sources - tables

    output, = capture_io do
      ActiveRecord::SchemaDumper.dump(connection)
    end
    output
  ensure
    ActiveRecord::SchemaDumper.ignore_tables = old_ignore_tables
  end

  def dump_all_table_schema(ignore_tables = [], connection: ActiveRecord::Base.connection)
    old_ignore_tables, ActiveRecord::SchemaDumper.ignore_tables = ActiveRecord::SchemaDumper.ignore_tables, ignore_tables
    output, = capture_io do
      ActiveRecord::SchemaDumper.dump(connection)
    end
    output
  ensure
    ActiveRecord::SchemaDumper.ignore_tables = old_ignore_tables
  end
end
