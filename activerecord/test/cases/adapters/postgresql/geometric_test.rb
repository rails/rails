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
    @connection.transaction do
      @connection.create_table('postgresql_points') do |t|
        t.point :x
        t.point :y, default: [12.2, 13.3]
        t.point :z, default: "(14.4,15.5)"
      end
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
    assert_not column.array
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
