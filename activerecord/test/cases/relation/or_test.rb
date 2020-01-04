# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/categorization"
require "models/post"
require "models/citation"

module ActiveRecord
  class OrTest < ActiveRecord::TestCase
    fixtures :posts, :authors, :author_addresses

    def test_or_with_relation
      expected = Post.where("id = 1 or id = 2").to_a
      assert_equal expected, Post.where("id = 1").or(Post.where("id = 2")).to_a
    end

    def test_or_identity
      expected = Post.where("id = 1").to_a
      assert_equal expected, Post.where("id = 1").or(Post.where("id = 1")).to_a
    end

    def test_or_with_null_left
      expected = Post.where("id = 1").to_a
      assert_equal expected, Post.none.or(Post.where("id = 1")).to_a
    end

    def test_or_with_null_right
      expected = Post.where("id = 1").to_a
      assert_equal expected, Post.where("id = 1").or(Post.none).to_a
    end

    def test_or_with_large_number
      expected = Post.where("id = 1 or id = 9223372036854775808").to_a
      assert_equal expected, Post.where(id: 1).or(Post.where(id: 9223372036854775808)).to_a
    end

    def test_or_with_bind_params
      assert_equal Post.find([1, 2]).sort_by(&:id), Post.where(id: 1).or(Post.where(id: 2)).sort_by(&:id)
    end

    def test_or_with_null_both
      expected = Post.none.to_a
      assert_equal expected, Post.none.or(Post.none).to_a
    end

    def test_or_without_left_where
      expected = Post.all
      assert_equal expected, Post.or(Post.where("id = 1")).to_a
    end

    def test_or_without_right_where
      expected = Post.all
      assert_equal expected, Post.where("id = 1").or(Post.all).to_a
    end

    def test_or_preserves_other_querying_methods
      expected = Post.where("id = 1 or id = 2 or id = 3").order("body asc").to_a
      partial = Post.order("body asc")
      assert_equal expected, partial.where("id = 1").or(partial.where(id: [2, 3])).to_a
      assert_equal expected, Post.order("body asc").where("id = 1").or(Post.order("body asc").where(id: [2, 3])).to_a
    end

    def test_or_with_incompatible_relations
      error = assert_raises ArgumentError do
        Post.order("body asc").where("id = 1").or(Post.order("id desc").where(id: [2, 3])).to_a
      end

      assert_equal "Relation passed to #or must be structurally compatible. Incompatible values: [:order]", error.message
    end

    def test_or_with_unscope_where
      expected = Post.where("id = 1 or id = 2")
      partial = Post.where("id = 1 and id != 2")
      assert_equal expected, partial.or(partial.unscope(:where).where("id = 2")).to_a
    end

    def test_or_with_unscope_where_column
      expected = Post.where("id = 1 or id = 2")
      partial = Post.where(id: 1).where.not(id: 2)
      assert_equal expected, partial.or(partial.unscope(where: :id).where("id = 2")).to_a
    end

    def test_or_with_unscope_order
      expected = Post.where("id = 1 or id = 2")
      assert_equal expected, Post.order("body asc").where("id = 1").unscope(:order).or(Post.where("id = 2")).to_a
    end

    def test_or_with_incompatible_unscope
      error = assert_raises ArgumentError do
        Post.order("body asc").where("id = 1").or(Post.order("body asc").where("id = 2").unscope(:order)).to_a
      end

      assert_equal "Relation passed to #or must be structurally compatible. Incompatible values: [:order]", error.message
    end

    def test_or_when_grouping
      groups = Post.where("id < 10").group("body")
      expected = groups.having("COUNT(*) > 1 OR body like 'Such%'").count
      assert_equal expected, groups.having("COUNT(*) > 1").or(groups.having("body like 'Such%'")).count
    end

    def test_or_with_named_scope
      expected = Post.where("id = 1 or body LIKE '\%a\%'").to_a
      assert_equal expected, Post.where("id = 1").or(Post.containing_the_letter_a)
    end

    def test_or_inside_named_scope
      expected = Post.where("body LIKE '\%a\%' OR title LIKE ?", "%'%").order("id DESC").to_a
      assert_equal expected, Post.order(id: :desc).typographically_interesting
    end

    def test_or_on_loaded_relation
      expected = Post.where("id = 1 or id = 2").to_a
      p = Post.where("id = 1")
      p.load
      assert_equal true, p.loaded?
      assert_equal expected, p.or(Post.where("id = 2")).to_a
    end

    def test_or_with_non_relation_object_raises_error
      assert_raises ArgumentError do
        Post.where(id: [1, 2, 3]).or(title: "Rails")
      end
    end

    def test_or_with_references_inequality
      joined = Post.includes(:author)
      actual = joined.where(authors: { id: 1 })
        .or(joined.where(title: "I don't have any comments"))
      expected = Author.find(1).posts + Post.where(title: "I don't have any comments")
      assert_equal expected.sort_by(&:id), actual.sort_by(&:id)
    end

    def test_or_with_scope_on_association
      author = Author.first
      assert_nothing_raised do
        author.top_posts.or(author.other_top_posts)
      end
    end

    def test_or_with_annotate
      quoted_posts = Regexp.escape(Post.quoted_table_name)
      assert_match %r{#{quoted_posts} /\* foo \*/\z}, Post.annotate("foo").or(Post.all).to_sql
      assert_match %r{#{quoted_posts} /\* foo \*/\z}, Post.annotate("foo").or(Post.annotate("foo")).to_sql
      assert_match %r{#{quoted_posts} /\* foo \*/\z}, Post.annotate("foo").or(Post.annotate("bar")).to_sql
      assert_match %r{#{quoted_posts} /\* foo \*/ /\* bar \*/\z}, Post.annotate("foo", "bar").or(Post.annotate("foo")).to_sql
    end

    def test_structurally_incompatible_values
      assert_nothing_raised do
        Post.includes(:author).includes(:author).or(Post.includes(:author))
        Post.eager_load(:author).eager_load(:author).or(Post.eager_load(:author))
        Post.preload(:author).preload(:author).or(Post.preload(:author))
        Post.group(:author_id).group(:author_id).or(Post.group(:author_id))
        Post.joins(:author).joins(:author).or(Post.joins(:author))
        Post.left_outer_joins(:author).left_outer_joins(:author).or(Post.left_outer_joins(:author))
        Post.from("posts").or(Post.from("posts"))
      end
    end
  end

  # The maximum expression tree depth is 1000 by default for SQLite3.
  # https://www.sqlite.org/limits.html#max_expr_depth
  unless current_adapter?(:SQLite3Adapter)
    class TooManyOrTest < ActiveRecord::TestCase
      fixtures :citations

      def test_too_many_or
        citations = 6000.times.map do |i|
          Citation.where(id: i, book2_id: i * i)
        end

        assert_equal 6000, citations.inject(&:or).count
      end
    end
  end
end
