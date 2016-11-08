require "cases/helper"
require "models/topic"

module ActiveRecord
  module TypeCaster
    class MapTest < ActiveRecord::TestCase
      setup do
        @map = Map.new(Topic)
      end

      test "type casts based on column type" do
        casted = @map.type_cast_for_database("id", "100")
        assert_equal casted, 100
      end

      test "does not type cast BindParam" do
        bind_param = Arel::Nodes::BindParam.new
        casted = @map.type_cast_for_database("id", bind_param)
        assert_equal bind_param, casted
      end

      test "does not type cast SqlLiteral" do
        sql_literal = Arel::Nodes::SqlLiteral.new("foo")
        casted = @map.type_cast_for_database("id", sql_literal)
        assert_equal sql_literal, casted
      end
    end
  end
end
