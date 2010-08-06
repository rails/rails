require 'spec_helper'

module Arel
  describe Array do
    before do
      @relation = Array.new([
        [1, 'duck' ],
        [2, 'duck' ],
        [3, 'goose']
      ], [[:id, Attributes::Integer], [:name, Attributes::String]])
    end

    describe '#attributes' do
      it 'manufactures attributes corresponding to the names given on construction' do
        @relation.attributes.should == [
          Attribute.new(@relation, :id),
          Attribute.new(@relation, :name)
        ]
      end
    end

    describe '#call' do
      it "manufactures an array of hashes of attributes to values" do
        rows = @relation.call
        rows.length.should == 3
        @relation.array.zip(rows).each do |tuple, row|
          row.relation.should == @relation
          row.tuple.should == tuple
        end
      end
    end
  end
end
