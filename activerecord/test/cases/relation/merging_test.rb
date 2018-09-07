# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/comment"
require "models/developer"
require "models/computer"
require "models/post"
require "models/project"
require "models/rating"

class RelationMergingTest < ActiveRecord::TestCase
  fixtures :developers, :comments, :authors, :author_addresses, :posts

  def test_relation_merging
    devs = Developer.where("salary >= 80000").merge(Developer.limit(2)).merge(Developer.order("id ASC").where("id < 3"))
    assert_equal [developers(:david), developers(:jamis)], devs.to_a

    dev_with_count = Developer.limit(1).merge(Developer.order("id DESC")).merge(Developer.select("developers.*"))
    assert_equal [developers(:poor_jamis)], dev_with_count.to_a
  end

  def test_relation_to_sql
    post = Post.first
    sql = post.comments.to_sql
    assert_match(/.?post_id.? = #{post.id}\z/i, sql)
  end

  def test_relation_merging_with_arel_equalities_keeps_last_equality
    devs = Developer.where(Developer.arel_table[:salary].eq(80000)).merge(
      Developer.where(Developer.arel_table[:salary].eq(9000))
    )
    assert_equal [developers(:poor_jamis)], devs.to_a
  end

  def test_relation_merging_with_arel_equalities_keeps_last_equality_with_non_attribute_left_hand
    salary_attr = Developer.arel_table[:salary]
    devs = Developer.where(
      Arel::Nodes::NamedFunction.new("abs", [salary_attr]).eq(80000)
    ).merge(
      Developer.where(
        Arel::Nodes::NamedFunction.new("abs", [salary_attr]).eq(9000)
      )
    )
    assert_equal [developers(:poor_jamis)], devs.to_a
  end

  def test_relation_merging_with_eager_load
    relations = []
    relations << Post.order("comments.id DESC").merge(Post.eager_load(:last_comment)).merge(Post.all)
    relations << Post.eager_load(:last_comment).merge(Post.order("comments.id DESC")).merge(Post.all)

    relations.each do |posts|
      post = posts.find { |p| p.id == 1 }
      assert_equal Post.find(1).last_comment, post.last_comment
    end
  end

  def test_relation_merging_with_locks
    devs = Developer.lock.where("salary >= 80000").order("id DESC").merge(Developer.limit(2))
    assert_predicate devs, :locked?
  end

  def test_relation_merging_with_preload
    [Post.all.merge(Post.preload(:author)), Post.preload(:author).merge(Post.all)].each do |posts|
      assert_queries(2) { assert posts.first.author }
    end
  end

  def test_relation_merging_with_joins
    comments = Comment.joins(:post).where(body: "Thank you for the welcome").merge(Post.where(body: "Such a lovely day"))
    assert_equal 1, comments.count
  end

  def test_relation_merging_with_left_outer_joins
    comments = Comment.joins(:post).where(body: "Thank you for the welcome").merge(Post.left_outer_joins(:author).where(body: "Such a lovely day"))

    assert_equal 1, comments.count
  end

  def test_relation_merging_with_skip_query_cache
    assert_equal Post.all.merge(Post.all.skip_query_cache!).skip_query_cache_value, true
  end

  def test_relation_merging_with_association
    assert_queries(2) do  # one for loading post, and another one merged query
      post = Post.where(body: "Such a lovely day").first
      comments = Comment.where(body: "Thank you for the welcome").merge(post.comments)
      assert_equal 1, comments.count
    end
  end

  test "merge collapses wheres from the LHS only" do
    left = Post.where(title: "omg").where(comments_count: 1)
    right = Post.where(title: "wtf").where(title: "bbq")

    merged = left.merge(right)

    assert_not_includes merged.to_sql, "omg"
    assert_includes merged.to_sql, "wtf"
    assert_includes merged.to_sql, "bbq"
  end

  def test_merging_reorders_bind_params
    post  = Post.first
    right = Post.where(id: 1)
    left  = Post.where(title: post.title)

    merged = left.merge(right)
    assert_equal post, merged.first
  end

  def test_merging_compares_symbols_and_strings_as_equal
    post = PostThatLoadsCommentsInAnAfterSaveHook.create!(title: "First Post", body: "Blah blah blah.")
    assert_equal "First comment!", post.comments.where(body: "First comment!").first_or_create.body
  end

  def test_merging_with_from_clause
    relation = Post.all
    assert_empty relation.from_clause
    relation = relation.merge(Post.from("posts"))
    assert_not_empty relation.from_clause
  end

  def test_merging_with_order_with_binds
    relation = Post.all.merge(Post.order([Arel.sql("title LIKE ?"), "%suffix"]))
    assert_equal ["title LIKE '%suffix'"], relation.order_values
  end

  def test_merging_with_order_without_binds
    relation = Post.all.merge(Post.order(Arel.sql("title LIKE '%?'")))
    assert_equal ["title LIKE '%?'"], relation.order_values
  end
end

class MergingDifferentRelationsTest < ActiveRecord::TestCase
  fixtures :posts, :authors, :author_addresses, :developers

  test "merging where relations" do
    hello_by_bob = Post.where(body: "hello").joins(:author).
      merge(Author.where(name: "Bob")).order("posts.id").pluck("posts.id")

    assert_equal [posts(:misc_by_bob).id,
                  posts(:other_by_bob).id], hello_by_bob
  end

  test "merging order relations" do
    posts_by_author_name = Post.limit(3).joins(:author).
      merge(Author.order(:name)).pluck("authors.name")

    assert_equal ["Bob", "Bob", "David"], posts_by_author_name

    posts_by_author_name = Post.limit(3).joins(:author).
      merge(Author.order("name")).pluck("authors.name")

    assert_equal ["Bob", "Bob", "David"], posts_by_author_name
  end

  test "merging order relations (using a hash argument)" do
    posts_by_author_name = Post.limit(4).joins(:author).
      merge(Author.order(name: :desc)).pluck("authors.name")

    assert_equal ["Mary", "Mary", "Mary", "David"], posts_by_author_name
  end

  test "relation merging (using a proc argument)" do
    dev = Developer.where(name: "Jamis").first

    comment_1 = dev.comments.create!(body: "I'm Jamis", post: Post.first)
    rating_1 = comment_1.ratings.create!

    comment_2 = dev.comments.create!(body: "I'm John", post: Post.first)
    comment_2.ratings.create!

    assert_equal dev.ratings, [rating_1]
  end
end
