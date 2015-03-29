require "cases/helper"
require 'support/connection_helper'
require 'support/schema_dumping_helper'

class PostgresqlPointTest < ActiveRecord::TestCase
  include ConnectionHelper
  include SchemaDumpingHelper

  class PostgresqlPoint < ActiveRecord::Base; end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table('postgresql_points') do |t|
      t.point :x
      t.point :y, default: [12.2, 13.3]
      t.point :z, default: "(14.4,15.5)"
    end
  end

  teardown do
    @connection.drop_table 'postgresql_points', if_exists: true
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
    assert_equal [12.2, 13.3], PostgresqlPoint.column_defaults['y']
    assert_equal [12.2, 13.3], PostgresqlPoint.new.y

    assert_equal [14.4, 15.5], PostgresqlPoint.column_defaults['z']
    assert_equal [14.4, 15.5], PostgresqlPoint.new.z
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
    assert_equal [10, 25.2], record.x

    record.x = [1.1, 2.2]
    record.save!
    assert record.reload
    assert_equal [1.1, 2.2], record.x
  end

  def test_mutation
    p = PostgresqlPoint.create! x: [10, 20]

    p.x[1] = 25
    p.save!
    p.reload

    assert_equal [10.0, 25.0], p.x
    assert_not p.changed?
  end
end

class PostgresqlBoxTest < ActiveRecord::TestCase
  include ConnectionHelper
  include SchemaDumpingHelper

  class PostgresqlBox < ActiveRecord::Base; end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.create_table('postgresql_boxes') do |t|
      t.box :x
      t.box :y, default: [[11.1, 14.4], [13.3, 12.2]]
      t.box :z, default: "((21.1,22.2),(23.3,24.4))"
    end
  end

  teardown do
    @connection.drop_table 'postgresql_boxes', if_exists: true
  end

  def test_column
    column = PostgresqlBox.columns_hash["x"]
    assert_equal :box, column.type
    assert_equal "box", column.sql_type
    assert_not column.array?

    type = PostgresqlBox.type_for_attribute("x")
    assert_not type.binary?
  end

  def test_default
    # reordered to store upper right corner then bottom left corner:
    assert_equal [[13.3, 14.4], [11.1, 12.2]], PostgresqlBox.column_defaults['y']
    assert_equal [[13.3, 14.4], [11.1, 12.2]], PostgresqlBox.new.y

    # reordered to store upper right corner then bottom left corner:
    assert_equal [[23.3, 24.4], [21.1, 22.2]], PostgresqlBox.column_defaults['z']
    assert_equal [[23.3, 24.4], [21.1, 22.2]], PostgresqlBox.new.z
  end

  def test_schema_dumping
    output = dump_table_schema("postgresql_boxes")
    assert_match %r{t\.box\s+"x"$}, output
    assert_match %r{t\.box\s+"y",\s+default: \[\[13\.3, 14\.4\], \[11\.1, 12\.2\]\]$}, output
    assert_match %r{t\.box\s+"z",\s+default: \[\[23\.3, 24\.4\], \[21\.1, 22\.2\]\]$}, output
  end

  def test_roundtrip
    PostgresqlBox.create! x: [[11, 12.2], [13.3, 14]]
    record = PostgresqlBox.first
    assert_equal [[13.3, 14], [11, 12.2]], record.x

    record.x = [[1.1, 2.2], [3.3, 4.4]]
    record.save!
    assert record.reload
    assert_equal [[3.3, 4.4], [1.1, 2.2]], record.x
  end

  def test_mutation
    PostgresqlBox.create! x: [[10, 20], [31.1, 32.2]]
    record = PostgresqlBox.first

    record.x[0] = [31.5, 32.5]
    record.x[1][0] = 11
    record.save!
    record.reload

    assert_equal [[31.5, 32.5], [11.0, 20.0]], record.x
    assert_not record.changed?
  end
end

class PostgresqlGeometricTest < ActiveRecord::TestCase
  class PostgresqlGeometric < ActiveRecord::Base; end

  setup do
    @connection = ActiveRecord::Base.connection
    @connection.create_table("postgresql_geometrics") do |t|
      t.column :a_line_segment, :lseg
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
      :a_path         => '[(2.0, 3), (5.5, 7.0), (8.5, 11.0)]',
      :a_polygon      => '((2.0, 3), (5.5, 7.0), (8.5, 11.0))',
      :a_circle       => '<(5.3, 10.4), 2>'
    )

    g.save!

    h = PostgresqlGeometric.find(g.id)

    assert_equal '[(2,3),(5.5,7)]', h.a_line_segment
    assert_equal '[(2,3),(5.5,7),(8.5,11)]', h.a_path
    assert_equal '((2,3),(5.5,7),(8.5,11))', h.a_polygon
    assert_equal '<(5.3,10.4),2>', h.a_circle
  end

  def test_alternative_format
    g = PostgresqlGeometric.new(
      :a_line_segment => '((2.0, 3), (5.5, 7.0))',
      :a_path         => '((2.0, 3), (5.5, 7.0), (8.5, 11.0))',
      :a_polygon      => '2.0, 3, 5.5, 7.0, 8.5, 11.0',
      :a_circle       => '((5.3, 10.4), 2)'
    )

    g.save!

    h = PostgresqlGeometric.find(g.id)
    assert_equal '[(2,3),(5.5,7)]', h.a_line_segment
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
