require 'spec_helper'

module Arel
  describe Table do
    before do
      @relation = Table.new(:users)
    end

    describe '[]' do
      describe 'when given a', Symbol do
        it "manufactures an attribute if the symbol names an attribute within the relation" do
          check @relation[:id].should == Attributes::Integer.new(@relation, :id)
        end
      end

      describe 'when given an', Attribute do
        it "returns the attribute if the attribute is within the relation" do
          @relation[@relation[:id]].should == @relation[:id]
        end

        it "returns nil if the attribtue is not within the relation" do
          another_relation = Table.new(:photos)
          @relation[another_relation[:id]].should be_nil
        end
      end

      describe 'when given an', Expression do
        before do
          @expression = @relation[:id].count
        end

        it "returns the Expression if the Expression is within the relation" do
          @relation[@expression].should be_nil
        end
      end
    end
  end
end
