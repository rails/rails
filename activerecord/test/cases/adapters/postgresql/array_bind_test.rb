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
      end
    end
  end
end
