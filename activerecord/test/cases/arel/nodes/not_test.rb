# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    describe "not" do
      describe "#not" do
        it "makes a NOT node" do
          attr = Table.new(:users)[:id]
          expr  = attr.eq(10)
          node  = expr.not
          _(node).must_be_kind_of Not
          _(node.expr).must_equal expr
        end
      end

      describe "equality" do
        it "is equal with equal ivars" do
          array = [Not.new("foo"), Not.new("foo")]
          assert_equal 1, array.uniq.size
        end

        it "is not equal with different ivars" do
          array = [Not.new("foo"), Not.new("baz")]
          assert_equal 2, array.uniq.size
        end
      end
    end
  end
end
