# -*- coding: utf-8 -*-
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
    @connection.execute 'DROP TABLE IF EXISTS postgresql_points'
  end

  def test_column
    column = PostgresqlPoint.columns_hash["x"]
    assert_equal :point, column.type
    assert_equal "point", column.sql_type
    assert_not column.number?
    assert_not column.binary?
    assert_not column.array?
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

class PostgresqlGeometricTest < ActiveRecord::TestCase
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
    @connection.execute 'DROP TABLE IF EXISTS postgresql_geometrics'
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
