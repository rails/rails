require 'spec_helper'

module Arel
  describe Order do
    before do
      @relation = Array.new([
        [1, 'duck' ],
        [2, 'duck' ],
        [3, 'goose']
      ], [[:id, Attributes::Integer], [:name, Attributes::String]])
    end

    describe '#call' do
      it 'sorts the relation with the provided ordering' do
        @relation                     \
          .order(@relation[:id].desc) \
        .tap do |relation|
          rows = relation.call
          rows.length.should == 3
          @relation.array.reverse.zip(rows) do |tuple, row|
            row.relation.should == relation
            row.tuple.should == tuple
          end
        end
      end
    end
  end
end
