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
        .tap do |relation|
          rows = relation.call
          rows.length.should == 2
          rows.each_with_index do |row, i|
            row.relation.should == relation
            row.tuple.should == [i + 1, 'duck']
          end
        end
      end

      describe 'when filtering a where relation' do
        it 'further filters the already-filtered relation with the provided predicate' do
          @relation                       \
            .where(@relation[:id].gt(1))  \
            .where(@relation[:id].lt(3))  \
          .tap do |relation|
            rows = relation.call
            rows.length.should == 1
            row = rows.first
            row.relation.should == relation
            row.tuple.should == [2, 'duck']
          end
        end
      end
    end
  end
end
