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


        def test_add_index_type_gin
          table = :developers
          column = :name
          assert_equal %(CREATE INDEX \"#{@conn.index_name(table, column)}\" ON \"#{table}\" USING gin(\"#{column}\")), @conn.add_index(table, column, :gin => true)
        end

        def test_add_index_type_gist
          table = :developers
          column = :name
          assert_equal %(CREATE INDEX \"#{@conn.index_name(table, column)}\" ON \"#{table}\" USING gist(\"#{column}\")), @conn.add_index(table, column, :gist => true)
        end
      end
    end
  end
end
