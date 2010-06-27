require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class SQLite3AdapterTest < ActiveRecord::TestCase
      def test_connection_no_db
        assert_raises(ArgumentError) do
          Base.sqlite3_connection {}
        end
      end

      def test_connection_no_adapter
        assert_raises(ArgumentError) do
          Base.sqlite3_connection :database => ':memory:'
        end
      end

      def test_connection_wrong_adapter
        assert_raises(ArgumentError) do
          Base.sqlite3_connection :database => ':memory:',:adapter => 'vuvuzela'
        end
      end

      def test_bad_timeout
        assert_raises(TypeError) do
          Base.sqlite3_connection :database => ':memory:',
                                  :adapter => 'sqlite3',
                                  :timeout => 'usa'
        end
      end

      # connection is OK with a nil timeout
      def test_nil_timeout
        conn = Base.sqlite3_connection :database => ':memory:',
                                       :adapter => 'sqlite3',
                                       :timeout => nil
        assert conn, 'made a connection'
      end

      def test_connect
        conn = Base.sqlite3_connection :database => ':memory:',
                                       :adapter => 'sqlite3',
                                       :timeout => 100
        assert conn, 'should have connection'
      end

      # sqlite3 defaults to UTF-8 encoding
      def test_encoding
        conn = Base.sqlite3_connection :database => ':memory:',
                                       :adapter => 'sqlite3',
                                       :timeout => 100
        assert_equal 'UTF-8', conn.encoding
      end
    end
  end
end
