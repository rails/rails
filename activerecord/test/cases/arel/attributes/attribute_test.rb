# frozen_string_literal: true

require_relative "../helper"

module Arel
  module Attributes
    class AttributeTest < Arel::Test
      test "#not_eq should create a NotEqual node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::NotEqual, relation[:id].not_eq(10)
      end

      test "#not_eq should generate != in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].not_eq(10)
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE "users"."id" != 10
        }, mgr.to_sql
      end

      test "#not_eq should handle nil" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].not_eq(nil)
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE "users"."id" IS NOT NULL
        }, mgr.to_sql
      end

      test "#not_eq_any should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].not_eq_any([1, 2])
      end

      test "#not_eq_any should generate ORs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].not_eq_any([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" != 1 OR "users"."id" != 2)
        }, mgr.to_sql
      end

      test "#not_eq_all should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].not_eq_all([1, 2])
      end

      test "#not_eq_all should generate ANDs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].not_eq_all([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" != 1 AND "users"."id" != 2)
        }, mgr.to_sql
      end

      test "#gt should create a GreaterThan node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::GreaterThan, relation[:id].gt(10)
      end

      test "#gt should generate > in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].gt(10)
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE "users"."id" > 10
        }, mgr.to_sql
      end

      test "#gt should handle comparing with a subquery" do
        users = Table.new(:users)

        avg = users.project(users[:karma].average)
        mgr = users.project(Arel.star).where(users[:karma].gt(avg))

        assert_like %{
          SELECT * FROM "users" WHERE "users"."karma" > (SELECT AVG("users"."karma") FROM "users")
        }, mgr.to_sql
      end

      test "#gt should accept various data types." do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:name].gt("fake_name")
        assert_match %{"users"."name" > 'fake_name'}, mgr.to_sql

        current_time = ::Time.now
        mgr.where relation[:created_at].gt(current_time)
        assert_match %{"users"."created_at" > '#{current_time}'}, mgr.to_sql
      end

      test "#gt_any should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].gt_any([1, 2])
      end

      test "#gt_any should generate ORs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].gt_any([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" > 1 OR "users"."id" > 2)
        }, mgr.to_sql
      end

      test "#gt_all should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].gt_all([1, 2])
      end

      test "#gt_all should generate ANDs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].gt_all([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" > 1 AND "users"."id" > 2)
        }, mgr.to_sql
      end

      test "#gteq should create a GreaterThanOrEqual node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::GreaterThanOrEqual, relation[:id].gteq(10)
      end

      test "#gteq should generate >= in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].gteq(10)
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE "users"."id" >= 10
        }, mgr.to_sql
      end

      test "#gteq should accept various data types." do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:name].gteq("fake_name")
        assert_match %{"users"."name" >= 'fake_name'}, mgr.to_sql

        current_time = ::Time.now
        mgr.where relation[:created_at].gteq(current_time)
        assert_match %{"users"."created_at" >= '#{current_time}'}, mgr.to_sql
      end

      test "#gteq_any should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].gteq_any([1, 2])
      end

      test "#gteq_any should generate ORs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].gteq_any([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" >= 1 OR "users"."id" >= 2)
        }, mgr.to_sql
      end

      test "#gteq_all should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].gteq_all([1, 2])
      end

      test "#gteq_all should generate ANDs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].gteq_all([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" >= 1 AND "users"."id" >= 2)
        }, mgr.to_sql
      end

      test "#lt should create a LessThan node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::LessThan, relation[:id].lt(10)
      end

      test "#lt should generate < in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].lt(10)
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE "users"."id" < 10
        }, mgr.to_sql
      end

      test "#lt should accept various data types." do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:name].lt("fake_name")
        assert_match %{"users"."name" < 'fake_name'}, mgr.to_sql

        current_time = ::Time.now
        mgr.where relation[:created_at].lt(current_time)
        assert_match %{"users"."created_at" < '#{current_time}'}, mgr.to_sql
      end

      test "#lt_any should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].lt_any([1, 2])
      end

      test "#lt_any should generate ORs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].lt_any([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" < 1 OR "users"."id" < 2)
        }, mgr.to_sql
      end

      test "#lt_all should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].lt_all([1, 2])
      end

      test "#lt_all should generate ANDs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].lt_all([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" < 1 AND "users"."id" < 2)
        }, mgr.to_sql
      end

      test "#lteq should create a LessThanOrEqual node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::LessThanOrEqual, relation[:id].lteq(10)
      end

      test "#lteq should generate <= in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].lteq(10)
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE "users"."id" <= 10
        }, mgr.to_sql
      end

      test "#lteq should accept various data types." do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:name].lteq("fake_name")
        assert_match %{"users"."name" <= 'fake_name'}, mgr.to_sql

        current_time = ::Time.now
        mgr.where relation[:created_at].lteq(current_time)
        assert_match %{"users"."created_at" <= '#{current_time}'}, mgr.to_sql
      end

      test "#lteq_any should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].lteq_any([1, 2])
      end

      test "#lteq_any should generate ORs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].lteq_any([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" <= 1 OR "users"."id" <= 2)
        }, mgr.to_sql
      end

      test "#lteq_all should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].lteq_all([1, 2])
      end

      test "#lteq_all should generate ANDs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].lteq_all([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" <= 1 AND "users"."id" <= 2)
        }, mgr.to_sql
      end

      test "#average should create an AVG node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Avg, relation[:id].average
      end

      test "#average should generate the proper SQL" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id].average
        assert_like %{
          SELECT AVG("users"."id")
          FROM "users"
        }, mgr.to_sql
      end

      test "#maximum should create a MAX node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Max, relation[:id].maximum
      end

      test "#maximum should generate proper SQL" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id].maximum
        assert_like %{
          SELECT MAX("users"."id")
          FROM "users"
        }, mgr.to_sql
      end

      test "#minimum should create a Min node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Min, relation[:id].minimum
      end

      test "#minimum should generate proper SQL" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id].minimum
        assert_like %{
          SELECT MIN("users"."id")
          FROM "users"
        }, mgr.to_sql
      end

      test "#sum should create a SUM node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Sum, relation[:id].sum
      end

      test "#sum should generate the proper SQL" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id].sum
        assert_like %{
          SELECT SUM("users"."id")
          FROM "users"
        }, mgr.to_sql
      end

      test "#count should return a count node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Count, relation[:id].count
      end

      test "#count should take a distinct param" do
        relation = Table.new(:users)
        count = relation[:id].count(nil)
        assert_kind_of Nodes::Count, count
        assert_nil count.distinct
      end

      test "#eq should return an equality node" do
        attribute = Attribute.new nil, nil
        equality = attribute.eq 1
        assert_equal attribute, equality.left
        assert_equal 1, equality.right.value
        assert_kind_of Nodes::Equality, equality
      end

      test "#eq should generate = in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].eq(10)
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE "users"."id" = 10
        }, mgr.to_sql
      end

      test "#eq should handle nil" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].eq(nil)
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE "users"."id" IS NULL
        }, mgr.to_sql
      end

      test "#eq_any should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].eq_any([1, 2])
      end

      test "#eq_any should generate ORs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].eq_any([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" = 1 OR "users"."id" = 2)
        }, mgr.to_sql
      end

      test "#eq_any should not eat input" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        values = [1, 2]
        mgr.where relation[:id].eq_any(values)
        assert_equal [1, 2], values
      end

      test "#eq_all should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].eq_all([1, 2])
      end

      test "#eq_all should generate ANDs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].eq_all([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" = 1 AND "users"."id" = 2)
        }, mgr.to_sql
      end

      test "#eq_all should not eat input" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        values = [1, 2]
        mgr.where relation[:id].eq_all(values)
        assert_equal [1, 2], values
      end

      test "#matches should create a Matches node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Matches, relation[:name].matches("%bacon%")
      end

      test "#matches should generate LIKE in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:name].matches("%bacon%")
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE "users"."name" LIKE '%bacon%'
        }, mgr.to_sql
      end

      test "#matches_any should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:name].matches_any(["%chunky%", "%bacon%"])
      end

      test "#matches_any should generate ORs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:name].matches_any(["%chunky%", "%bacon%"])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."name" LIKE '%chunky%' OR "users"."name" LIKE '%bacon%')
        }, mgr.to_sql
      end

      test "#matches_all should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:name].matches_all(["%chunky%", "%bacon%"])
      end

      test "#matches_all should generate ANDs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:name].matches_all(["%chunky%", "%bacon%"])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."name" LIKE '%chunky%' AND "users"."name" LIKE '%bacon%')
        }, mgr.to_sql
      end

      test "#does_not_match should create a DoesNotMatch node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::DoesNotMatch, relation[:name].does_not_match("%bacon%")
      end

      test "#does_not_match should generate NOT LIKE in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:name].does_not_match("%bacon%")
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE "users"."name" NOT LIKE '%bacon%'
        }, mgr.to_sql
      end

      test "#does_not_match_any should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:name].does_not_match_any(["%chunky%", "%bacon%"])
      end

      test "#does_not_match_any should generate ORs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:name].does_not_match_any(["%chunky%", "%bacon%"])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."name" NOT LIKE '%chunky%' OR "users"."name" NOT LIKE '%bacon%')
        }, mgr.to_sql
      end

      test "#does_not_match_all should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:name].does_not_match_all(["%chunky%", "%bacon%"])
      end

      test "#does_not_match_all should generate ANDs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:name].does_not_match_all(["%chunky%", "%bacon%"])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."name" NOT LIKE '%chunky%' AND "users"."name" NOT LIKE '%bacon%')
        }, mgr.to_sql
      end

      test "#between can be constructed with a standard range" do
        attribute = Attribute.new nil, nil
        node = attribute.between(1..3)

        assert_equal Nodes::Between.new(
          attribute,
          Nodes::And.new([
            Nodes::Casted.new(1, attribute),
            Nodes::Casted.new(3, attribute)
          ])
        ), node
      end

      test "#between can be constructed with a range starting from -Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.between(-::Float::INFINITY..3)

        assert_equal Nodes::LessThanOrEqual.new(
          attribute,
          Nodes::Casted.new(3, attribute)
        ), node
      end

      test "#between can be constructed with a quoted range starting from -Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.between(quoted_range(-::Float::INFINITY, 3, false))

        assert_equal Nodes::LessThanOrEqual.new(
          attribute,
          Nodes::Quoted.new(3)
        ), node
      end

      test "#between can be constructed with an exclusive range starting from -Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.between(-::Float::INFINITY...3)

        assert_equal Nodes::LessThan.new(
          attribute,
          Nodes::Casted.new(3, attribute)
        ), node
      end

      test "#between can be constructed with a quoted exclusive range starting from -Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.between(quoted_range(-::Float::INFINITY, 3, true))

        assert_equal Nodes::LessThan.new(
          attribute,
          Nodes::Quoted.new(3)
        ), node
      end

      test "#between can be constructed with an infinite range" do
        attribute = Attribute.new nil, nil
        node = attribute.between(-::Float::INFINITY..::Float::INFINITY)

        assert_equal Nodes::NotIn.new(attribute, []), node
      end

      test "#between can be constructed with a quoted infinite range" do
        attribute = Attribute.new nil, nil
        node = attribute.between(quoted_range(-::Float::INFINITY, ::Float::INFINITY, false))

        assert_equal Nodes::NotIn.new(attribute, []), node
      end

      test "#between can be constructed with a range ending at Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.between(0..::Float::INFINITY)

        assert_equal Nodes::GreaterThanOrEqual.new(
          attribute,
          Nodes::Casted.new(0, attribute)
        ), node
      end

      test "#between can be constructed with a range implicitly starting at Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.between(..0)

        assert_equal Nodes::LessThanOrEqual.new(
          attribute,
          Nodes::Casted.new(0, attribute)
        ), node
      end

      test "#between can be constructed with a range implicitly ending at Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.between(0..)

        assert_equal Nodes::GreaterThanOrEqual.new(
          attribute,
          Nodes::Casted.new(0, attribute)
        ), node
      end

      test "#between can be constructed with an exclusive range implicitly ending at Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.between(0...)

        assert_equal Nodes::GreaterThanOrEqual.new(
          attribute,
          Nodes::Casted.new(0, attribute)
        ), node
      end

      test "#between can be constructed with a quoted range ending at Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.between(quoted_range(0, ::Float::INFINITY, false))

        assert_equal Nodes::GreaterThanOrEqual.new(
          attribute,
          Nodes::Quoted.new(0)
        ), node
      end

      test "#between can be constructed with an endless range starting from Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.between(::Float::INFINITY..)

        assert_equal Nodes::In.new(attribute, []), node
      end

      test "#between can be constructed with a beginless range ending in -Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.between(..-::Float::INFINITY)

        assert_equal Nodes::In.new(attribute, []), node
      end

      test "#between can be constructed with an exclusive range" do
        attribute = Attribute.new nil, nil
        node = attribute.between(0...3)

        assert_equal Nodes::And.new([
          Nodes::GreaterThanOrEqual.new(
            attribute,
            Nodes::Casted.new(0, attribute)
          ),
          Nodes::LessThan.new(
            attribute,
            Nodes::Casted.new(3, attribute)
          )
        ]), node
      end

      test "#between can be constructed with a range where the begin and end are equal" do
        attribute = Attribute.new nil, nil
        node = attribute.between(1..1)

        assert_equal Nodes::Equality.new(
          attribute,
          Nodes::Casted.new(1, attribute)
        ), node
      end

      test "#in can be constructed with a subquery" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:name].does_not_match_all(["%chunky%", "%bacon%"])
        attribute = Attribute.new nil, nil

        node = attribute.in(mgr)

        assert_equal Nodes::In.new(attribute, mgr.ast), node
      end

      test "#in can be constructed with a list" do
        attribute = Attribute.new nil, nil
        node = attribute.in([1, 2, 3])

        assert_equal Nodes::In.new(
          attribute,
          [
            Nodes::Casted.new(1, attribute),
            Nodes::Casted.new(2, attribute),
            Nodes::Casted.new(3, attribute),
          ]
        ), node
      end

      test "#in can be constructed with a random object" do
        attribute = Attribute.new nil, nil
        random_object = Object.new
        node = attribute.in(random_object)

        assert_equal Nodes::In.new(
          attribute,
          Nodes::Casted.new(random_object, attribute)
        ), node
      end

      test "#in should generate IN in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].in([1, 2, 3])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE "users"."id" IN (1, 2, 3)
        }, mgr.to_sql
      end

      test "#in_any should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].in_any([1, 2])
      end

      test "#in_any should generate ORs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].in_any([[1, 2], [3, 4]])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" IN (1, 2) OR "users"."id" IN (3, 4))
        }, mgr.to_sql
      end

      test "#in_all should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].in_all([1, 2])
      end

      test "#in_all should generate ANDs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].in_all([[1, 2], [3, 4]])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" IN (1, 2) AND "users"."id" IN (3, 4))
        }, mgr.to_sql
      end

      test "#not_between can be constructed with a standard range" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(1..3)

        assert_equal Nodes::Grouping.new(
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
        ), node
      end

      test "#not_between can be constructed with a range starting from -Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(-::Float::INFINITY..3)

        assert_equal Nodes::GreaterThan.new(
          attribute,
          Nodes::Casted.new(3, attribute)
        ), node
      end

      test "#not_between can be constructed with a quoted range starting from -Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(quoted_range(-::Float::INFINITY, 3, false))

        assert_equal Nodes::GreaterThan.new(
          attribute,
          Nodes::Quoted.new(3)
        ), node
      end

      test "#not_between can be constructed with an exclusive range starting from -Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(-::Float::INFINITY...3)

        assert_equal Nodes::GreaterThanOrEqual.new(
          attribute,
          Nodes::Casted.new(3, attribute)
        ), node
      end

      test "#not_between can be constructed with a quoted exclusive range starting from -Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(quoted_range(-::Float::INFINITY, 3, true))

        assert_equal Nodes::GreaterThanOrEqual.new(
          attribute,
          Nodes::Quoted.new(3)
        ), node
      end

      test "#not_between can be constructed with an infinite range" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(-::Float::INFINITY..::Float::INFINITY)

        assert_equal Nodes::In.new(attribute, []), node
      end

      test "#not_between can be constructed with a quoted infinite range" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(quoted_range(-::Float::INFINITY, ::Float::INFINITY, false))

        assert_equal Nodes::In.new(attribute, []), node
      end

      test "#not_between can be constructed with a range ending at Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(0..::Float::INFINITY)

        assert_equal Nodes::LessThan.new(
          attribute,
          Nodes::Casted.new(0, attribute)
        ), node
      end

      test "#not_between can be constructed with a range implicitly starting at Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(..0)

        assert_equal Nodes::GreaterThan.new(
          attribute,
          Nodes::Casted.new(0, attribute)
        ), node
      end

      test "#not_between can be constructed with a range implicitly ending at Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(0..)

        assert_equal Nodes::LessThan.new(
          attribute,
          Nodes::Casted.new(0, attribute)
        ), node
      end

      test "#not_between can be constructed with a quoted range ending at Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(quoted_range(0, ::Float::INFINITY, false))

        assert_equal Nodes::LessThan.new(
          attribute,
          Nodes::Quoted.new(0)
        ), node
      end

      test "#not_between can be constructed with an endless range starting from Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(::Float::INFINITY..)

        assert_equal Nodes::NotIn.new(attribute, []), node
      end

      test "#not_between can be constructed with a beginless range ending in -Infinity" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(..-::Float::INFINITY)

        assert_equal Nodes::NotIn.new(attribute, []), node
      end

      test "#not_between can be constructed with an exclusive range" do
        attribute = Attribute.new nil, nil
        node = attribute.not_between(0...3)

        assert_equal Nodes::Grouping.new(
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
        ), node
      end

      test "#not_in can be constructed with a subquery" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:name].does_not_match_all(["%chunky%", "%bacon%"])
        attribute = Attribute.new nil, nil

        node = attribute.not_in(mgr)

        assert_equal Nodes::NotIn.new(attribute, mgr.ast), node
      end

      test "#not_in can be constructed with a Union" do
        relation = Table.new(:users)
        mgr1 = relation.project(relation[:id])
        mgr2 = relation.project(relation[:id])

        union = mgr1.union(mgr2)
        node = relation[:id].in(union)
        assert_like %{
          "users"."id" IN (( SELECT "users"."id" FROM "users" UNION SELECT "users"."id" FROM "users" ))
        }, node.to_sql
      end

      test "#not_in can be constructed with a list" do
        attribute = Attribute.new nil, nil
        node = attribute.not_in([1, 2, 3])

        assert_equal Nodes::NotIn.new(
          attribute,
          [
            Nodes::Casted.new(1, attribute),
            Nodes::Casted.new(2, attribute),
            Nodes::Casted.new(3, attribute),
          ]
        ), node
      end

      test "#not_in can be constructed with a random object" do
        attribute = Attribute.new nil, nil
        random_object = Object.new
        node = attribute.not_in(random_object)

        assert_equal Nodes::NotIn.new(
          attribute,
          Nodes::Casted.new(random_object, attribute)
        ), node
      end

      test "#not_in should generate NOT IN in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].not_in([1, 2, 3])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE "users"."id" NOT IN (1, 2, 3)
        }, mgr.to_sql
      end

      test "#not_in_any should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].not_in_any([1, 2])
      end

      test "#not_in_any should generate ORs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].not_in_any([[1, 2], [3, 4]])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" NOT IN (1, 2) OR "users"."id" NOT IN (3, 4))
        }, mgr.to_sql
      end

      test "#not_in_all should create a Grouping node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].not_in_all([1, 2])
      end

      test "#not_in_all should generate ANDs in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].not_in_all([[1, 2], [3, 4]])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" NOT IN (1, 2) AND "users"."id" NOT IN (3, 4))
        }, mgr.to_sql
      end

      test "#eq_all should create a Grouping node (2)" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Grouping, relation[:id].eq_all([1, 2])
      end

      test "#eq_all should generate ANDs in sql (2)" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.where relation[:id].eq_all([1, 2])
        assert_like %{
          SELECT "users"."id" FROM "users" WHERE ("users"."id" = 1 AND "users"."id" = 2)
        }, mgr.to_sql
      end

      test "#asc should create an Ascending node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Ascending, relation[:id].asc
      end

      test "#asc should generate ASC in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.order relation[:id].asc
        assert_like %{
          SELECT "users"."id" FROM "users" ORDER BY "users"."id" ASC
        }, mgr.to_sql
      end

      test "#desc should create a Descending node" do
        relation = Table.new(:users)
        assert_kind_of Nodes::Descending, relation[:id].desc
      end

      test "#desc should generate DESC in sql" do
        relation = Table.new(:users)
        mgr = relation.project relation[:id]
        mgr.order relation[:id].desc
        assert_like %{
          SELECT "users"."id" FROM "users" ORDER BY "users"."id" DESC
        }, mgr.to_sql
      end

      test "#contains should create a Contains node" do
        relation = Table.new(:products)
        assert_kind_of Nodes::Contains, relation[:tags].contains(["foo", "bar"])
      end

      test "#contains should generate @> in sql" do
        relation = Table.new(:products, type_caster: fake_pg_caster)
        mgr = relation.project relation[:id]
        mgr.where relation[:tags].contains(["foo", "bar"])
        assert_like %{ SELECT "products"."id" FROM "products" WHERE "products"."tags" @> '{foo,bar}' }, mgr.to_sql
      end

      test "#overlaps should create an Overlaps node" do
        relation = Table.new(:products)
        assert_kind_of Nodes::Overlaps, relation[:tags].overlaps(["foo", "bar"])
      end

      test "#overlaps should generate && in sql" do
        relation = Table.new(:products, type_caster: fake_pg_caster)
        mgr = relation.project relation[:id]
        mgr.where relation[:tags].overlaps(["foo", "bar"])
        assert_like %{ SELECT "products"."id" FROM "products" WHERE "products"."tags" && '{foo,bar}' }, mgr.to_sql
      end

      test "equality #to_sql should produce sql" do
        table = Table.new :users
        condition = table["id"].eq 1
        assert_equal '"users"."id" = 1', condition.to_sql
      end

      test "type casting does not type cast by default" do
        table = Table.new(:foo)
        condition = table["id"].eq("1")

        assert_not table.able_to_type_cast?
        assert_equal %("foo"."id" = '1'), condition.to_sql
      end

      test "type casting type casts when given an explicit caster" do
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
        assert_equal %("foo"."id" = 1 AND "foo"."other_id" = '2'), condition.to_sql
      end

      test "type casting does not type cast SqlLiteral nodes" do
        fake_caster = Object.new
        def fake_caster.type_cast_for_database(attr_name, value)
          value.to_i
        end
        table = Table.new(:foo, type_caster: fake_caster)
        condition = table["id"].eq(Arel.sql("(select 1)"))

        assert_predicate table, :able_to_type_cast?
        assert_equal %("foo"."id" = (select 1)), condition.to_sql
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
