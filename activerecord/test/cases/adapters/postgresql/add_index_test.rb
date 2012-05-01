require "cases/helper"
require 'models/developer'

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      class IndexTest < ActiveRecord::TestCase
        def setup
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
            alias_method :real_execute, :execute
            remove_method :execute
            def execute(sql, name = nil) sql end
          end
          @conn = ActiveRecord::Base.connection
        end

        def teardown
          ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
            remove_method :execute
            alias_method :execute, :real_execute
          end
        end

        def test_add_index_custom_types
          table = :developers
          column = :name

          %w(gin gist hash btree).each do |method|
            expected = "CREATE  INDEX \"#{@conn.index_name(table, column)}\" ON \"#{table}\" USING #{method} (\"#{column}\")"
            assert_equal expected, @conn.add_index(table, column, :method => method)
          end
        end
      end
    end
  end
end
