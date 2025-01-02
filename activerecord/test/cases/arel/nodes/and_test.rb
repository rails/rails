# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class AndTest < Arel::Spec
      describe "equality" do
        it "is equal with equal ivars" do
          array = [And.new(["foo", "bar"]), And.new(["foo", "bar"])]
          assert_equal 1, array.uniq.size
        end

        it "is not equal with different ivars" do
          array = [And.new(["foo", "bar"]), And.new(["foo", "baz"])]
          assert_equal 2, array.uniq.size
        end
      end

      describe "functions as node expression" do
        it "allows aliasing" do
          aliased = And.new(["foo", "bar"]).as("baz")

          assert_kind_of As, aliased
          assert_kind_of SqlLiteral, aliased.right
        end
      end
    end
  end
end
