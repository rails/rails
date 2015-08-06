require 'cases/helper'

module ActiveRecord
  class Migration
    class PostgreSQLGeometricTypesTest < ActiveRecord::TestCase
      attr_reader :connection, :table_name

      def setup
        super
        @connection = ActiveRecord::Base.connection
        @table_name = :testings
      end

      if current_adapter?(:PostgreSQLAdapter)
        def test_creating_column_with_point_type
          connection.create_table(table_name) do |t|
            t.point :foo_point
          end
          
          assert_column_exists(:foo_point)
          assert_type_correct(:foo_point, :point)
        end

        def test_creating_column_with_line_type
          connection.create_table(table_name) do |t|
            t.line :foo_line
          end
          
          assert_column_exists(:foo_line)
          assert_type_correct(:foo_line, :line)
        end

        def test_creating_column_with_lseg_type
          connection.create_table(table_name) do |t|
            t.lseg :foo_lseg
          end
          
          assert_column_exists(:foo_lseg)
          assert_type_correct(:foo_lseg, :lseg)
        end

        def test_creating_column_with_box_type
          connection.create_table(table_name) do |t|
            t.box :foo_box
          end
          
          assert_column_exists(:foo_box)
          assert_type_correct(:foo_box, :box)
        end

        def test_creating_column_with_path_type
          connection.create_table(table_name) do |t|
            t.path :foo_path
          end
          
          assert_column_exists(:foo_path)
          assert_type_correct(:foo_path, :path)
        end

        def test_creating_column_with_polygon_type
          connection.create_table(table_name) do |t|
            t.polygon :foo_polygon
          end
          
          assert_column_exists(:foo_polygon)
          assert_type_correct(:foo_polygon, :polygon)
        end

        def test_creating_column_with_circle_type
          connection.create_table(table_name) do |t|
            t.circle :foo_circle
          end
          
          assert_column_exists(:foo_circle)
          assert_type_correct(:foo_circle, :circle)
        end
      end

      private
        def assert_column_exists(column_name)
          columns = connection.columns(table_name)
          assert columns.map(&:name).include?(column_name.to_s)
        end

        def assert_type_correct(column_name, type)
          columns = connection.columns(table_name)
          column = columns.select{ |c| c.name == column_name.to_s }.first
          assert_equal type.to_s, column.sql_type
        end

    end
  end
end