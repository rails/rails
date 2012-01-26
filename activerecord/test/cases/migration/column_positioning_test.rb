require 'cases/helper'

module ActiveRecord
  class Migration
    class ColumnPositioningTest < ActiveRecord::TestCase
      attr_reader :connection, :table_name
      alias :conn :connection

      def setup
        super

        unless current_adapter?(:MysqlAdapter, :Mysql2Adapter)
          skip "not supported on #{connection.class}"
        end

        @connection = ActiveRecord::Base.connection

        connection.create_table :testings, id: false do |t|
          t.column :first, :integer
          t.column :second, :integer
          t.column :third, :integer
        end
      end

      def teardown
        super
        connection.drop_table :testings rescue nil
        ActiveRecord::Base.primary_key_prefix_type = nil
      end

      def test_column_positioning
        assert_equal %w(first second third), conn.columns(:testings).map {|c| c.name }
      end

      def test_add_column_with_positioning
        conn.add_column :testings, :new_col, :integer
        assert_equal %w(first second third new_col), conn.columns(:testings).map {|c| c.name }
      end

      def test_add_column_with_positioning_first
        conn.add_column :testings, :new_col, :integer, first: true
        assert_equal %w(new_col first second third), conn.columns(:testings).map {|c| c.name }
      end

      def test_add_column_with_positioning_after
        conn.add_column :testings, :new_col, :integer, after: :first
        assert_equal %w(first new_col second third), conn.columns(:testings).map {|c| c.name }
      end

      def test_change_column_with_positioning
        conn.change_column :testings, :second, :integer, first: true
        assert_equal %w(second first third), conn.columns(:testings).map {|c| c.name }

        conn.change_column :testings, :second, :integer, after: :third
        assert_equal %w(first third second), conn.columns(:testings).map {|c| c.name }
      end

    end
  end
end
