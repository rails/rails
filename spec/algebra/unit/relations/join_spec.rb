require 'spec_helper'

module Arel
  describe Join do
    before do
      @relation1 = Table.new(:users)
      @relation2 = Table.new(:photos)
      @predicate = @relation1[:id].eq(@relation2[:user_id])
    end

    describe '#attributes' do
      it 'combines the attributes of the two relations' do
        join = InnerJoin.new(@relation1, @relation2, @predicate)
        join.attributes.should == (@relation1.attributes | @relation2.attributes).bind(join)
      end
    end
  end
end
