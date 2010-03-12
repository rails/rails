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
        @relation.call.should == [
          Row.new(@relation, [1, 'duck']),
          Row.new(@relation, [2, 'duck']),
          Row.new(@relation, [3, 'goose'])
        ]
      end
    end
  end
end
