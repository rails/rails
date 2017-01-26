require "cases/helper"
require "support/schema_dumping_helper"

class Mysql2SpatialTypesTest < ActiveRecord::Mysql2TestCase
  include SchemaDumpingHelper
  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table("spatial_types", force: true) do |t|
      t.geometry   :geometry_field
      t.polygon    :polygon_field, null:false, index:{ type: :spatial}
      t.point      :point_field
      t.linestring :linestring_field
    end
  end

  teardown do
    @connection.drop_table "spatial_types", if_exists: true
  end

  test "schema dump includes spatial types" do
    schema = dump_table_schema "spatial_types"
    assert_match %r{t.geometry\s+"geometry_field"$}, schema
    assert_match %r{t.polygon\s+"polygon_field",\s+null: false$}, schema
    assert_match %r{t.point\s+"point_field"$}, schema
    assert_match %r{t.linestring\s+"linestring_field"$}, schema
  end

  test "schema dump can be restored" do
    schema = dump_table_schema "spatial_types"
    @connection.drop_table "spatial_types", if_exists: true
    silence_stdout{ eval schema }
    schema2 = dump_table_schema "spatial_types"
    assert_equal schema, schema2
  end

end
