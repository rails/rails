require 'spec_helper'

module Arel
  describe Skip do
    before do
      @relation = Array.new([
        [1, 'duck' ],
        [2, 'duck' ],
        [3, 'goose']
      ], [[:id, Attributes::Integer], [:name, Attributes::String]])
    end

    describe '#call' do
      it 'removes the first n rows' do
        @relation   \
          .skip(1)  \
        .let do |relation|
          relation.call.should == [
            Row.new(relation, [2, 'duck']),
            Row.new(relation, [3, 'goose']),
          ]
        end
      end
    end
  end
end
