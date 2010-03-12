require 'spec_helper'

module Arel
  describe Expression do
    before do
      @relation = Table.new(:users)
      @attribute = @relation[:id]
    end

    describe "#inspect" do
      it "returns a simple, short inspect string" do
        @attribute.count.inspect.should == "<Arel::Count <Attribute id>>"
      end
    end

    describe Expression::Transformations do
      before do
        @expression = Count.new(@attribute)
      end

      describe '#bind' do
        it "manufactures an attribute with a rebound relation and self as the ancestor" do
          derived_relation = @relation.where(@relation[:id].eq(1))
          @expression.bind(derived_relation).should == Count.new(@attribute.bind(derived_relation), nil, @expression)
        end

        it "returns self if the substituting to the same relation" do
          @expression.bind(@relation).should == @expression
        end
      end

      describe '#as' do
        it "manufactures an aliased expression" do
          @expression.as(:alias).should == Expression.new(@attribute, :alias, @expression)
        end
      end

      describe '#to_attribute' do
        it "manufactures an attribute with the expression as an ancestor" do
          @expression.to_attribute(@relation).should == Attribute.new(@relation, @expression.alias, :ancestor => @expression)
        end
      end
    end
  end
end
