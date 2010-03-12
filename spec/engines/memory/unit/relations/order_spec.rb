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
        .let do |relation|
          relation.call.should == [
            Row.new(relation, [3, 'goose']),
            Row.new(relation, [2, 'duck' ]),
            Row.new(relation, [1, 'duck' ])
          ]
        end
      end
    end
  end
end
