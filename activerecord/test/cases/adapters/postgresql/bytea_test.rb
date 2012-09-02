# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlByteaTest < ActiveRecord::TestCase
  class Bytea < ActiveRecord::Base
    self.table_name = 'byteas'
  end

  Binary = Array.new(255){|i| i.chr}.join

  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.transaction do
        @connection.create_table(Bytea.table_name) do |t|
          t.binary 'data', :default => nil
        end
      end
    end
    @column = Bytea.columns.find { |c| c.name == 'data' }
  end

  def teardown
    @connection.execute "drop table if exists #{ Bytea.table_name }"
  end

  def test_column
    assert_equal :binary, @column.type
  end

  def test_cycle
    assert_cycle Binary
  end

  def test_unhex_bytea
    assert_equal 'foobar', unhex_bytea('\\\\x666f6f626172')
  end

# c.query("select ''::bytea").values[0][0]
  private
  def assert_cycle data
    # test creation
    x = Bytea.create!(:data => data)
    x.reload
    assert_equal(data, x.data)

    # test updating
    x = Bytea.create!(:data => nil)
    x.data = data
    x.save!
    x.reload
    assert_equal(data, x.data)
  end

  def unhex_bytea(data)
    @connection.unhex_bytea(data)
  end
end
