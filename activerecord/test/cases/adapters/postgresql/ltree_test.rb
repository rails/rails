# encoding: utf-8

require "cases/helper"
require 'active_record/base'
require 'active_record/connection_adapters/postgresql_adapter'

class PostgresqlLtreeTest < ActiveRecord::TestCase
  class Ltree < ActiveRecord::Base
    self.table_name = 'ltrees'
  end

  def setup
    @connection = ActiveRecord::Base.connection
    begin
      @connection.transaction do
        @connection.create_table('ltrees') do |t|
          t.ltree 'path'
        end
      end
    rescue ActiveRecord::StatementInvalid
      return skip "do not test on PG without ltree"
    end
    @column = Ltree.columns.find { |c| c.name == 'path' }
  end

  def teardown
    @connection.execute 'drop table if exists ltrees'
  end

  def test_column
    assert_equal :ltree, @column.type
  end

  def test_write
    x = Ltree.new(:path => '1.2.3.4')
    assert x.save!
  end

  def test_select
    @connection.execute "insert into ltrees (path) VALUES ('1.2.3')"
    x = Ltree.first
    assert_equal('1.2.3', x.path)
  end
end
