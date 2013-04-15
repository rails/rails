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
    @connection.transaction do
      @connection.create_table('ltrees') do |t|
        t.ltree 'path'
      end
    end
  rescue ActiveRecord::StatementInvalid
    skip "do not test on PG without ltree"
  end

  def teardown
    @connection.execute 'drop table if exists ltrees'
  end

  def test_column
    column = Ltree.columns_hash['path']
    assert_equal :ltree, column.type
  end

  def test_write
    ltree = Ltree.new(path: '1.2.3.4')
    assert ltree.save!
  end

  def test_select
    @connection.execute "insert into ltrees (path) VALUES ('1.2.3')"
    ltree = Ltree.first
    assert_equal '1.2.3', ltree.path
  end
end
