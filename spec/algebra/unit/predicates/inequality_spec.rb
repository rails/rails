require 'spec_helper'

module Arel
  module Predicates
    describe Inequality do
      before do
        relation1 = Arel::Table.new(:users)
        relation2 = Arel::Table.new(:photos)
        left      = relation1[:id]
        right     = relation2[:user_id]
        @a        = Inequality.new(left, right)
        @b        = Inequality.new(right, left)
      end

      describe 'operator' do
        it "should have one" do
          @a.operator.should == :"!="
        end
      end

      describe '==' do
        it "is equal to itself" do
          @a.should == @a
        end

        it "should not care abount children order" do
          @a.should == @b
        end
      end
    end
  end
end
