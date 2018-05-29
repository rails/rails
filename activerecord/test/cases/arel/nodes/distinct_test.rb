# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    describe "Distinct" do
      describe "equality" do
        it "is equal to other distinct nodes" do
          array = [Distinct.new, Distinct.new]
          assert_equal 1, array.uniq.size
        end

        it "is not equal with other nodes" do
          array = [Distinct.new, Node.new]
          assert_equal 2, array.uniq.size
        end
      end
    end
  end
end
