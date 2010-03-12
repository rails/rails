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
        .let do |relation|
          relation.call.should == [
            Row.new(relation, [1]),
            Row.new(relation, [2]),
            Row.new(relation, [3])
          ]
        end
      end
    end
  end
end
