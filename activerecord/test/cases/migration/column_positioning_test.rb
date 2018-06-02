# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class Migration
    class ColumnPositioningTest < ActiveRecord::TestCase
      attr_reader :connection
      alias :conn :connection

      def setup
        super

        @connection = ActiveRecord::Base.connection

        connection.create_table :testings, id: false do |t|
          t.column :first, :integer
          t.column :second, :integer
          t.column :third, :integer
        end
      end

      teardown do
        connection.drop_table :testings rescue nil
        ActiveRecord::Base.primary_key_prefix_type = nil
      end

      if current_adapter?(:Mysql2Adapter)
        def test_column_positioning
          assert_equal %w(first second third), conn.columns(:testings).map(&:name)
        end

        def test_add_column_with_positioning
          conn.add_column :testings, :new_col, :integer
          assert_equal %w(first second third new_col), conn.columns(:testings).map(&:name)
        end

        def test_add_column_with_positioning_first
          conn.add_column :testings, :new_col, :integer, first: true
          assert_equal %w(new_col first second third), conn.columns(:testings).map(&:name)
        end

        def test_add_column_with_positioning_after
          conn.add_column :testings, :new_col, :integer, after: :first
          assert_equal %w(first new_col second third), conn.columns(:testings).map(&:name)
        end

        def test_change_column_with_positioning
          conn.change_column :testings, :second, :integer, first: true
          assert_equal %w(second first third), conn.columns(:testings).map(&:name)

          conn.change_column :testings, :second, :integer, after: :third
          assert_equal %w(first third second), conn.columns(:testings).map(&:name)
        end

        def test_add_reference_with_positioning_first
          conn.add_reference :testings, :new, polymorphic: true, first: true
          assert_equal %w(new_id new_type first second third), conn.columns(:testings).map(&:name)
        end

        def test_add_reference_with_positioning_after
          conn.add_reference :testings, :new, polymorphic: true, after: :first
          assert_equal %w(first new_id new_type second third), conn.columns(:testings).map(&:name)
        end
      end
    end
  end
end
