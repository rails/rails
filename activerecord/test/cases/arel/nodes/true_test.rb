# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class TrueTest < Arel::Test
      test "equality is equal to other true nodes" do
        array = [True.new, True.new]
        assert_equal 1, array.uniq.size
      end

      test "equality is not equal with other nodes" do
        array = [True.new, Node.new]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
