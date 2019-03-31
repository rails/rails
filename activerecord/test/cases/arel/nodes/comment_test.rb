# frozen_string_literal: true

require_relative "../helper"
require "yaml"

module Arel
  module Nodes
    class CommentTest < Arel::Spec
      describe "equality" do
        it "is equal with equal contents" do
          array = [Comment.new(["foo"]), Comment.new(["foo"])]
          assert_equal 1, array.uniq.size
        end

        it "is not equal with different contents" do
          array = [Comment.new(["foo"]), Comment.new(["bar"])]
          assert_equal 2, array.uniq.size
        end
      end
    end
  end
end
