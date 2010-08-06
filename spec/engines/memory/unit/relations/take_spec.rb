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
        .tap do |relation|
          rows = relation.call
          rows.length.should == 2
          rows.each_with_index do |row, i|
            row.relation.should == relation
            row.tuple.should == [i + 1, 'duck']
          end
        end
      end
    end
  end
end
