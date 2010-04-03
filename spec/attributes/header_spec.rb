require 'spec_helper'

module Arel
  describe "Header" do
    before :all do
      @relation = Model.build do |r|
        r.attribute :id,   Attributes::Integer
        r.attribute :name, Attributes::String
        r.attribute :age,  Attributes::Integer
      end

      @other = Model.build do |r|
        r.attribute :foo, Attributes::String
      end

      @subset = Model.build do |r|
        r.attribute :id, Attributes::Integer
      end
    end

    it "finds attributes by name" do
      @relation.attributes[:name].should == Attributes::String.new(@relation, :name)
    end

    describe "#union" do
      it "keeps all attributes from disjoint headers" do
        (@relation.attributes.union @other.attributes).to_ary.should have(4).items
      end

      it "keeps all attributes from both relations even if they seem like subsets" do
        (@relation.attributes.union @subset.attributes).to_ary.should have(4).items
      end
    end
  end
end