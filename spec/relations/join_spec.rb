require 'spec_helper'

describe "Arel" do
  before :all do
    @owner = Arel::Model.build do |r|
      r.engine Arel::Testing::Engine.new

      r.attribute :id, Arel::Attributes::Integer
    end

    @thing = Arel::Model.build do |r|
      r.engine Arel::Testing::Engine.new

      r.attribute :id,       Arel::Attributes::Integer
      r.attribute :owner_id, Arel::Attributes::Integer
      r.attribute :name,     Arel::Attributes::String
      r.attribute :age,      Arel::Attributes::Integer
    end
  end

  describe "Join" do
    before :all do
      @relation = @thing.join(@owner).on(@thing[:owner_id].eq(@owner[:id]))
      @expected = []

      3.times do |owner_id|
        @owner.insert([owner_id])

        8.times do |i|
          thing_id = owner_id * 8 + i
          age      = 2 * thing_id
          name     = "Name #{thing_id % 6}"

          @thing.insert([thing_id, owner_id, name, age])
          @expected << Arel::Row.new(@relation, [thing_id, owner_id, name, age, owner_id])
        end
      end
    end

    it_should_behave_like 'A Relation'
  end
end
