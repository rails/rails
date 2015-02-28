require "cases/helper"

class Mysql2BooleanTest < ActiveRecord::TestCase
  self.use_transactional_fixtures = false

  class BooleanType < ActiveRecord::Base
    self.table_name = "mysql_booleans"
  end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.clear_cache!
    @connection.create_table("mysql_booleans") do |t|
      t.boolean "archived"
      t.string "published", limit: 1
    end
    BooleanType.reset_column_information

    @emulate_booleans = ActiveRecord::ConnectionAdapters::Mysql2Adapter.emulate_booleans
  end

  teardown do
    emulate_booleans @emulate_booleans
    @connection.drop_table "mysql_booleans"
  end

  test "column type with emulated booleans" do
    emulate_booleans true

    assert_equal :boolean, boolean_column.type
    assert_equal :string, string_column.type
  end

  test "column type without emulated booleans" do
    emulate_booleans false

    assert_equal :integer, boolean_column.type
    assert_equal :string, string_column.type
  end

  test "test type casting with emulated booleans" do
    emulate_booleans true

    boolean = BooleanType.create!(archived: true, published: true)
    attributes = boolean.reload.attributes_before_type_cast

    assert_equal 1, attributes["archived"]
    assert_equal "1", attributes["published"]

    assert_equal 1, @connection.type_cast(true)
  end

  test "test type casting without emulated booleans" do
    emulate_booleans false

    boolean = BooleanType.create!(archived: true, published: true)
    attributes = boolean.reload.attributes_before_type_cast

    assert_equal 1, attributes["archived"]
    assert_equal "1", attributes["published"]

    assert_equal 1, @connection.type_cast(true)
  end

  test "with booleans stored as 1 and 0" do
    @connection.execute "INSERT INTO mysql_booleans(archived, published) VALUES(1, '1')"
    boolean = BooleanType.first
    assert_equal true, boolean.archived
    assert_equal "1", boolean.published
  end

  test "with booleans stored as t" do
    @connection.execute "INSERT INTO mysql_booleans(published) VALUES('t')"
    boolean = BooleanType.first
    assert_equal "t", boolean.published
  end

  def boolean_column
    BooleanType.columns.find { |c| c.name == 'archived' }
  end

  def string_column
    BooleanType.columns.find { |c| c.name == 'published' }
  end

  def emulate_booleans(value)
    ActiveRecord::ConnectionAdapters::Mysql2Adapter.emulate_booleans = value
    BooleanType.reset_column_information
  end
end
