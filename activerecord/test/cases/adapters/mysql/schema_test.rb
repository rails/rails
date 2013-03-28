require "cases/helper"
require 'models/post'
require 'models/comment'

module ActiveRecord
  module ConnectionAdapters
    class MysqlSchemaTest < ActiveRecord::TestCase
      fixtures :posts

      def setup
        @connection = ActiveRecord::Base.connection
        db          = Post.connection_pool.spec.config[:database]
        table       = Post.table_name
        @db_name    = db

        @omgpost = Class.new(ActiveRecord::Base) do
          self.table_name = "#{db}.#{table}"
          def self.name; 'Post'; end
        end
      end

      def test_schema
        assert @omgpost.first
      end

      def test_primary_key
        assert_equal 'id', @omgpost.primary_key
      end

      def test_table_exists?
        name = @omgpost.table_name
        assert @connection.table_exists?(name), "#{name} table should exist"
      end

      def test_table_exists_wrong_schema
        assert(!@connection.table_exists?("#{@db_name}.zomg"), "table should not exist")
      end

      def test_dump_indexes
        index_a_name = 'index_key_tests_on_snack'
        index_b_name = 'index_key_tests_on_pizza'
        index_c_name = 'index_key_tests_on_awesome'

        table = 'key_tests'

        indexes = @connection.indexes(table).sort_by {|i| i.name}
        assert_equal 3,indexes.size

        index_a = indexes.select{|i| i.name == index_a_name}[0]
        index_b = indexes.select{|i| i.name == index_b_name}[0]
        index_c = indexes.select{|i| i.name == index_c_name}[0]
        assert_equal :btree, index_a.using
        assert_nil index_a.type
        assert_equal :btree, index_b.using
        assert_nil index_b.type

        assert_nil index_c.using
        assert_equal :fulltext, index_c.type
      end
    end
  end
end
