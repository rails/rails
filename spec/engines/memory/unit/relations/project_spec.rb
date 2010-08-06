require 'spec_helper'

module Arel
  describe Project do
    before do
      @relation = Array.new([
        [1, 'duck' ],
        [2, 'duck' ],
        [3, 'goose']
      ], [[:id, Attributes::Integer], [:name, Attributes::String]])
    end

    describe '#call' do
      it 'retains only the attributes that are provided' do
        @relation                   \
          .project(@relation[:id])  \
        .tap do |relation|
          rows = relation.call
          @relation.array.zip(rows) do |tuple, row|
            row.relation.should == relation
            row.tuple.should == [tuple.first]
          end
        end
      end
    end
  end
end
