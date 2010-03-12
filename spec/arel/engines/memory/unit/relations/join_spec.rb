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
          .let do |relation|
            relation.call.should == [
              Row.new(relation, [1, 'duck',  1, 'duck' ]),
              Row.new(relation, [2, 'duck',  2, 'duck' ]),
              Row.new(relation, [3, 'goose', 3, 'goose'])
            ]
          end
        end
      end
    end
  end
end
