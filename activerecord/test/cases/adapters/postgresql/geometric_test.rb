# frozen_string_literal: true

require 'cases/helper'
require 'support/connection_helper'
require 'support/schema_dumping_helper'

class PostgresqlPointTest < ActiveRecord::PostgreSQLTestCase
  include ConnectionHelper
  include SchemaDumpingHelper

  class PostgresqlPoint < ActiveRecord::Base
    attribute :x, :point
    attribute :y, :point
    attribute :z, :point
    attribute :array_of_points, :point, array: true
    attribute :legacy_x, :legacy_point
    attribute :legacy_y, :legacy_point
    attribute :legacy_z, :legacy_point
  end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table('postgresql_points') do |t|
      t.point :x
      t.point :y, default: [12.2, 13.3]
      t.point :z, default: '(14.4,15.5)'
      t.point :array_of_points, array: true
      t.point :legacy_x
      t.point :legacy_y, default: [12.2, 13.3]
      t.point :legacy_z, default: '(14.4,15.5)'
    end
  end

  teardown do
    @connection.drop_table 'postgresql_points', if_exists: true
  end

  def test_column
    column = PostgresqlPoint.columns_hash['x']
    assert_equal :point, column.type
    assert_equal 'point', column.sql_type
    assert_not_predicate column, :array?

    type = PostgresqlPoint.type_for_attribute('x')
    assert_not_predicate type, :binary?
  end

  def test_default
    assert_equal ActiveRecord::Point.new(12.2, 13.3), PostgresqlPoint.column_defaults['y']
    assert_equal ActiveRecord::Point.new(12.2, 13.3), PostgresqlPoint.new.y

    assert_equal ActiveRecord::Point.new(14.4, 15.5), PostgresqlPoint.column_defaults['z']
    assert_equal ActiveRecord::Point.new(14.4, 15.5), PostgresqlPoint.new.z
  end

  def test_schema_dumping
    output = dump_table_schema('postgresql_points')
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
    assert_not_predicate p, :changed?
  end

  def test_array_assignment
    p = PostgresqlPoint.new(x: [1, 2])

    assert_equal ActiveRecord::Point.new(1, 2), p.x
  end

  def test_string_assignment
    p = PostgresqlPoint.new(x: '(1, 2)')

    assert_equal ActiveRecord::Point.new(1, 2), p.x
  end

  def test_empty_string_assignment
    p = PostgresqlPoint.new(x: '')
    assert_nil p.x
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
    column = PostgresqlPoint.columns_hash['legacy_x']
    assert_equal :point, column.type
    assert_equal 'point', column.sql_type
    assert_not_predicate column, :array?

    type = PostgresqlPoint.type_for_attribute('legacy_x')
    assert_not_predicate type, :binary?
  end

  def test_legacy_default
    assert_equal [12.2, 13.3], PostgresqlPoint.column_defaults['legacy_y']
    assert_equal [12.2, 13.3], PostgresqlPoint.new.legacy_y

    assert_equal [14.4, 15.5], PostgresqlPoint.column_defaults['legacy_z']
    assert_equal [14.4, 15.5], PostgresqlPoint.new.legacy_z
  end

  def test_legacy_schema_dumping
    output = dump_table_schema('postgresql_points')
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
    assert_not_predicate p, :changed?
  end
end

class PostgresqlGeometricTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  class PostgresqlGeometric < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table('postgresql_geometrics') do |t|
      t.lseg    :a_line_segment
      t.box     :a_box
      t.path    :a_path
      t.polygon :a_polygon
      t.circle  :a_circle
    end
  end

  teardown do
    @connection.drop_table 'postgresql_geometrics', if_exists: true
  end

  def test_geometric_types
    g = PostgresqlGeometric.new(
      a_line_segment: '(2.0, 3), (5.5, 7.0)',
      a_box: '2.0, 3, 5.5, 7.0',
      a_path: '[(2.0, 3), (5.5, 7.0), (8.5, 11.0)]',
      a_polygon: '((2.0, 3), (5.5, 7.0), (8.5, 11.0))',
      a_circle: '<(5.3, 10.4), 2>'
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
      a_line_segment: '((2.0, 3), (5.5, 7.0))',
      a_box: '(2.0, 3), (5.5, 7.0)',
      a_path: '((2.0, 3), (5.5, 7.0), (8.5, 11.0))',
      a_polygon: '2.0, 3, 5.5, 7.0, 8.5, 11.0',
      a_circle: '((5.3, 10.4), 2)'
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

    objs = PostgresqlGeometric.find_by_sql 'SELECT isopen(a_path) FROM postgresql_geometrics ORDER BY id ASC'
    assert_equal [true, false], objs.map(&:isopen)

    objs = PostgresqlGeometric.find_by_sql 'SELECT isclosed(a_path) FROM postgresql_geometrics ORDER BY id ASC'
    assert_equal [false, true], objs.map(&:isclosed)
  end

  def test_schema_dumping
    output = dump_table_schema('postgresql_geometrics')
    assert_match %r{t\.lseg\s+"a_line_segment"$}, output
    assert_match %r{t\.box\s+"a_box"$}, output
    assert_match %r{t\.path\s+"a_path"$}, output
    assert_match %r{t\.polygon\s+"a_polygon"$}, output
    assert_match %r{t\.circle\s+"a_circle"$}, output
  end
end

class PostgreSQLGeometricLineTest < ActiveRecord::PostgreSQLTestCase
  include SchemaDumpingHelper

  class PostgresqlLine < ActiveRecord::Base; end

  setup do
    unless ActiveRecord::Base.connection.database_version >= 90400
      skip('line type is not fully implemented')
    end
    @connection = ActiveRecord::Base.connection
    @connection.create_table('postgresql_lines') do |t|
      t.line :a_line
    end
  end

  teardown do
    if defined?(@connection)
      @connection.drop_table 'postgresql_lines', if_exists: true
    end
  end

  def test_geometric_line_type
    g = PostgresqlLine.new(
      a_line: '{2.0, 3, 5.5}'
    )
    g.save!

    h = PostgresqlLine.find(g.id)
    assert_equal '{2,3,5.5}', h.a_line
  end

  def test_alternative_format_line_type
    g = PostgresqlLine.new(
      a_line: '(2.0, 3), (4.0, 6.0)'
    )
    g.save!

    h = PostgresqlLine.find(g.id)
    assert_equal '{1.5,-1,0}', h.a_line
  end

  def test_schema_dumping_for_line_type
    output = dump_table_schema('postgresql_lines')
    assert_match %r{t\.line\s+"a_line"$}, output
  end
end

class PostgreSQLGeometricTypesTest < ActiveRecord::PostgreSQLTestCase
  attr_reader :connection, :table_name

  def setup
    super
    @connection = ActiveRecord::Base.connection
    @table_name = :testings
  end

  def test_creating_column_with_point_type
    connection.create_table(table_name) do |t|
      t.point :foo_point
    end

    assert_column_exists(:foo_point)
    assert_type_correct(:foo_point, :point)
  end

  def test_creating_column_with_line_type
    connection.create_table(table_name) do |t|
      t.line :foo_line
    end

    assert_column_exists(:foo_line)
    assert_type_correct(:foo_line, :line)
  end

  def test_creating_column_with_lseg_type
    connection.create_table(table_name) do |t|
      t.lseg :foo_lseg
    end

    assert_column_exists(:foo_lseg)
    assert_type_correct(:foo_lseg, :lseg)
  end

  def test_creating_column_with_box_type
    connection.create_table(table_name) do |t|
      t.box :foo_box
    end

    assert_column_exists(:foo_box)
    assert_type_correct(:foo_box, :box)
  end

  def test_creating_column_with_path_type
    connection.create_table(table_name) do |t|
      t.path :foo_path
    end

    assert_column_exists(:foo_path)
    assert_type_correct(:foo_path, :path)
  end

  def test_creating_column_with_polygon_type
    connection.create_table(table_name) do |t|
      t.polygon :foo_polygon
    end

    assert_column_exists(:foo_polygon)
    assert_type_correct(:foo_polygon, :polygon)
  end

  def test_creating_column_with_circle_type
    connection.create_table(table_name) do |t|
      t.circle :foo_circle
    end

    assert_column_exists(:foo_circle)
    assert_type_correct(:foo_circle, :circle)
  end

  private
    def assert_column_exists(column_name)
      assert connection.column_exists?(table_name, column_name)
    end

    def assert_type_correct(column_name, type)
      column = connection.columns(table_name).find { |c| c.name == column_name.to_s }
      assert_equal type, column.type
    end
end
