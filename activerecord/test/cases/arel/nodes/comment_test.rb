# frozen_string_literal: true

require_relative "../helper"
require "yaml"

module Arel
  module Nodes
    class CommentTest < Arel::Test
      test "equality is equal with equal contents" do
        array = [Comment.new(["foo"]), Comment.new(["foo"])]
        assert_equal 1, array.uniq.size
      end

      test "equality is not equal with different contents" do
        array = [Comment.new(["foo"]), Comment.new(["bar"])]
        assert_equal 2, array.uniq.size
      end
    end
  end
end
