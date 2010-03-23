require 'spec_helper'

module Arel
  describe Where do
    before do
      @relation = Table.new(:users)
      @predicate = @relation[:id].eq(1)
    end

    describe '#initialize' do
      it "manufactures nested where relations if multiple predicates are provided" do
        pending "This is not true anymore"
        another_predicate = @relation[:name].lt(2)
        Where.new(@relation, @predicate, another_predicate). \
          should == Where.new(Where.new(@relation, another_predicate), @predicate)
      end
    end
  end
end
