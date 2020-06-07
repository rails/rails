# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class GroupingTest < Arel::Spec
      it "should create Equality nodes" do
        grouping = Grouping.new(Nodes.build_quoted("foo"))
        _(grouping.eq("foo").to_sql).must_be_like "('foo') = 'foo'"
      end

      describe "equality" do
        it "is equal with equal ivars" do
          array = [Grouping.new("foo"), Grouping.new("foo")]
          assert_equal 1, array.uniq.size
        end

        it "is not equal with different ivars" do
          array = [Grouping.new("foo"), Grouping.new("bar")]
          assert_equal 2, array.uniq.size
        end
      end
    end
  end
end
