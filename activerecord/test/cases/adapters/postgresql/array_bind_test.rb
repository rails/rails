# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/author"

module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter
      # Tests for Arel.array_bind, which sends an IN/NOT IN list as a single
      # array bind (+col = ANY($1)+ / +col <> ALL($1)+) instead of expanding
      # every value into the SQL text.
      class ArrayBindTest < ActiveRecord::PostgreSQLTestCase
        fixtures :posts, :authors

        def test_in_compiles_to_any_with_a_single_bind
          relation = Post.where(id: Arel.array_bind([1, 2, 3]))
          assert_equal(
            %{SELECT "posts".* FROM "posts" WHERE "posts"."id" = ANY($1)},
            relation.to_sql
          )
        end

        def test_not_in_compiles_to_all_with_a_single_bind
          relation = Post.where.not(id: Arel.array_bind([1, 2, 3]))
          assert_equal(
            %{SELECT "posts".* FROM "posts" WHERE "posts"."id" <> ALL($1)},
            relation.to_sql
          )
        end

        def test_sql_size_is_constant_regardless_of_list_length
          small = Post.where(id: Arel.array_bind([1, 2])).to_sql
          large = Post.where(id: Arel.array_bind((1..5000).to_a)).to_sql
          assert_equal small, large
        end

        def test_returns_the_same_records_as_a_regular_in_query
          ids = Post.limit(3).pluck(:id)

          assert_equal(
            Post.where(id: ids).order(:id).to_a,
            Post.where(id: Arel.array_bind(ids)).order(:id).to_a
          )
        end

        def test_not_in_returns_the_same_records_as_a_regular_not_in_query
          ids = Post.limit(3).pluck(:id)

          assert_equal(
            Post.where.not(id: ids).order(:id).to_a,
            Post.where.not(id: Arel.array_bind(ids)).order(:id).to_a
          )
        end

        def test_works_when_prepared_statements_are_disabled
          Post.lease_connection.unprepared_statement do
            ids = Post.limit(3).pluck(:id)
            relation = Post.where(id: Arel.array_bind(ids))

            assert_includes relation.to_sql, "= ANY($1)"
            assert_equal Post.where(id: ids).count, relation.count
          end
        end

        def test_matches_string_values_safely
          titles = Post.limit(2).pluck(:title)
          titles << "', injected) --"

          assert_equal(
            Post.where(title: titles.first(2)).order(:id).to_a,
            Post.where(title: Arel.array_bind(titles)).order(:id).to_a
          )
        end

        def test_nil_values_are_split_into_a_separate_predicate
          relation = Post.where(id: Arel.array_bind([1, 2, nil]))

          assert_equal(
            %{SELECT "posts".* FROM "posts" WHERE ("posts"."id" = ANY($1) OR "posts"."id" IS NULL)},
            relation.to_sql
          )
        end

        def test_single_value_does_not_use_an_array_bind
          # A single value is a plain equality, so no array bind is needed.
          relation = Post.where(id: Arel.array_bind([1]))
          assert_not_includes relation.to_sql, "ANY"
          assert_equal Post.where(id: 1).to_a, relation.to_a
        end

        def test_empty_array_matches_nothing
          relation = Post.where(id: Arel.array_bind([]))
          assert_equal Post.where(id: []).to_sql, relation.to_sql
          assert_empty relation.to_a
        end

        def test_accepts_a_set
          ids = Post.limit(2).pluck(:id)

          assert_equal(
            Post.where(id: ids).order(:id).to_a,
            Post.where(id: Arel.array_bind(Set.new(ids))).order(:id).to_a
          )
        end

        def test_not_in_drops_values_that_serialize_to_nil
          # An arbitrary object is serializable? for integer columns but
          # serializes to nil. Regular HomogeneousIn drops it via casted_values;
          # array binds must do the same so <> ALL does not see a NULL element
          # (which would filter out every row).
          unserializable = Object.new
          ids = [posts(:welcome).id, unserializable]

          assert_equal(
            Post.where.not(id: ids).order(:id).to_a,
            Post.where.not(id: Arel.array_bind(ids)).order(:id).to_a
          )
        end

        def test_in_drops_values_that_serialize_to_nil
          unserializable = Object.new
          ids = [posts(:welcome).id, unserializable]

          assert_equal(
            Post.where(id: ids).order(:id).to_a,
            Post.where(id: Arel.array_bind(ids)).order(:id).to_a
          )
        end

        def test_remains_preparable_with_a_single_bind
          connection = Post.lease_connection
          skip "requires prepared statements" unless connection.prepared_statements

          arel = Post.where(id: Arel.array_bind([1, 2, 3])).arel
          _sql, binds, preparable = connection.send(:to_sql_and_binds, arel)

          assert preparable, "array-bind queries have a fixed single placeholder and should be preparable"
          assert_equal 1, binds.length
        end

        def test_statement_cache_keeps_array_bind_under_unprepared_statements
          ids = Post.limit(3).pluck(:id)
          large_ids = (1..500).to_a

          Post.lease_connection.unprepared_statement do
            cache = ActiveRecord::StatementCache.create(Post.lease_connection) do |_params|
              Post.where(id: Arel.array_bind(ids))
            end

            result = cache.execute([], Post.lease_connection)
            assert_equal Post.where(id: ids).order(:id).to_a, result.sort_by(&:id)

            # Rebuild a cache for a large list and assert the partial SQL keeps
            # a single placeholder rather than expanding the array into text.
            large_cache = ActiveRecord::StatementCache.create(Post.lease_connection) do |_params|
              Post.where(id: Arel.array_bind(large_ids))
            end

            query_builder = large_cache.instance_variable_get(:@query_builder)
            bind_map = large_cache.instance_variable_get(:@bind_map)
            bind_values = bind_map.bind([])
            sql = query_builder.sql_for(bind_values, Post.lease_connection)

            assert_includes sql, "= ANY($1)"
            assert_not_includes sql, large_ids.first(5).join(", ")
            assert_equal 1, bind_values.length
          end
        end

        def test_invert_preserves_array_bind_node
          relation = Post.where(id: Arel.array_bind([1, 2, 3]))
          inverted = relation.invert_where

          assert_includes inverted.to_sql, "<> ALL($1)"
          assert_not_includes inverted.to_sql, "NOT IN"
        end
      end
    end
  end
end
