require 'spec_helper'

describe "Arel" do
  before :all do
    @engine = Arel::Testing::Engine.new
    @relation = Arel::Model.build do |r|
      r.engine @engine

      r.attribute :id,   Arel::Attributes::Integer
      r.attribute :name, Arel::Attributes::String
      r.attribute :age,  Arel::Attributes::Integer
    end
  end

  describe "Relation" do
    before :all do
      @expected = (1..20).map { |i| @relation.insert([i, "Name #{i % 6}", 2 * i]) }
    end

    it_should_behave_like 'A Relation'
  end

  describe "Relation" do
    describe "#insert" do
      it "inserts the row into the engine" do
        @relation.insert([1, 'Foo', 10])
        @engine.rows.should == [[1, 'Foo', 10]]
      end
    end
  end
end
