require 'spec_helper'

module Arel
  module Attributes
    describe 'attribute' do
      describe '#not_eq' do
        it 'should create a NotEqual node' do
          relation = Table.new(:users)
          relation[:id].not_eq(10).should be_kind_of Nodes::NotEqual
        end

        it 'should generate != in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_eq(10)
          mgr.to_sql.should be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" != 10
          }
        end

        it 'should handle nil' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_eq(nil)
          mgr.to_sql.should be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" IS NOT NULL
          }
        end
      end

      describe '#gt' do
        it 'should create a GreaterThan node' do
          relation = Table.new(:users)
          relation[:id].gt(10).should be_kind_of Nodes::GreaterThan
        end

        it 'should generate >= in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gt(10)
          mgr.to_sql.should be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" > 10
          }
        end
      end

      describe '#gteq' do
        it 'should create a GreaterThanOrEqual node' do
          relation = Table.new(:users)
          relation[:id].gteq(10).should be_kind_of Nodes::GreaterThanOrEqual
        end

        it 'should generate >= in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gteq(10)
          mgr.to_sql.should be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" >= 10
          }
        end
      end

      describe '#average' do
        it 'should create a AVG node' do
          relation = Table.new(:users)
          relation[:id].average.should be_kind_of Nodes::Avg
        end

        # FIXME: backwards compat. Is this really necessary?
        it 'should set the alias to "avg_id"' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id].average
          mgr.to_sql.should be_like %{
            SELECT AVG("users"."id") AS avg_id
            FROM "users"
          }
        end
      end

      describe '#maximum' do
        it 'should create a MAX node' do
          relation = Table.new(:users)
          relation[:id].maximum.should be_kind_of Nodes::Max
        end

        # FIXME: backwards compat. Is this really necessary?
        it 'should set the alias to "max_id"' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id].maximum
          mgr.to_sql.should be_like %{
            SELECT MAX("users"."id") AS max_id
            FROM "users"
          }
        end
      end

      describe '#minimum' do
        it 'should create a Min node' do
          relation = Table.new(:users)
          relation[:id].minimum.should be_kind_of Nodes::Min
        end
      end

      describe '#sum' do
        it 'should create a SUM node' do
          relation = Table.new(:users)
          relation[:id].sum.should be_kind_of Nodes::Sum
        end

        # FIXME: backwards compat. Is this really necessary?
        it 'should set the alias to "sum_id"' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id].sum
          mgr.to_sql.should be_like %{
            SELECT SUM("users"."id") AS sum_id
            FROM "users"
          }
        end
      end

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
