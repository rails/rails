# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Attributes
    class AttributeTest < Arel::Spec
      describe "#not_eq" do
        it "should create a NotEqual node" do
          relation = Table.new(:users)
          _(relation[:id].not_eq(10)).must_be_kind_of Nodes::NotEqual
        end

        it "should generate != in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_eq(10)
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" != 10
          }
        end

        it "should handle nil" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_eq(nil)
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" IS NOT NULL
          }
        end
      end

      describe "#not_eq_any" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].not_eq_any([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ORs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_eq_any([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" != 1 OR "users"."id" != 2)
          }
        end
      end

      describe "#not_eq_all" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].not_eq_all([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ANDs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_eq_all([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" != 1 AND "users"."id" != 2)
          }
        end
      end

      describe "#gt" do
        it "should create a GreaterThan node" do
          relation = Table.new(:users)
          _(relation[:id].gt(10)).must_be_kind_of Nodes::GreaterThan
        end

        it "should generate > in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gt(10)
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" > 10
          }
        end

        it "should handle comparing with a subquery" do
          users = Table.new(:users)

          avg = users.project(users[:karma].average)
          mgr = users.project(Arel.star).where(users[:karma].gt(avg))

          _(mgr.to_sql).must_be_like %{
            SELECT * FROM "users" WHERE "users"."karma" > (SELECT AVG("users"."karma") FROM "users")
          }
        end

        it "should accept various data types." do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].gt("fake_name")
          _(mgr.to_sql).must_match %{"users"."name" > 'fake_name'}

          current_time = ::Time.now
          mgr.where relation[:created_at].gt(current_time)
          _(mgr.to_sql).must_match %{"users"."created_at" > '#{current_time}'}
        end
      end

      describe "#gt_any" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].gt_any([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ORs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gt_any([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" > 1 OR "users"."id" > 2)
          }
        end
      end

      describe "#gt_all" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].gt_all([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ANDs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gt_all([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" > 1 AND "users"."id" > 2)
          }
        end
      end

      describe "#gteq" do
        it "should create a GreaterThanOrEqual node" do
          relation = Table.new(:users)
          _(relation[:id].gteq(10)).must_be_kind_of Nodes::GreaterThanOrEqual
        end

        it "should generate >= in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gteq(10)
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" >= 10
          }
        end

        it "should accept various data types." do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].gteq("fake_name")
          _(mgr.to_sql).must_match %{"users"."name" >= 'fake_name'}

          current_time = ::Time.now
          mgr.where relation[:created_at].gteq(current_time)
          _(mgr.to_sql).must_match %{"users"."created_at" >= '#{current_time}'}
        end
      end

      describe "#gteq_any" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].gteq_any([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ORs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gteq_any([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" >= 1 OR "users"."id" >= 2)
          }
        end
      end

      describe "#gteq_all" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].gteq_all([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ANDs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].gteq_all([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" >= 1 AND "users"."id" >= 2)
          }
        end
      end

      describe "#lt" do
        it "should create a LessThan node" do
          relation = Table.new(:users)
          _(relation[:id].lt(10)).must_be_kind_of Nodes::LessThan
        end

        it "should generate < in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].lt(10)
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" < 10
          }
        end

        it "should accept various data types." do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].lt("fake_name")
          _(mgr.to_sql).must_match %{"users"."name" < 'fake_name'}

          current_time = ::Time.now
          mgr.where relation[:created_at].lt(current_time)
          _(mgr.to_sql).must_match %{"users"."created_at" < '#{current_time}'}
        end
      end

      describe "#lt_any" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].lt_any([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ORs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].lt_any([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" < 1 OR "users"."id" < 2)
          }
        end
      end

      describe "#lt_all" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].lt_all([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ANDs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].lt_all([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" < 1 AND "users"."id" < 2)
          }
        end
      end

      describe "#lteq" do
        it "should create a LessThanOrEqual node" do
          relation = Table.new(:users)
          _(relation[:id].lteq(10)).must_be_kind_of Nodes::LessThanOrEqual
        end

        it "should generate <= in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].lteq(10)
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" <= 10
          }
        end

        it "should accept various data types." do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].lteq("fake_name")
          _(mgr.to_sql).must_match %{"users"."name" <= 'fake_name'}

          current_time = ::Time.now
          mgr.where relation[:created_at].lteq(current_time)
          _(mgr.to_sql).must_match %{"users"."created_at" <= '#{current_time}'}
        end
      end

      describe "#lteq_any" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].lteq_any([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ORs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].lteq_any([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" <= 1 OR "users"."id" <= 2)
          }
        end
      end

      describe "#lteq_all" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].lteq_all([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ANDs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].lteq_all([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" <= 1 AND "users"."id" <= 2)
          }
        end
      end

      describe "#average" do
        it "should create a AVG node" do
          relation = Table.new(:users)
          _(relation[:id].average).must_be_kind_of Nodes::Avg
        end

        it "should generate the proper SQL" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id].average
          _(mgr.to_sql).must_be_like %{
            SELECT AVG("users"."id")
            FROM "users"
          }
        end
      end

      describe "#maximum" do
        it "should create a MAX node" do
          relation = Table.new(:users)
          _(relation[:id].maximum).must_be_kind_of Nodes::Max
        end

        it "should generate proper SQL" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id].maximum
          _(mgr.to_sql).must_be_like %{
            SELECT MAX("users"."id")
            FROM "users"
          }
        end
      end

      describe "#minimum" do
        it "should create a Min node" do
          relation = Table.new(:users)
          _(relation[:id].minimum).must_be_kind_of Nodes::Min
        end

        it "should generate proper SQL" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id].minimum
          _(mgr.to_sql).must_be_like %{
            SELECT MIN("users"."id")
            FROM "users"
          }
        end
      end

      describe "#sum" do
        it "should create a SUM node" do
          relation = Table.new(:users)
          _(relation[:id].sum).must_be_kind_of Nodes::Sum
        end

        it "should generate the proper SQL" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id].sum
          _(mgr.to_sql).must_be_like %{
            SELECT SUM("users"."id")
            FROM "users"
          }
        end
      end

      describe "#count" do
        it "should return a count node" do
          relation = Table.new(:users)
          _(relation[:id].count).must_be_kind_of Nodes::Count
        end

        it "should take a distinct param" do
          relation = Table.new(:users)
          count = relation[:id].count(nil)
          _(count).must_be_kind_of Nodes::Count
          _(count.distinct).must_be_nil
        end
      end

      describe "#eq" do
        it "should return an equality node" do
          attribute = Attribute.new nil, nil
          equality = attribute.eq 1
          _(equality.left).must_equal attribute
          _(equality.right.value).must_equal 1
          _(equality).must_be_kind_of Nodes::Equality
        end

        it "should generate = in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].eq(10)
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" = 10
          }
        end

        it "should handle nil" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].eq(nil)
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" IS NULL
          }
        end
      end

      describe "#eq_any" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].eq_any([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ORs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].eq_any([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" = 1 OR "users"."id" = 2)
          }
        end

        it "should not eat input" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          values = [1, 2]
          mgr.where relation[:id].eq_any(values)
          _(values).must_equal [1, 2]
        end
      end

      describe "#eq_all" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].eq_all([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ANDs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].eq_all([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" = 1 AND "users"."id" = 2)
          }
        end

        it "should not eat input" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          values = [1, 2]
          mgr.where relation[:id].eq_all(values)
          _(values).must_equal [1, 2]
        end
      end

      describe "#matches" do
        it "should create a Matches node" do
          relation = Table.new(:users)
          _(relation[:name].matches("%bacon%")).must_be_kind_of Nodes::Matches
        end

        it "should generate LIKE in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].matches("%bacon%")
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."name" LIKE '%bacon%'
          }
        end
      end

      describe "#matches_any" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:name].matches_any(["%chunky%", "%bacon%"])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ORs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].matches_any(["%chunky%", "%bacon%"])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."name" LIKE '%chunky%' OR "users"."name" LIKE '%bacon%')
          }
        end
      end

      describe "#matches_all" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:name].matches_all(["%chunky%", "%bacon%"])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ANDs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].matches_all(["%chunky%", "%bacon%"])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."name" LIKE '%chunky%' AND "users"."name" LIKE '%bacon%')
          }
        end
      end

      describe "#does_not_match" do
        it "should create a DoesNotMatch node" do
          relation = Table.new(:users)
          _(relation[:name].does_not_match("%bacon%")).must_be_kind_of Nodes::DoesNotMatch
        end

        it "should generate NOT LIKE in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].does_not_match("%bacon%")
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."name" NOT LIKE '%bacon%'
          }
        end
      end

      describe "#does_not_match_any" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:name].does_not_match_any(["%chunky%", "%bacon%"])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ORs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].does_not_match_any(["%chunky%", "%bacon%"])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."name" NOT LIKE '%chunky%' OR "users"."name" NOT LIKE '%bacon%')
          }
        end
      end

      describe "#does_not_match_all" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:name].does_not_match_all(["%chunky%", "%bacon%"])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ANDs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].does_not_match_all(["%chunky%", "%bacon%"])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."name" NOT LIKE '%chunky%' AND "users"."name" NOT LIKE '%bacon%')
          }
        end
      end

      describe "#between" do
        it "can be constructed with a standard range" do
          attribute = Attribute.new nil, nil
          node = attribute.between(1..3)

          _(node).must_equal Nodes::Between.new(
            attribute,
            Nodes::And.new([
              Nodes::Casted.new(1, attribute),
              Nodes::Casted.new(3, attribute)
            ])
          )
        end

        it "can be constructed with a range starting from -Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.between(-::Float::INFINITY..3)

          _(node).must_equal Nodes::LessThanOrEqual.new(
            attribute,
            Nodes::Casted.new(3, attribute)
          )
        end

        it "can be constructed with a quoted range starting from -Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.between(quoted_range(-::Float::INFINITY, 3, false))

          _(node).must_equal Nodes::LessThanOrEqual.new(
            attribute,
            Nodes::Quoted.new(3)
          )
        end

        it "can be constructed with an exclusive range starting from -Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.between(-::Float::INFINITY...3)

          _(node).must_equal Nodes::LessThan.new(
            attribute,
            Nodes::Casted.new(3, attribute)
          )
        end

        it "can be constructed with a quoted exclusive range starting from -Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.between(quoted_range(-::Float::INFINITY, 3, true))

          _(node).must_equal Nodes::LessThan.new(
            attribute,
            Nodes::Quoted.new(3)
          )
        end

        it "can be constructed with an infinite range" do
          attribute = Attribute.new nil, nil
          node = attribute.between(-::Float::INFINITY..::Float::INFINITY)

          _(node).must_equal Nodes::NotIn.new(attribute, [])
        end

        it "can be constructed with a quoted infinite range" do
          attribute = Attribute.new nil, nil
          node = attribute.between(quoted_range(-::Float::INFINITY, ::Float::INFINITY, false))

          _(node).must_equal Nodes::NotIn.new(attribute, [])
        end

        it "can be constructed with a range ending at Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.between(0..::Float::INFINITY)

          _(node).must_equal Nodes::GreaterThanOrEqual.new(
            attribute,
            Nodes::Casted.new(0, attribute)
          )
        end

        it "can be constructed with a range implicitly starting at Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.between(..0)

          _(node).must_equal Nodes::LessThanOrEqual.new(
            attribute,
            Nodes::Casted.new(0, attribute)
          )
        end

        it "can be constructed with a range implicitly ending at Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.between(0..)

          _(node).must_equal Nodes::GreaterThanOrEqual.new(
            attribute,
            Nodes::Casted.new(0, attribute)
          )
        end

        it "can be constructed with an exclusive range implicitly ending at Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.between(0...)

          _(node).must_equal Nodes::GreaterThanOrEqual.new(
            attribute,
            Nodes::Casted.new(0, attribute)
          )
        end

        it "can be constructed with a quoted range ending at Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.between(quoted_range(0, ::Float::INFINITY, false))

          _(node).must_equal Nodes::GreaterThanOrEqual.new(
            attribute,
            Nodes::Quoted.new(0)
          )
        end

        it "can be constructed with an endless range starting from Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.between(::Float::INFINITY..)

          _(node).must_equal Nodes::In.new(attribute, [])
        end

        it "can be constructed with a beginless range ending in -Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.between(..-::Float::INFINITY)

          _(node).must_equal Nodes::In.new(attribute, [])
        end

        it "can be constructed with an exclusive range" do
          attribute = Attribute.new nil, nil
          node = attribute.between(0...3)

          _(node).must_equal Nodes::And.new([
            Nodes::GreaterThanOrEqual.new(
              attribute,
              Nodes::Casted.new(0, attribute)
            ),
            Nodes::LessThan.new(
              attribute,
              Nodes::Casted.new(3, attribute)
            )
          ])
        end

        it "can be constructed with a range where the begin and end are equal" do
          attribute = Attribute.new nil, nil
          node = attribute.between(1..1)

          _(node).must_equal Nodes::Equality.new(
            attribute,
            Nodes::Casted.new(1, attribute)
          )
        end
      end

      describe "#in" do
        it "can be constructed with a subquery" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].does_not_match_all(["%chunky%", "%bacon%"])
          attribute = Attribute.new nil, nil

          node = attribute.in(mgr)

          _(node).must_equal Nodes::In.new(attribute, mgr.ast)
        end

        it "can be constructed with a list" do
          attribute = Attribute.new nil, nil
          node = attribute.in([1, 2, 3])

          _(node).must_equal Nodes::In.new(
            attribute,
            [
              Nodes::Casted.new(1, attribute),
              Nodes::Casted.new(2, attribute),
              Nodes::Casted.new(3, attribute),
            ]
          )
        end

        it "can be constructed with a random object" do
          attribute = Attribute.new nil, nil
          random_object = Object.new
          node = attribute.in(random_object)

          _(node).must_equal Nodes::In.new(
            attribute,
            Nodes::Casted.new(random_object, attribute)
          )
        end

        it "should generate IN in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].in([1, 2, 3])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" IN (1, 2, 3)
          }
        end
      end

      describe "#in_any" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].in_any([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ORs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].in_any([[1, 2], [3, 4]])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" IN (1, 2) OR "users"."id" IN (3, 4))
          }
        end
      end

      describe "#in_all" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].in_all([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ANDs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].in_all([[1, 2], [3, 4]])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" IN (1, 2) AND "users"."id" IN (3, 4))
          }
        end
      end

      describe "#not_between" do
        it "can be constructed with a standard range" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(1..3)

          _(node).must_equal Nodes::Grouping.new(
            Nodes::Or.new([
              Nodes::LessThan.new(
                attribute,
                Nodes::Casted.new(1, attribute)
              ),
              Nodes::GreaterThan.new(
                attribute,
                Nodes::Casted.new(3, attribute)
              )
            ])
          )
        end

        it "can be constructed with a range starting from -Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(-::Float::INFINITY..3)

          _(node).must_equal Nodes::GreaterThan.new(
            attribute,
            Nodes::Casted.new(3, attribute)
          )
        end

        it "can be constructed with a quoted range starting from -Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(quoted_range(-::Float::INFINITY, 3, false))

          _(node).must_equal Nodes::GreaterThan.new(
            attribute,
            Nodes::Quoted.new(3)
          )
        end

        it "can be constructed with an exclusive range starting from -Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(-::Float::INFINITY...3)

          _(node).must_equal Nodes::GreaterThanOrEqual.new(
            attribute,
            Nodes::Casted.new(3, attribute)
          )
        end

        it "can be constructed with a quoted exclusive range starting from -Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(quoted_range(-::Float::INFINITY, 3, true))

          _(node).must_equal Nodes::GreaterThanOrEqual.new(
            attribute,
            Nodes::Quoted.new(3)
          )
        end

        it "can be constructed with an infinite range" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(-::Float::INFINITY..::Float::INFINITY)

          _(node).must_equal Nodes::In.new(attribute, [])
        end

        it "can be constructed with a quoted infinite range" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(quoted_range(-::Float::INFINITY, ::Float::INFINITY, false))

          _(node).must_equal Nodes::In.new(attribute, [])
        end

        it "can be constructed with a range ending at Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(0..::Float::INFINITY)

          _(node).must_equal Nodes::LessThan.new(
            attribute,
            Nodes::Casted.new(0, attribute)
          )
        end

        it "can be constructed with a range implicitly starting at Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(..0)

          _(node).must_equal Nodes::GreaterThan.new(
            attribute,
            Nodes::Casted.new(0, attribute)
          )
        end

        it "can be constructed with a range implicitly ending at Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(0..)

          _(node).must_equal Nodes::LessThan.new(
            attribute,
            Nodes::Casted.new(0, attribute)
          )
        end

        it "can be constructed with a quoted range ending at Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(quoted_range(0, ::Float::INFINITY, false))

          _(node).must_equal Nodes::LessThan.new(
            attribute,
            Nodes::Quoted.new(0)
          )
        end

        it "can be constructed with an endless range starting from Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(::Float::INFINITY..)

          _(node).must_equal Nodes::NotIn.new(attribute, [])
        end

        it "can be constructed with a beginless range ending in -Infinity" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(..-::Float::INFINITY)

          _(node).must_equal Nodes::NotIn.new(attribute, [])
        end

        it "can be constructed with an exclusive range" do
          attribute = Attribute.new nil, nil
          node = attribute.not_between(0...3)

          _(node).must_equal Nodes::Grouping.new(
            Nodes::Or.new([
              Nodes::LessThan.new(
                attribute,
                Nodes::Casted.new(0, attribute)
              ),
              Nodes::GreaterThanOrEqual.new(
                attribute,
                Nodes::Casted.new(3, attribute)
              )
            ])
          )
        end
      end

      describe "#not_in" do
        it "can be constructed with a subquery" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:name].does_not_match_all(["%chunky%", "%bacon%"])
          attribute = Attribute.new nil, nil

          node = attribute.not_in(mgr)

          _(node).must_equal Nodes::NotIn.new(attribute, mgr.ast)
        end

        it "can be constructed with a Union" do
          relation = Table.new(:users)
          mgr1 = relation.project(relation[:id])
          mgr2 = relation.project(relation[:id])

          union = mgr1.union(mgr2)
          node = relation[:id].in(union)
          _(node.to_sql).must_be_like %{
            "users"."id" IN (( SELECT "users"."id" FROM "users" UNION SELECT "users"."id" FROM "users" ))
          }
        end

        it "can be constructed with a list" do
          attribute = Attribute.new nil, nil
          node = attribute.not_in([1, 2, 3])

          _(node).must_equal Nodes::NotIn.new(
            attribute,
            [
              Nodes::Casted.new(1, attribute),
              Nodes::Casted.new(2, attribute),
              Nodes::Casted.new(3, attribute),
            ]
          )
        end

        it "can be constructed with a random object" do
          attribute = Attribute.new nil, nil
          random_object = Object.new
          node = attribute.not_in(random_object)

          _(node).must_equal Nodes::NotIn.new(
            attribute,
            Nodes::Casted.new(random_object, attribute)
          )
        end

        it "should generate NOT IN in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_in([1, 2, 3])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE "users"."id" NOT IN (1, 2, 3)
          }
        end
      end

      describe "#not_in_any" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].not_in_any([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ORs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_in_any([[1, 2], [3, 4]])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" NOT IN (1, 2) OR "users"."id" NOT IN (3, 4))
          }
        end
      end

      describe "#not_in_all" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].not_in_all([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ANDs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].not_in_all([[1, 2], [3, 4]])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" NOT IN (1, 2) AND "users"."id" NOT IN (3, 4))
          }
        end
      end

      describe "#eq_all" do
        it "should create a Grouping node" do
          relation = Table.new(:users)
          _(relation[:id].eq_all([1, 2])).must_be_kind_of Nodes::Grouping
        end

        it "should generate ANDs in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.where relation[:id].eq_all([1, 2])
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" WHERE ("users"."id" = 1 AND "users"."id" = 2)
          }
        end
      end

      describe "#asc" do
        it "should create an Ascending node" do
          relation = Table.new(:users)
          _(relation[:id].asc).must_be_kind_of Nodes::Ascending
        end

        it "should generate ASC in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.order relation[:id].asc
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" ORDER BY "users"."id" ASC
          }
        end
      end

      describe "#desc" do
        it "should create a Descending node" do
          relation = Table.new(:users)
          _(relation[:id].desc).must_be_kind_of Nodes::Descending
        end

        it "should generate DESC in sql" do
          relation = Table.new(:users)
          mgr = relation.project relation[:id]
          mgr.order relation[:id].desc
          _(mgr.to_sql).must_be_like %{
            SELECT "users"."id" FROM "users" ORDER BY "users"."id" DESC
          }
        end
      end

      describe "#contains" do
        it "should create a Contains node" do
          relation = Table.new(:products)
          _(relation[:tags].contains(["foo", "bar"])).must_be_kind_of Nodes::Contains
        end

        it "should generate @> in sql" do
          relation = Table.new(:products, type_caster: fake_pg_caster)
          mgr = relation.project relation[:id]
          mgr.where relation[:tags].contains(["foo", "bar"])
          _(mgr.to_sql).must_be_like %{ SELECT "products"."id" FROM "products" WHERE "products"."tags" @> '{foo,bar}' }
        end
      end

      describe "#overlaps" do
        it "should create an Overlaps node" do
          relation = Table.new(:products)
          _(relation[:tags].overlaps(["foo", "bar"])).must_be_kind_of Nodes::Overlaps
        end

        it "should generate && in sql" do
          relation = Table.new(:products, type_caster: fake_pg_caster)
          mgr = relation.project relation[:id]
          mgr.where relation[:tags].overlaps(["foo", "bar"])
          _(mgr.to_sql).must_be_like %{ SELECT "products"."id" FROM "products" WHERE "products"."tags" && '{foo,bar}' }
        end
      end

      describe "equality" do
        describe "#to_sql" do
          it "should produce sql" do
            table = Table.new :users
            condition = table["id"].eq 1
            _(condition.to_sql).must_equal '"users"."id" = 1'
          end
        end
      end

      describe "type casting" do
        it "does not type cast by default" do
          table = Table.new(:foo)
          condition = table["id"].eq("1")

          assert_not table.able_to_type_cast?
          _(condition.to_sql).must_equal %("foo"."id" = '1')
        end

        it "type casts when given an explicit caster" do
          fake_caster = Object.new
          def fake_caster.type_cast_for_database(attr_name, value)
            if attr_name == "id"
              value.to_i
            else
              value
            end
          end
          table = Table.new(:foo, type_caster: fake_caster)
          condition = table["id"].eq("1").and(table["other_id"].eq("2"))

          assert_predicate table, :able_to_type_cast?
          _(condition.to_sql).must_equal %("foo"."id" = 1 AND "foo"."other_id" = '2')
        end

        it "does not type cast SqlLiteral nodes" do
          fake_caster = Object.new
          def fake_caster.type_cast_for_database(attr_name, value)
            value.to_i
          end
          table = Table.new(:foo, type_caster: fake_caster)
          condition = table["id"].eq(Arel.sql("(select 1)"))

          assert_predicate table, :able_to_type_cast?
          _(condition.to_sql).must_equal %("foo"."id" = (select 1))
        end
      end

      private
        def quoted_range(begin_val, end_val, exclude)
          Struct.new(:begin, :end, :exclude_end?).new(
            Nodes::Quoted.new(begin_val),
            Nodes::Quoted.new(end_val),
            exclude,
          )
        end

        # Mimic PG::TextDecoder::Array casting
        def fake_pg_caster
          Object.new.tap do |caster|
            def caster.type_cast_for_database(attr_name, value)
              if attr_name == "tags"
                "{#{value.join(",")}}"
              else
                value
              end
            end
          end
        end
    end
  end
end
