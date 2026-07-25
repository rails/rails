# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class CastedTest < Arel::Test
      test "#hash is equal when eql? returns true" do
        one = Casted.new 1, 2
        also_one = Casted.new 1, 2

        assert_equal one.hash, also_one.hash
      end
    end
  end
end
