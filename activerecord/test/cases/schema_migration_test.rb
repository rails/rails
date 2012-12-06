require "cases/helper"

class SchemaMigrationTest < ActiveRecord::TestCase
  def sm_table_name
    ActiveRecord::SchemaMigration.table_name
  end

  def connection
    ActiveRecord::Base.connection
  end

  def test_add_schema_info_respects_prefix_and_suffix
    connection.drop_table(sm_table_name) if connection.table_exists?(sm_table_name)
    # Use shorter prefix and suffix as in Oracle database identifier cannot be larger than 30 characters
    ActiveRecord::Base.table_name_prefix = 'p_'
    ActiveRecord::Base.table_name_suffix = '_s'
    connection.drop_table(sm_table_name) if connection.table_exists?(sm_table_name)

    ActiveRecord::SchemaMigration.create_table

    assert_equal "p_unique_schema_migrations_s", connection.indexes(sm_table_name)[0][:name]
  ensure
    ActiveRecord::Base.table_name_prefix = ""
    ActiveRecord::Base.table_name_suffix = ""
  end

  def test_add_metadata_columns_to_exisiting_schema_migrations
    # creates the old table schema from pre-Rails4.0, so we can test adding to it below
    if connection.table_exists?(sm_table_name)
      connection.drop_table(sm_table_name)
    end
    connection.create_table(sm_table_name, :id => false) do |schema_migrations_table|
      schema_migrations_table.column("version", :string, :null => false)
    end

    connection.insert "INSERT INTO #{connection.quote_table_name(sm_table_name)} (version) VALUES (100)"
    connection.insert "INSERT INTO #{connection.quote_table_name(sm_table_name)} (version) VALUES (200)"

    ActiveRecord::SchemaMigration.create_table

    rows = connection.select_all("SELECT * FROM #{connection.quote_table_name(sm_table_name)}")
    assert rows[0].has_key?("migrated_at"), "missing column `migrated_at`"
    assert_match(/\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/, rows[0]["migrated_at"].to_s) # sometimes a String, sometimes a Time
    assert rows[0].has_key?("fingerprint"), "missing column `fingerprint`"
    assert rows[0].has_key?("name"), "missing column `name`"
  end

  def test_schema_migrations_columns
    ActiveRecord::SchemaMigration.create_table

    columns =  connection.columns(sm_table_name).collect(&:name)
    %w[version migrated_at fingerprint name].each { |col| assert columns.include?(col), "missing column `#{col}`" }
  end
end
