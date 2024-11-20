# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"
require "models/rating"
require "models/author"
require "models/essay"
require "models/category"
require "models/categorization"
require "models/person"
require "models/friendship"
require "models/reference"
require "models/job"

class LeftOuterJoinAssociationTest < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :essays, :posts, :comments, :ratings, :categorizations, :people

  def test_merging_multiple_left_joins_from_different_associations
    count = Author.joins(:posts).merge(Post.left_joins(:comments).merge(Comment.left_joins(:ratings))).count
    assert_equal 17, count

    count = Author.left_joins(:posts).merge(Post.left_joins(:comments).merge(Comment.left_joins(:ratings))).count
    assert_equal 17, count
  end

  def test_construct_finder_sql_applies_aliases_tables_on_association_conditions
    result = Author.left_outer_joins(:thinking_posts, :welcome_posts).first
    assert_equal authors(:david), result
  end

  def test_construct_finder_sql_does_not_table_name_collide_on_duplicate_associations
    assert_nothing_raised do
      queries = capture_sql do
        Person.left_outer_joins(agents: { agents: :agents })
              .left_outer_joins(agents: { agents: { primary_contact: :agents } }).to_a
      end
      assert queries.any? { |sql| /agents_people_4/i.match?(sql) }
    end
  end

  def test_left_outer_joins_count_is_same_as_size_of_loaded_results
    assert_equal 18, Post.left_outer_joins(:comments).to_a.size
    assert_equal 18, Post.left_outer_joins(:comments).count
  end

  def test_merging_left_joins_should_be_left_joins
    assert_equal 5, Author.left_joins(:posts).merge(Post.no_comments).count
  end

  def test_left_joins_aliases_left_outer_joins
    assert_equal Post.left_outer_joins(:comments).to_sql, Post.left_joins(:comments).to_sql
  end

  def test_left_outer_joins_return_has_value_for_every_comment
    all_post_ids = Post.pluck(:id)
    assert_equal all_post_ids, all_post_ids & Post.left_outer_joins(:comments).pluck(:id)
  end

  def test_left_outer_joins_actually_does_a_left_outer_join
    queries = capture_sql { Author.left_outer_joins(:posts).to_a }
    assert queries.any? { |sql| /LEFT OUTER JOIN/i.match?(sql) }
  end

  def test_left_outer_joins_is_deduped_when_same_association_is_joined
    queries = capture_sql { Author.joins(:posts).left_outer_joins(:posts).to_a }
    assert queries.any? { |sql| /INNER JOIN/i.match?(sql) }
    assert queries.none? { |sql| /LEFT OUTER JOIN/i.match?(sql) }
  end

  def test_construct_finder_sql_ignores_empty_left_outer_joins_hash
    queries = capture_sql { Author.left_outer_joins({}).to_a }
    assert queries.none? { |sql| /LEFT OUTER JOIN/i.match?(sql) }
  end

  def test_construct_finder_sql_ignores_empty_left_outer_joins_array
    queries = capture_sql { Author.left_outer_joins([]).to_a }
    assert queries.none? { |sql| /LEFT OUTER JOIN/i.match?(sql) }
  end

  def test_left_outer_joins_forbids_to_use_string_as_argument
    assert_raise(ArgumentError) { Author.left_outer_joins('LEFT OUTER JOIN "posts" ON "posts"."user_id" = "users"."id"').to_a }
  end

  def test_left_outer_joins_with_string_join
    assert_equal 17, Author.left_outer_joins(:posts).joins("LEFT OUTER JOIN comments ON comments.post_id = posts.id").count
  end

  def test_left_outer_joins_with_arel_join
    comments = Comment.arel_table
    posts = Post.arel_table
    constraint = comments[:post_id].eq(posts[:id])
    arel_join = comments.create_join(comments, comments.create_on(constraint), Arel::Nodes::OuterJoin)

    assert_equal 17, Author.left_outer_joins(:posts).joins(arel_join).count
  end

  def test_join_conditions_added_to_join_clause
    queries = capture_sql { Author.left_outer_joins(:essays).to_a }
    assert queries.any? { |sql| /writer_type.*?=.*?(Author|\?|\$1|:a1)/i.match?(sql) }
    assert queries.none? { |sql| /WHERE/i.match?(sql) }
  end

  def test_find_with_sti_join
    scope = Post.left_outer_joins(:special_comments).where(id: posts(:sti_comments).id)

    # The join should match SpecialComment and its subclasses only
    assert_empty scope.where("comments.type" => "Comment")
    assert_not_empty scope.where("comments.type" => "SpecialComment")
    assert_not_empty scope.where("comments.type" => "SubSpecialComment")
  end

  def test_does_not_override_select
    authors = Author.select("authors.name, #{%{(authors.author_address_id || ' ' || authors.author_address_extra_id) as addr_id}}").left_outer_joins(:posts)
    assert_predicate authors, :any?
    assert_respond_to authors.first, :addr_id
  end

  test "the default scope of the target is applied when joining associations" do
    author = Author.create! name: "Jon"
    author.categorizations.create!
    author.categorizations.create! special: true

    assert_equal [author], Author.where(id: author).left_outer_joins(:special_categorizations)
  end

  def test_left_outer_joins_includes_all_nested_associations
    sql, = capture_sql { Friendship.left_outer_joins(:friend_favorite_reference_job, :follower_favorite_reference_job).to_a }

    assert_match %r(#{Regexp.escape(quote_table_name("friendships.friend_id"))}), sql
    assert_match %r(#{Regexp.escape(quote_table_name("friendships.follower_id"))}), sql
  end
end
