require 'spec_helper'

module Arel
  module Predicates
    describe Polyadic do
      before do
        @relation1 = Arel::Table.new(:users)
        @relation2 = Arel::Table.new(:photos)
        @a = @relation1[:id]
        @b = @relation2[:user_id]
      end

      describe '==' do
        left = Polyadic.new @a, @b
        right = Polyadic.new @b, @a

        left.should != right
        left.should == right
      end
    end
  end
end
