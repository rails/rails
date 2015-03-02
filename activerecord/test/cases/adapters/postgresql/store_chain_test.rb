require "cases/helper"
require 'support/schema_dumping_helper'

if ActiveRecord::Base.connection.supports_extensions?
  class PostgresqlStoreChainTest < ActiveRecord::TestCase
    class Hstore < ActiveRecord::Base
      self.table_name = 'hstores2'
    end

    def setup
      @connection = ActiveRecord::Base.connection

      unless @connection.extension_enabled?('hstore')
        @connection.enable_extension 'hstore'
        @connection.commit_db_transaction
      end

      @connection.reconnect!

      @connection.transaction do
        @connection.create_table('hstores2') do |t|
          t.string :name
          t.hstore :data
        end
      end

      Hstore.create!(name: 'a', data: { a: 1, b: 2, f: true })
      Hstore.create!(name: 'b', data: { a: 2 })
      Hstore.create!(name: 'c', data: { f: true })
      Hstore.create!(name: 'd', data: { f: false })
      Hstore.create!(name: 'e', data: { a: 2, c: 'x' })
    end

    teardown do
      @connection.drop_table 'hstores2', if_exists: true
    end

    def test_query_by_key_val
      assert_equal 'a', Hstore.where.store(:data, a: 1, b: 2).first.name
      assert_equal 'e', Hstore.where.store(:data, a: 2, c: 'x').first.name
      assert_equal 'd', Hstore.where.store(:data, f: false).first.name
    end

    def test_key_clause
      records = Hstore.where.store(:data).key(:a)
      assert_equal 3, records.size

      records = Hstore.where.store(:data).key(:b)
      assert_equal 1, records.size
      assert_equal 'a', records.first.name
    end

    def test_keys_clause
      records = Hstore.where.store(:data).keys('a', 'f')
      assert_equal 1, records.size
      assert_equal 'a', records.first.name

      records = Hstore.where.store(:data).keys(:a, :c)
      assert_equal 1, records.size
      assert_equal 'e', records.first.name
    end

    def test_any_clause
      records = Hstore.where.store(:data).any('b', 'f')
      assert_equal 3, records.size

      records = Hstore.where.store(:data).any(:c, :b)
      assert_equal 2, records.size
    end

    def test_contain_clause
      records = Hstore.where.store(:data).contain(f: true)
      assert_equal 2, records.size

      records = Hstore.where.store(:data).contain(a: 2, c: 'x')
      assert_equal 1, records.size
      assert_equal 'e', records.first.name
    end

    def test_contained_clause
      records = Hstore.where.store(:data).contained(a: 2, b: 2, f: true)
      assert_equal 2, records.size

      records = Hstore.where.store(:data).contained(c: 'x', f: false)
      assert_equal 1, records.size
      assert_equal 'd', records.first.name
    end
  end
end
