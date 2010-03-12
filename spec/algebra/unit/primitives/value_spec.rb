require 'spec_helper'

module Arel
  describe Value do
    before do
      @relation = Table.new(:users)
    end

    describe '#bind' do
      it "manufactures a new value whose relation is the provided relation" do
        Value.new(1, @relation).bind(another_relation = Table.new(:photos)).should == Value.new(1, another_relation)
      end
    end
  end
end
