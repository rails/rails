require 'spec_helper'

module Arel
  describe Join do
    before do
      @relation1 = Array.new([
        [1, 'duck' ],
        [2, 'duck' ],
        [3, 'goose']
      ], [[:id, Attributes::Integer], [:name, Attributes::String]])
      @relation2 = @relation1.alias
    end

    describe InnerJoin do
      describe '#call' do
        it 'combines the two tables where the predicate obtains' do
          @relation1                                    \
            .join(@relation2)                           \
              .on(@relation1[:id].eq(@relation2[:id]))  \
          .tap do |relation|
            rows = relation.call
            rows.length.should == 3
            @relation1.array.zip(rows).each do |tuple, row|
              row.relation.should == relation
              row.tuple.should == (tuple * 2)
            end
          end
        end
      end
    end
  end
end
