require 'spec_helper'

module Arel
  describe Take do
    before do
      @relation = Array.new([
        [1, 'duck' ],
        [2, 'duck' ],
        [3, 'goose']
      ], [[:id, Attributes::Integer], [:name, Attributes::String]])
    end

    describe '#call' do
      it 'removes the rows after the first n' do
        @relation   \
          .take(2)  \
        .let do |relation|
          relation.call.should == [
            Row.new(relation, [1, 'duck']),
            Row.new(relation, [2, 'duck']),
          ]
        end
      end
    end
  end
end
