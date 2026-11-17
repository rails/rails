# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class FalseTest < Arel::Test
      test "equality is equal to other false nodes" do
        array = [False.new, False.new]
        assert_equal 1, array.uniq.size
      end

      test "equality is not equal with other nodes" do
        array = [False.new, Node.new]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
