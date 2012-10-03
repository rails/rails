require "cases/helper"
require 'models/post'
require 'models/comment'

module ActiveRecord
  module ConnectionAdapters
    class Mysql2SchemaTest < ActiveRecord::TestCase
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

      def test_tables_quoting
        begin
          @connection.tables(nil, "foo-bar", nil)
          flunk
        rescue => e
          # assertion for *quoted* database properly
          assert_match(/database 'foo-bar'/, e.inspect)
        end
      end

      def test_dump_indexes
        index_a_name = 'index_post_title'
        index_b_name = 'index_post_body'

        table = Post.table_name

        @connection.execute "CREATE INDEX `#{index_a_name}` ON `#{table}` (`title`);"
        @connection.execute "CREATE INDEX `#{index_b_name}` USING btree ON `#{table}` (`body`(10));"

        indexes = @connection.indexes(table).sort_by {|i| i.name}
        assert_equal 2,indexes.size

        assert_equal :btree, indexes.select{|i| i.name == index_a_name}[0].type
        assert_equal :btree, indexes.select{|i| i.name == index_b_name}[0].type

        @connection.execute "DROP INDEX `#{index_a_name}` ON `#{table}`;"
        @connection.execute "DROP INDEX `#{index_b_name}` ON `#{table}`;"
      end
    end
  end
end
