# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Nodes
    class WindowTest < Arel::Spec
      describe "equality" do
        it "is equal with equal ivars" do
          window1 = Window.new
          window1.orders = [1, 2]
          window1.partitions = [1]
          window1.frame 3
          window2 = Window.new
          window2.orders = [1, 2]
          window2.partitions = [1]
          window2.frame 3
          array = [window1, window2]
          assert_equal 1, array.uniq.size
        end

        it "is not equal with different ivars" do
          window1 = Window.new
          window1.orders = [1, 2]
          window1.partitions = [1]
          window1.frame 3
          window2 = Window.new
          window2.orders = [1, 2]
          window1.partitions = [1]
          window2.frame 4
          array = [window1, window2]
          assert_equal 2, array.uniq.size
        end
      end
    end

    describe "NamedWindow" do
      describe "equality" do
        it "is equal with equal ivars" do
          window1 = NamedWindow.new "foo"
          window1.orders = [1, 2]
          window1.partitions = [1]
          window1.frame 3
          window2 = NamedWindow.new "foo"
          window2.orders = [1, 2]
          window2.partitions = [1]
          window2.frame 3
          array = [window1, window2]
          assert_equal 1, array.uniq.size
        end

        it "is not equal with different ivars" do
          window1 = NamedWindow.new "foo"
          window1.orders = [1, 2]
          window1.partitions = [1]
          window1.frame 3
          window2 = NamedWindow.new "bar"
          window2.orders = [1, 2]
          window2.partitions = [1]
          window2.frame 3
          array = [window1, window2]
          assert_equal 2, array.uniq.size
        end
      end
    end

    describe "CurrentRow" do
      describe "equality" do
        it "is equal to other current row nodes" do
          array = [CurrentRow.new, CurrentRow.new]
          assert_equal 1, array.uniq.size
        end

        it "is not equal with other nodes" do
          array = [CurrentRow.new, Node.new]
          assert_equal 2, array.uniq.size
        end
      end
    end
  end
end
