# frozen_string_literal: true

require "cases/helper"

class SpatialTypeTest < ActiveRecord::AbstractMysqlTestCase
  self.use_transactional_tests = false

  setup do
    @connection = ActiveRecord::Base.lease_connection
    @connection.create_table("spatial_types", force: true) do |t|
      t.column :coordinates, "point"
      t.column :waypoints, "multipoint"
    end
  end

  teardown do
    @connection.drop_table "spatial_types", if_exists: true
  end

  test "POINT and MULTIPOINT columns are not misreported as integers" do
    columns = @connection.columns("spatial_types").index_by(&:name)

    assert_nil columns["coordinates"].type
    assert_nil columns["waypoints"].type
  end
end
