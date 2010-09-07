require 'spec_helper'

module Arel
  module Attributes
    describe 'attribute' do
      describe '#count' do
        it 'should return a count node' do
          relation = Table.new(:users)
          relation[:id].count.should be_kind_of Nodes::Count
        end

        it 'should take a distinct param' do
          relation = Table.new(:users)
          count = relation[:id].count(nil)
          count.should be_kind_of Nodes::Count
          count.distinct.should be_nil
        end
      end

      describe '#eq' do
        it 'should return an equality node' do
          attribute = Attribute.new nil, nil, nil
          equality = attribute.eq 1
          check equality.left.should == attribute
          check equality.right.should == 1
          equality.should be_kind_of Nodes::Equality
        end
      end

      describe '#in' do
        it 'can be constructed with a list' do
        end

        it 'should return an in node' do
          attribute = Attribute.new nil, nil, nil
          node = Nodes::In.new attribute, [1,2,3]
          check node.left.should  == attribute
          check node.right.should == [1, 2, 3]
        end
      end
    end

    describe 'equality' do
      describe '#to_sql' do
        it 'should produce sql' do
          table = Table.new :users
          condition = table['id'].eq 1
          condition.to_sql.should == '"users"."id" = 1'
        end
      end
    end
  end
end
