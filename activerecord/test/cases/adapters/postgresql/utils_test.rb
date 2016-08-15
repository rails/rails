require "cases/helper"
require "active_record/connection_adapters/postgresql/utils"

class PostgreSQLUtilsTest < ActiveRecord::PostgreSQLTestCase
  Name = ActiveRecord::ConnectionAdapters::PostgreSQL::Name
  include ActiveRecord::ConnectionAdapters::PostgreSQL::Utils

  def test_extract_schema_qualified_name
    {
      %(table_name)            => [nil,"table_name"],
      %("table.name")          => [nil,"table.name"],
      %(schema.table_name)     => %w{schema table_name},
      %("schema".table_name)   => %w{schema table_name},
      %(schema."table_name")   => %w{schema table_name},
      %("schema"."table_name") => %w{schema table_name},
      %("even spaces".table)   => ["even spaces","table"],
      %(schema."table.name")   => ["schema", "table.name"]
    }.each do |given, expect|
      assert_equal Name.new(*expect), extract_schema_qualified_name(given)
    end
  end
end

class PostgreSQLNameTest < ActiveRecord::PostgreSQLTestCase
  Name = ActiveRecord::ConnectionAdapters::PostgreSQL::Name

  test "represents itself as schema.name" do
    obj = Name.new("public", "articles")
    assert_equal "public.articles", obj.to_s
  end

  test "without schema, represents itself as name only" do
    obj = Name.new(nil, "articles")
    assert_equal "articles", obj.to_s
  end

  test "quoted returns a string representation usable in a query" do
    assert_equal %("articles"), Name.new(nil, "articles").quoted
    assert_equal %("public"."articles"), Name.new("public", "articles").quoted
  end

  test "prevents double quoting" do
    name = Name.new('"quoted_schema"', '"quoted_table"')
    assert_equal "quoted_schema.quoted_table", name.to_s
    assert_equal %("quoted_schema"."quoted_table"), name.quoted
  end

  test "equality based on state" do
    assert_equal Name.new("access", "users"), Name.new("access", "users")
    assert_equal Name.new(nil, "users"), Name.new(nil, "users")
    assert_not_equal Name.new(nil, "users"), Name.new("access", "users")
    assert_not_equal Name.new("access", "users"), Name.new("public", "users")
    assert_not_equal Name.new("public", "users"), Name.new("public", "articles")
  end

  test "can be used as hash key" do
    hash = {Name.new("schema", "article_seq") => "success"}
    assert_equal "success", hash[Name.new("schema", "article_seq")]
    assert_equal nil, hash[Name.new("schema", "articles")]
    assert_equal nil, hash[Name.new("public", "article_seq")]
  end
end
