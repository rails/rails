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

        @connection.create_table "mysql_doubles"
      end

      teardown do
        @connection.execute "drop table if exists mysql_doubles"
      end

      class MysqlDouble < ActiveRecord::Base
        self.table_name = "mysql_doubles"
      end

      def test_float_limits
        @connection.add_column :mysql_doubles, :float_no_limit, :float
        @connection.add_column :mysql_doubles, :float_short, :float, limit: 5
        @connection.add_column :mysql_doubles, :float_long, :float, limit: 53

        @connection.add_column :mysql_doubles, :float_23, :float, limit: 23
        @connection.add_column :mysql_doubles, :float_24, :float, limit: 24
        @connection.add_column :mysql_doubles, :float_25, :float, limit: 25
        MysqlDouble.reset_column_information

        column_no_limit = MysqlDouble.columns.find { |c| c.name == 'float_no_limit' }
        column_short = MysqlDouble.columns.find { |c| c.name == 'float_short' }
        column_long = MysqlDouble.columns.find { |c| c.name == 'float_long' }

        column_23 = MysqlDouble.columns.find { |c| c.name == 'float_23' }
        column_24 = MysqlDouble.columns.find { |c| c.name == 'float_24' }
        column_25 = MysqlDouble.columns.find { |c| c.name == 'float_25' }

        # Mysql floats are precision 0..24, Mysql doubles are precision 25..53
        assert_equal 24, column_no_limit.limit
        assert_equal 24, column_short.limit
        assert_equal 53, column_long.limit

        assert_equal 24, column_23.limit
        assert_equal 24, column_24.limit
        assert_equal 53, column_25.limit
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
