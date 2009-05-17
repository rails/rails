require File.join(File.dirname(__FILE__), '..', '..', '..', 'spec_helper')

module Arel
  describe Array do
    before do
      @relation = Array.new([[1], [2], [3]], [:id])
    end

    describe '#attributes' do
      it 'manufactures attributes corresponding to the names given on construction' do
        @relation.attributes.should == [
          Attribute.new(@relation, :id)
        ]
      end
    end

    describe '#call' do
      it "manufactures an array of hashes of attributes to values" do
        @relation.call.should == [
          { @relation[:id] => 1 },
          { @relation[:id] => 2 },
          { @relation[:id] => 3 }
        ]
      end

      it '' do
        @relation.where(@relation[:id].lt(3)).call.should == [
          { @relation[:id] => 1 },
          { @relation[:id] => 2 }
        ]
      end
    end
  end
end