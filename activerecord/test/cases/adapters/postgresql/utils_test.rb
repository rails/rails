require 'cases/helper'

class PostgreSQLUtilsTest < ActiveSupport::TestCase
  include ActiveRecord::ConnectionAdapters::PostgreSQLAdapter::Utils

  def test_extract_schema_and_table
    {
      %(table_name)            => [nil,'table_name'],
      %("table.name")          => [nil,'table.name'],
      %(schema.table_name)     => %w{schema table_name},
      %("schema".table_name)   => %w{schema table_name},
      %(schema."table_name")   => %w{schema table_name},
      %("schema"."table_name") => %w{schema table_name},
      %("even spaces".table)   => ['even spaces','table'],
      %(schema."table.name")   => ['schema', 'table.name']
    }.each do |given, expect|
      assert_equal expect, extract_schema_and_table(given)
    end
  end
end
