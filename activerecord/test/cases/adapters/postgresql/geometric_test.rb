# -*- coding: utf-8 -*-
require "cases/helper"
require 'support/connection_helper'
require 'support/schema_dumping_helper'
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlPointTest < ActiveRecord::TestCase
  include ConnectionHelper
  include SchemaDumpingHelper

  class PostgresqlPoint < ActiveRecord::Base; end

  def setup
    @connection = ActiveRecord::Base.connection
    @connection.transaction do
      @connection.create_table('postgresql_points') do |t|
        t.column :x, :point
        t.column :y, :point, default: [12.2, 13.3]
        t.column :z, :point, default: "(14.4,15.5)"
      end
    end
  end

  teardown do
    @connection.execute 'DROP TABLE IF EXISTS postgresql_points'
  end

  def test_column
    column = PostgresqlPoint.columns_hash["x"]
    assert_equal :string, column.type
    assert_equal "point", column.sql_type
    assert column.text?
    assert_not column.number?
    assert_not column.binary?
    assert_not column.array
  end

  def test_default
    column = PostgresqlPoint.columns_hash["y"]
    assert_equal [12.2, 13.3], column.default
    assert_equal [12.2, 13.3], PostgresqlPoint.new.y

    column = PostgresqlPoint.columns_hash["z"]
    assert_equal [14.4, 15.5], column.default
    assert_equal [14.4, 15.5], PostgresqlPoint.new.z
  end

  def test_schema_dumping
    output = dump_table_schema("postgresql_points")
    assert_match %r{t\.string\s+"x"$}, output
    assert_match %r{t\.string\s+"y",\s+default: \[12\.2, 13\.3\]$}, output
    assert_match %r{t\.string\s+"z",\s+default: \[14\.4, 15\.5\]$}, output
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
end
