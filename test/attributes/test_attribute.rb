require 'helper'

module Arel
  module Attributes
    describe 'attribute' do
      describe '#not_eq' do
        it 'should create a NotEqual node' do
          relation = Table.new(:users)
          relation[:id].not_eq(10).must_be_kind_of Nodes::NotEqual
        end

        it 'should generate != in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_eq(10)
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" != 10
          }
        end

        it 'should handle nil' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_eq(nil)
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" IS NOT NULL
          }
        end
      end

      describe '#not_eq_any' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].not_eq_any([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ORs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_eq_any([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" != 1 OR "users"."id" != 2)
          }
        end
      end

      describe '#not_eq_all' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].not_eq_all([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ANDs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_eq_all([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" != 1 AND "users"."id" != 2)
          }
        end
      end

      describe '#gt' do
        it 'should create a GreaterThan node' do
          relation = Table.new(:users)
          relation[:id].gt(10).must_be_kind_of Nodes::GreaterThan
        end

        it 'should generate >= in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gt(10)
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" > 10
          }
        end
      end

      describe '#gt_any' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].gt_any([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ORs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gt_any([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" > 1 OR "users"."id" > 2)
          }
        end
      end

      describe '#gt_all' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].gt_all([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ANDs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gt_all([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" > 1 AND "users"."id" > 2)
          }
        end
      end

      describe '#gteq' do
        it 'should create a GreaterThanOrEqual node' do
          relation = Table.new(:users)
          relation[:id].gteq(10).must_be_kind_of Nodes::GreaterThanOrEqual
        end

        it 'should generate >= in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gteq(10)
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" >= 10
          }
        end
      end

      describe '#gteq_any' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].gteq_any([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ORs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gteq_any([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" >= 1 OR "users"."id" >= 2)
          }
        end
      end

      describe '#gteq_all' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].gteq_all([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ANDs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gteq_all([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" >= 1 AND "users"."id" >= 2)
          }
        end
      end

      describe '#lt' do
        it 'should create a LessThan node' do
          relation = Table.new(:users)
          relation[:id].lt(10).must_be_kind_of Nodes::LessThan
        end

        it 'should generate < in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].lt(10)
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" < 10
          }
        end
      end

      describe '#lt_any' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].lt_any([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ORs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].lt_any([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" < 1 OR "users"."id" < 2)
          }
        end
      end

      describe '#lt_all' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].lt_all([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ANDs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].lt_all([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" < 1 AND "users"."id" < 2)
          }
        end
      end

      describe '#lteq' do
        it 'should create a LessThanOrEqual node' do
          relation = Table.new(:users)
          relation[:id].lteq(10).must_be_kind_of Nodes::LessThanOrEqual
        end

        it 'should generate <= in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].lteq(10)
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" <= 10
          }
        end
      end

      describe '#lteq_any' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].lteq_any([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ORs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].lteq_any([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" <= 1 OR "users"."id" <= 2)
          }
        end
      end

      describe '#lteq_all' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].lteq_all([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ANDs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].lteq_all([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" <= 1 AND "users"."id" <= 2)
          }
        end
      end

      describe '#average' do
        it 'should create a AVG node' do
          relation = Table.new(:users)
          relation[:id].average.must_be_kind_of Nodes::Avg
        end

        # FIXME: backwards compat. Is this really necessary?
        it 'should set the alias to "avg_id"' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id].average
          mgr.to_sql.must_be_like %{
            SELECT AVG("users"."id") AS avg_id
            FROM "users"
          }
        end
      end

      describe '#maximum' do
        it 'should create a MAX node' do
          relation = Table.new(:users)
          relation[:id].maximum.must_be_kind_of Nodes::Max
        end

        # FIXME: backwards compat. Is this really necessary?
        it 'should set the alias to "max_id"' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id].maximum
          mgr.to_sql.must_be_like %{
            SELECT MAX("users"."id") AS max_id
            FROM "users"
          }
        end
      end

      describe '#minimum' do
        it 'should create a Min node' do
          relation = Table.new(:users)
          relation[:id].minimum.must_be_kind_of Nodes::Min
        end
      end

      describe '#sum' do
        it 'should create a SUM node' do
          relation = Table.new(:users)
          relation[:id].sum.must_be_kind_of Nodes::Sum
        end

        # FIXME: backwards compat. Is this really necessary?
        it 'should set the alias to "sum_id"' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id].sum
          mgr.to_sql.must_be_like %{
            SELECT SUM("users"."id") AS sum_id
            FROM "users"
          }
        end
      end

      describe '#count' do
        it 'should return a count node' do
          relation = Table.new(:users)
          relation[:id].count.must_be_kind_of Nodes::Count
        end

        it 'should take a distinct param' do
          relation = Table.new(:users)
          count = relation[:id].count(nil)
          count.must_be_kind_of Nodes::Count
          count.distinct.must_be_nil
        end
      end

      describe '#eq' do
        it 'should return an equality node' do
          attribute = Attribute.new nil, nil
          equality = attribute.eq 1
          equality.left.must_equal attribute
          equality.right.must_equal 1
          equality.must_be_kind_of Nodes::Equality
        end

        it 'should generate = in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].eq(10)
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" = 10
          }
        end

        it 'should handle nil' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].eq(nil)
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" IS NULL
          }
        end
      end

      describe '#eq_any' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].eq_any([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ORs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].eq_any([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" = 1 OR "users"."id" = 2)
          }
        end

        it 'should not eat input' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          values = [1,2]
          mgr.where relation[:id].eq_any(values)
          values.must_equal [1,2]
        end
      end

      describe '#eq_all' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].eq_all([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ANDs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].eq_all([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" = 1 AND "users"."id" = 2)
          }
        end

        it 'should not eat input' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          values = [1,2]
          mgr.where relation[:id].eq_all(values)
          values.must_equal [1,2]
        end
      end

      describe '#matches' do
        it 'should create a Matches node' do
          relation = Table.new(:users)
          relation[:name].matches('%bacon%').must_be_kind_of Nodes::Matches
        end

        it 'should generate LIKE in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].matches('%bacon%')
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."name" LIKE '%bacon%'
          }
        end
      end

      describe '#matches_any' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:name].matches_any(['%chunky%','%bacon%']).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ORs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].matches_any(['%chunky%','%bacon%'])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."name" LIKE '%chunky%' OR "users"."name" LIKE '%bacon%')
          }
        end
      end

      describe '#matches_all' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:name].matches_all(['%chunky%','%bacon%']).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ANDs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].matches_all(['%chunky%','%bacon%'])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."name" LIKE '%chunky%' AND "users"."name" LIKE '%bacon%')
          }
        end
      end

      describe '#does_not_match' do
        it 'should create a DoesNotMatch node' do
          relation = Table.new(:users)
          relation[:name].does_not_match('%bacon%').must_be_kind_of Nodes::DoesNotMatch
        end

        it 'should generate NOT LIKE in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].does_not_match('%bacon%')
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."name" NOT LIKE '%bacon%'
          }
        end
      end

      describe '#does_not_match_any' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:name].does_not_match_any(['%chunky%','%bacon%']).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ORs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].does_not_match_any(['%chunky%','%bacon%'])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."name" NOT LIKE '%chunky%' OR "users"."name" NOT LIKE '%bacon%')
          }
        end
      end

      describe '#does_not_match_all' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:name].does_not_match_all(['%chunky%','%bacon%']).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ANDs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].does_not_match_all(['%chunky%','%bacon%'])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."name" NOT LIKE '%chunky%' AND "users"."name" NOT LIKE '%bacon%')
          }
        end
      end

      describe '#in' do
        it 'can be constructed with a list' do
        end

        it 'should return an in node' do
          attribute = Attribute.new nil, nil
          node = Nodes::In.new attribute, [1,2,3]
          node.left.must_equal attribute
          node.right.must_equal [1, 2, 3]
        end

        it 'should generate IN in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].in([1,2,3])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" IN (1, 2, 3)
          }
        end
      end

      describe '#in_any' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].in_any([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ORs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].in_any([[1,2], [3,4]])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" IN (1, 2) OR "users"."id" IN (3, 4))
          }
        end
      end

      describe '#in_all' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].in_all([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ANDs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].in_all([[1,2], [3,4]])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" IN (1, 2) AND "users"."id" IN (3, 4))
          }
        end
      end

      describe '#not_in' do
        it 'can be constructed with a list' do
        end

        it 'should return a NotIn node' do
          attribute = Attribute.new nil, nil
          node = Nodes::NotIn.new attribute, [1,2,3]
          node.left.must_equal attribute
          node.right.must_equal [1, 2, 3]
        end

        it 'should generate NOT IN in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_in([1,2,3])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" NOT IN (1, 2, 3)
          }
        end
      end

      describe '#not_in_any' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].not_in_any([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ORs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_in_any([[1,2], [3,4]])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" NOT IN (1, 2) OR "users"."id" NOT IN (3, 4))
          }
        end
      end

      describe '#not_in_all' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].not_in_all([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ANDs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_in_all([[1,2], [3,4]])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" NOT IN (1, 2) AND "users"."id" NOT IN (3, 4))
          }
        end
      end

      describe '#eq_all' do
        it 'should create a Grouping node' do
          relation = Table.new(:users)
          relation[:id].eq_all([1,2]).must_be_kind_of Nodes::Grouping
        end

        it 'should generate ANDs in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].eq_all([1,2])
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" = 1 AND "users"."id" = 2)
          }
        end
      end

      describe '#asc' do
        it 'should create an Ascending node' do
          relation = Table.new(:users)
          relation[:id].asc.must_be_kind_of Nodes::Ascending
        end

        it 'should generate ASC in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.order relation[:id].asc
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" ORDER BY "users"."id" ASC
          }
        end
      end

      describe '#desc' do
        it 'should create a Descending node' do
          relation = Table.new(:users)
          relation[:id].desc.must_be_kind_of Nodes::Descending
        end

        it 'should generate DESC in sql' do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.order relation[:id].desc
          mgr.to_sql.must_be_like %{
            SELECT "users"."id" FROM "users" ORDER BY "users"."id" DESC
          }
        end
      end
    end

    describe 'equality' do
      describe '#to_sql' do
        it 'should produce sql' do
          table = Table.new :users
          condition = table['id'].eq 1
          condition.to_sql.must_equal '"users"."id" = 1'
        end
      end
    end
  end
end
