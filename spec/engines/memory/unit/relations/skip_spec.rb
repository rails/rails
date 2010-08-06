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
        .tap do |relation|
          rows = relation.call
          rows.length.should == 2
          one, two = *rows

          one.relation.should == relation
          one.tuple.should == [2, 'duck']

          two.relation.should == relation
          two.tuple.should == [3, 'goose']
        end
      end
    end
  end
end
