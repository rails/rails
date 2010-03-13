require 'spec_helper'

module Arel
  describe "Relation" do
    before :all do
      @engine = Testing::Engine.new
      @relation = Model.build do |r|
        r.engine @engine

        r.attribute :id,   Attributes::Integer
        r.attribute :name, Attributes::String
        r.attribute :age,  Attributes::Integer
      end
    end

    describe "..." do
      before :all do
        @expected = (1..20).map { |i| @relation.insert([i, nil, 2 * i]) }
      end

      it_should_behave_like 'A Relation'
    end

    describe "#insert" do
      it "inserts the row into the engine" do
        @relation.insert([1, 'Foo', 10])
        @engine.rows.should == [[1, 'Foo', 10]]
      end
    end
  end
end