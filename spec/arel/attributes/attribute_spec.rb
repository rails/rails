require 'spec_helper'

module Arel
  module Attributes
    describe 'attribute' do
      describe '#eq' do
        it 'should return an equality node' do
          attribute = Attribute.new nil, nil, nil
          equality = attribute.eq 1
          equality.left.should == attribute
          equality.right.should == 1
          equality.should be_kind_of Nodes::Equality
        end
      end
    end
  end
end
