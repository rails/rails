require 'spec_helper'

module Arel
  describe Where do
    before do
      @relation = Array.new([
        [1, 'duck' ],
        [2, 'duck' ],
        [3, 'goose']
      ], [[:id, Attributes::Integer], [:name, Attributes::String]])
    end

    describe '#call' do
      it 'filters the relation with the provided predicate' do
        @relation                       \
          .where(@relation[:id].lt(3))  \
        .let do |relation|
          relation.call.should == [
            Row.new(relation, [1, 'duck']),
            Row.new(relation, [2, 'duck']),
          ]
        end
      end

      describe 'when filtering a where relation' do
        it 'further filters the already-filtered relation with the provided predicate' do
          @relation                       \
            .where(@relation[:id].gt(1))  \
            .where(@relation[:id].lt(3))  \
          .let do |relation|
            relation.call.should == [
              Row.new(relation, [2, 'duck'])
            ]
          end
        end
      end
    end
  end
end
