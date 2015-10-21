require "cases/helper"
require 'support/connection_helper'
require 'support/schema_dumping_helper'

class PostgresqlPointTest < ActiveRecord::PostgreSQLTestCase
  include ConnectionHelper
  include SchemaDumpingHelper

  class PostgresqlPoint < ActiveRecord::Base
    attribute :x, :rails_5_1_point
    attribute :y, :rails_5_1_point
    attribute :z, :rails_5_1_point
    attribute :array_of_points, :rails_5_1_point, array: true
    attribute :legacy_x, :legacy_point
    attribute :legacy_y, :legacy_point
    attribute :legacy_z, :legacy_point
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table('postgresql_points') do |t|
      t.point :x
      t.point :y, default: [12.2, 13.3]
      t.point :z, default: "(14.4,15.5)"
      t.point :array_of_points, array: true
      t.point :legacy_x
      t.point :legacy_y, default: [12.2, 13.3]
      t.point :legacy_z, default: "(14.4,15.5)"
    end
    @connection.create_table('deprecated_points') do |t|
      t.point :x
    end
  end

  teardown do
    @connection.drop_table 'postgresql_points', if_exists: true
    @connection.drop_table 'deprecated_points', if_exists: true
  end

  class DeprecatedPoint < ActiveRecord::Base; end

  def test_deprecated_legacy_type
    assert_deprecated do
      DeprecatedPoint.new
    end
  end

  def test_column
    column = PostgresqlPoint.columns_hash["x"]
    assert_equal :point, column.type
    assert_equal "point", column.sql_type
    assert_not column.array?

    type = PostgresqlPoint.type_for_attribute("x")
    assert_not type.binary?
  end

  def test_default
    assert_equal ActiveRecord::Point.new(12.2, 13.3), PostgresqlPoint.column_defaults['y']
    assert_equal ActiveRecord::Point.new(12.2, 13.3), PostgresqlPoint.new.y

    assert_equal ActiveRecord::Point.new(14.4, 15.5), PostgresqlPoint.column_defaults['z']
    assert_equal ActiveRecord::Point.new(14.4, 15.5), PostgresqlPoint.new.z
  end

  def test_schema_dumping
    output = dump_table_schema("postgresql_points")
    assert_match %r{t\.point\s+"x"$}, output
    assert_match %r{t\.point\s+"y",\s+default: \[12\.2, 13\.3\]$}, output
    assert_match %r{t\.point\s+"z",\s+default: \[14\.4, 15\.5\]$}, output
  end

  def test_roundtrip
    PostgresqlPoint.create! x: [10, 25.2]
    record = PostgresqlPoint.first
    assert_equal ActiveRecord::Point.new(10, 25.2), record.x

    record.x = ActiveRecord::Point.new(1.1, 2.2)
    record.save!
    assert record.reload
    assert_equal ActiveRecord::Point.new(1.1, 2.2), record.x
  end

  def test_mutation
    p = PostgresqlPoint.create! x: ActiveRecord::Point.new(10, 20)

    p.x.y = 25
    p.save!
    p.reload

    assert_equal ActiveRecord::Point.new(10.0, 25.0), p.x
    assert_not p.changed?
  end

  def test_array_assignment
    p = PostgresqlPoint.new(x: [1, 2])

    assert_equal ActiveRecord::Point.new(1, 2), p.x
  end

  def test_string_assignment
    p = PostgresqlPoint.new(x: "(1, 2)")

    assert_equal ActiveRecord::Point.new(1, 2), p.x
  end

  def test_array_of_points_round_trip
    expected_value = [
      ActiveRecord::Point.new(1, 2),
      ActiveRecord::Point.new(2, 3),
      ActiveRecord::Point.new(3, 4),
    ]
    p = PostgresqlPoint.new(array_of_points: expected_value)

    assert_equal expected_value, p.array_of_points
    p.save!
    p.reload
    assert_equal expected_value, p.array_of_points
  end

  def test_legacy_column
    column = PostgresqlPoint.columns_hash["legacy_x"]
    assert_equal :point, column.type
    assert_equal "point", column.sql_type
    assert_not column.array?

    type = PostgresqlPoint.type_for_attribute("legacy_x")
    assert_not type.binary?
  end

  def test_legacy_default
    assert_equal [12.2, 13.3], PostgresqlPoint.column_defaults['legacy_y']
    assert_equal [12.2, 13.3], PostgresqlPoint.new.legacy_y

    assert_equal [14.4, 15.5], PostgresqlPoint.column_defaults['legacy_z']
    assert_equal [14.4, 15.5], PostgresqlPoint.new.legacy_z
  end

  def test_legacy_schema_dumping
    output = dump_table_schema("postgresql_points")
    assert_match %r{t\.point\s+"legacy_x"$}, output
    assert_match %r{t\.point\s+"legacy_y",\s+default: \[12\.2, 13\.3\]$}, output
    assert_match %r{t\.point\s+"legacy_z",\s+default: \[14\.4, 15\.5\]$}, output
  end

  def test_legacy_roundtrip
    PostgresqlPoint.create! legacy_x: [10, 25.2]
    record = PostgresqlPoint.first
    assert_equal [10, 25.2], record.legacy_x

    record.legacy_x = [1.1, 2.2]
    record.save!
    assert record.reload
    assert_equal [1.1, 2.2], record.legacy_x
  end

  def test_legacy_mutation
    p = PostgresqlPoint.create! legacy_x: [10, 20]

    p.legacy_x[1] = 25
    p.save!
    p.reload

    assert_equal [10.0, 25.0], p.legacy_x
    assert_not p.changed?
  end
end

class PostgresqlGeometricTest < ActiveRecord::PostgreSQLTestCase
  class PostgresqlGeometric < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table("postgresql_geometrics") do |t|
      t.column :a_line_segment, :lseg
      t.column :a_box, :box
      t.column :a_path, :path
      t.column :a_polygon, :polygon
      t.column :a_circle, :circle
    end
  end

  teardown do
    @connection.drop_table 'postgresql_geometrics', if_exists: true
  end

  def test_geometric_types
    g = PostgresqlGeometric.new(
      :a_line_segment => '(2.0, 3), (5.5, 7.0)',
      :a_box          => '2.0, 3, 5.5, 7.0',
      :a_path         => '[(2.0, 3), (5.5, 7.0), (8.5, 11.0)]',
      :a_polygon      => '((2.0, 3), (5.5, 7.0), (8.5, 11.0))',
      :a_circle       => '<(5.3, 10.4), 2>'
    )

    g.save!

    h = PostgresqlGeometric.find(g.id)

    assert_equal '[(2,3),(5.5,7)]', h.a_line_segment
    assert_equal '(5.5,7),(2,3)', h.a_box # reordered to store upper right corner then bottom left corner
    assert_equal '[(2,3),(5.5,7),(8.5,11)]', h.a_path
    assert_equal '((2,3),(5.5,7),(8.5,11))', h.a_polygon
    assert_equal '<(5.3,10.4),2>', h.a_circle
  end

  def test_alternative_format
    g = PostgresqlGeometric.new(
      :a_line_segment => '((2.0, 3), (5.5, 7.0))',
      :a_box          => '(2.0, 3), (5.5, 7.0)',
      :a_path         => '((2.0, 3), (5.5, 7.0), (8.5, 11.0))',
      :a_polygon      => '2.0, 3, 5.5, 7.0, 8.5, 11.0',
      :a_circle       => '((5.3, 10.4), 2)'
    )

    g.save!

    h = PostgresqlGeometric.find(g.id)
    assert_equal '[(2,3),(5.5,7)]', h.a_line_segment
    assert_equal '(5.5,7),(2,3)', h.a_box   # reordered to store upper right corner then bottom left corner
    assert_equal '((2,3),(5.5,7),(8.5,11))', h.a_path
    assert_equal '((2,3),(5.5,7),(8.5,11))', h.a_polygon
    assert_equal '<(5.3,10.4),2>', h.a_circle
  end

  def test_geometric_function
    PostgresqlGeometric.create! a_path: '[(2.0, 3), (5.5, 7.0), (8.5, 11.0)]'  # [ ] is an open path
    PostgresqlGeometric.create! a_path: '((2.0, 3), (5.5, 7.0), (8.5, 11.0))'  # ( ) is a closed path

    objs = PostgresqlGeometric.find_by_sql "SELECT isopen(a_path) FROM postgresql_geometrics ORDER BY id ASC"
    assert_equal [true, false], objs.map(&:isopen)

    objs = PostgresqlGeometric.find_by_sql "SELECT isclosed(a_path) FROM postgresql_geometrics ORDER BY id ASC"
    assert_equal [false, true], objs.map(&:isclosed)
  end
end
