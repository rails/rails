require 'spec_helper'

module Arel
  module Predicates
    describe Binary do
      before do
        @relation = Arel::Table.new(:users)
        @attribute1 = @relation[:id]
        @attribute2 = @relation[:name]
        class ConcreteBinary < Binary
        end
      end

      describe '#bind' do
        before do
          @another_relation = @relation.alias
        end

        describe 'when both operands are attributes' do
          it "manufactures an expression with the attributes bound to the relation" do
            ConcreteBinary.new(@attribute1, @attribute2).bind(@another_relation). \
              should == ConcreteBinary.new(@another_relation[@attribute1], @another_relation[@attribute2])
          end
        end

        describe 'when an operand is a value' do
          it "manufactures an expression with unmodified values" do
            ConcreteBinary.new(@attribute1, "asdf").bind(@another_relation). \
              should == ConcreteBinary.new(@attribute1.find_correlate_in(@another_relation), "asdf".find_correlate_in(@another_relation))
          end
        end
      end
    end
  end
end
