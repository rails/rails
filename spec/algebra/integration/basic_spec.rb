require 'spec_helper'

def have_rows(expected)
  simple_matcher "have rows" do |given, matcher|
    found, got, expected = [], [], expected.map { |r| r.tuple }
    given.each do |row|
      got << row.tuple
      found << expected.find { |r| row.tuple == r }
    end

    matcher.failure_message = "Expected to get:\n" \
      "#{expected.map {|r| "  #{r.inspect}" }.join("\n")}\n" \
      "instead, got:\n" \
      "#{got.map {|r| "  #{r.inspect}" }.join("\n")}"
    
    found.compact.length == expected.length && got.compact.length == expected.length
  end
end

share_examples_for 'A Relation' do

  before :all do
    # The two needed instance variables need to be set in a
    # before :all callback.
    #   @relation is the relation being tested here.
    #   @expected is an array of the elements that are expected to be in
    #     the relation.
    %w[ @relation @expected ].each do |ivar|
      raise "#{ivar} needs to be defined" unless instance_variable_get(ivar)
    end

    # There needs to be enough items to be able to run all the tests
    raise "@expected needs to have at least 6 items" unless @expected.length >= 6
  end

  describe "#each" do
    it "iterates over the rows in any order" do
      @relation.should have_rows(@expected)
    end
  end

  describe "#where" do
    before :all do
      @expected = @expected.sort_by { |r| r[@relation[:age]] }
      @pivot = @expected[@expected.length / 2]
    end

    it "finds rows with an equal to predicate" do
      expected = @expected.select { |r| r[@relation[:age]] == @pivot[@relation[:age]] }
      @relation.where(@relation[:age].eq(@pivot[@relation[:age]])).should have_rows(expected)
    end
  end
end

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