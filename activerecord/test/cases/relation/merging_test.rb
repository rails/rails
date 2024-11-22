# frozen_string_literal: true

require "cases/helper"
require "models/author"
require "models/categorization"
require "models/comment"
require "models/developer"
require "models/computer"
require "models/post"
require "models/project"
require "models/rating"

class RelationMergingTest < ActiveRecord::TestCase
  fixtures :developers, :comments, :authors, :author_addresses, :posts

  def test_merge_in_clause
    david, mary, bob = authors = authors(:david, :mary, :bob)

    david_and_mary = Author.where(id: [david, mary]).order(:id)
    mary_and_bob   = Author.where(id: [mary, bob]).order(:id)

    assert_equal [david, mary], david_and_mary
    assert_equal [mary, bob],   mary_and_bob

    assert_equal [mary], david_and_mary.merge(Author.where(id: mary))
    assert_equal [mary], david_and_mary.merge(Author.rewhere(id: mary))

    assert_equal [bob],  david_and_mary.merge(Author.where(id: bob))
    assert_equal [bob],  david_and_mary.merge(Author.rewhere(id: bob))

    assert_equal [david, bob], mary_and_bob.merge(Author.where(id: [david, bob]))

    assert_equal [mary, bob], david_and_mary.merge(mary_and_bob)
    assert_equal [mary], david_and_mary.and(mary_and_bob)
    assert_equal authors, david_and_mary.or(mary_and_bob)

    assert_equal [david, mary], mary_and_bob.merge(david_and_mary)
    assert_equal [mary], david_and_mary.and(mary_and_bob)
    assert_equal authors, david_and_mary.or(mary_and_bob)

    david_and_bob = Author.where(id: david).or(Author.where(name: "Bob"))

    assert_equal [david], david_and_mary.merge(david_and_bob)
    assert_equal [david], david_and_mary.and(david_and_bob)
    assert_equal authors, david_and_mary.or(david_and_bob)
  end

  def test_merge_between_clause
    david, mary, bob = authors = authors(:david, :mary, :bob)

    david_and_mary = Author.where(id: david.id..mary.id).order(:id)
    mary_and_bob   = Author.where(id: mary.id..bob.id).order(:id)

    assert_equal [david, mary], david_and_mary
    assert_equal [mary, bob],   mary_and_bob

    assert_equal [mary], david_and_mary.merge(Author.where(id: mary))
    assert_equal [mary], david_and_mary.merge(Author.rewhere(id: mary))

    assert_equal [bob], david_and_mary.merge(Author.where(id: bob))
    assert_equal [bob],  david_and_mary.merge(Author.rewhere(id: bob))

    assert_equal [david, bob], mary_and_bob.merge(Author.where(id: [david, bob]))

    assert_equal [mary, bob], david_and_mary.merge(mary_and_bob)
    assert_equal [mary], david_and_mary.and(mary_and_bob)
    assert_equal authors, david_and_mary.or(mary_and_bob)

    assert_equal [david, mary], mary_and_bob.merge(david_and_mary)
    assert_equal [mary], david_and_mary.and(mary_and_bob)
    assert_equal authors, david_and_mary.or(mary_and_bob)

    david_and_bob = Author.where(id: david).or(Author.where(name: "Bob"))

    assert_equal [david], david_and_mary.merge(david_and_bob)
    assert_equal [david], david_and_mary.and(david_and_bob)
    assert_equal authors, david_and_mary.or(david_and_bob)
  end

  def test_merge_or_clause
    david, mary, bob = authors = authors(:david, :mary, :bob)

    david_and_mary = Author.where(id: david).or(Author.where(id: mary)).order(:id)
    mary_and_bob   = Author.where(id: mary).or(Author.where(id: bob)).order(:id)

    assert_equal [david, mary], david_and_mary
    assert_equal [mary, bob],   mary_and_bob

    assert_equal [mary], david_and_mary.merge(Author.where(id: mary))
    assert_equal [mary], david_and_mary.merge(Author.rewhere(id: mary))

    assert_equal [bob], david_and_mary.merge(Author.where(id: bob))
    assert_equal [bob],  david_and_mary.merge(Author.rewhere(id: bob))

    assert_equal [david, bob], mary_and_bob.merge(Author.where(id: [david, bob]))

    assert_equal [mary, bob], david_and_mary.merge(mary_and_bob)
    assert_equal [mary], david_and_mary.and(mary_and_bob)
    assert_equal authors, david_and_mary.or(mary_and_bob)

    assert_equal [david, mary], mary_and_bob.merge(david_and_mary)
    assert_equal [mary], david_and_mary.and(mary_and_bob)
    assert_equal authors, david_and_mary.or(mary_and_bob)

    david_and_bob = Author.where(id: david).or(Author.where(name: "Bob"))

    assert_equal [david], david_and_mary.merge(david_and_bob)
    assert_equal [david], david_and_mary.and(david_and_bob)
    assert_equal authors, david_and_mary.or(david_and_bob)
  end

  def test_merge_not_in_clause
    david, mary, bob = authors(:david, :mary, :bob)

    non_mary_and_bob = Author.where.not(id: [mary, bob])

    assert_equal [david], non_mary_and_bob

    assert_equal [david], Author.where(id: david).merge(non_mary_and_bob)

    assert_equal [david], Author.where(id: mary).merge(non_mary_and_bob)
  end

  def test_merge_not_range_clause
    david, mary, bob = authors(:david, :mary, :bob)

    less_than_bob = Author.where.not(id: bob.id..Float::INFINITY).order(:id)

    assert_equal [david, mary], less_than_bob

    assert_equal [david, mary], Author.where(id: david).merge(less_than_bob)

    assert_equal [david, mary], Author.where(id: mary).merge(less_than_bob)
  end

  def test_merge_doesnt_duplicate_same_clauses
    david, mary, bob = authors(:david, :mary, :bob)

    non_mary_and_bob = Author.where.not(id: [mary, bob])

    author_id = quote_table_name("authors.id")
    assert_queries_match(/WHERE #{Regexp.escape(author_id)} NOT IN \((\?|\W?\w?\d), \g<1>\)\z/) do
      assert_equal [david], non_mary_and_bob.merge(non_mary_and_bob)
    end

    only_david = Author.where("#{author_id} IN (?)", david)

    matcher = if Author.lease_connection.prepared_statements
      if current_adapter?(:PostgreSQLAdapter)
        /WHERE \(#{Regexp.escape(author_id)} IN \(\$1\)\)\z/
      else
        /WHERE \(#{Regexp.escape(author_id)} IN \(\?\)\)\z/
      end
    elsif current_adapter?(:Mysql2Adapter, :TrilogyAdapter)
      /WHERE \(#{Regexp.escape(author_id)} IN \('1'\)\)\z/
    else
      /WHERE \(#{Regexp.escape(author_id)} IN \(1\)\)\z/
    end

    assert_queries_match(matcher) do
      assert_equal [david], only_david.merge(only_david)
    end
  end

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
    salary_attr = Developer.arel_table[:salary]

    devs = Developer.where(salary_attr.eq(80000)).merge(Developer.where(salary_attr.eq(9000)))
    assert_equal [developers(:poor_jamis)], devs.to_a

    devs = Developer.where(salary_attr.eq(80000)).rewhere(salary_attr.eq(9000))
    assert_equal [developers(:poor_jamis)], devs.to_a
  end

  def test_relation_merging_with_arel_equalities_keeps_last_equality_with_non_attribute_left_hand
    salary_attr = Developer.arel_table[:salary]
    abs_salary = Arel::Nodes::NamedFunction.new("abs", [salary_attr])

    devs = Developer.where(abs_salary.eq(80000)).merge(Developer.where(abs_salary.eq(9000)))
    assert_equal [developers(:poor_jamis)], devs.to_a

    devs = Developer.where(abs_salary.eq(80000)).rewhere(abs_salary.eq(9000))
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
      assert_queries_count(2) { assert posts.first.author }
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
    assert_equal true, Post.all.merge(Post.all.skip_query_cache!).skip_query_cache_value
  end

  def test_relation_merging_with_association
    assert_queries_count(2) do  # one for loading post, and another one merged query
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

  def test_merging_with_from_clause_on_different_class
    assert Comment.joins(:post).merge(Post.from("posts")).first
  end

  def test_merging_with_order_with_binds
    relation = Post.all.merge(Post.order([Arel.sql("title LIKE ?"), "%suffix"]))
    assert_equal ["title LIKE '%suffix'"], relation.order_values
  end

  def test_merging_with_order_without_binds
    relation = Post.all.merge(Post.order(Arel.sql("title LIKE '%?'")))
    assert_equal ["title LIKE '%?'"], relation.order_values
  end

  def test_merging_annotations_respects_merge_order
    assert_queries_match(%r{/\* foo \*/ /\* bar \*/}) do
      Post.annotate("foo").merge(Post.annotate("bar")).first
    end
    assert_queries_match(%r{/\* bar \*/ /\* foo \*/}) do
      Post.annotate("bar").merge(Post.annotate("foo")).first
    end
    assert_queries_match(%r{/\* foo \*/ /\* bar \*/ /\* baz \*/ /\* qux \*/}) do
      Post.annotate("foo").annotate("bar").merge(Post.annotate("baz").annotate("qux")).first
    end
  end

  def test_merging_duplicated_annotations
    posts = Post.annotate("foo")
    assert_queries_match(%r{FROM #{Regexp.escape(Post.quoted_table_name)} /\* foo \*/\z}) do
      posts.merge(posts).uniq!(:annotate).to_a
    end

    assert_queries_match(%r{FROM #{Regexp.escape(Post.quoted_table_name)} /\* foo \*/\z}) do
      posts.merge(posts).to_a
    end
    assert_queries_match(%r{FROM #{Regexp.escape(Post.quoted_table_name)} /\* foo \*/ /\* bar \*/\z}) do
      Post.annotate("foo").merge(Post.annotate("bar")).merge(posts).to_a
    end
    assert_queries_match(%r{FROM #{Regexp.escape(Post.quoted_table_name)} /\* bar \*/ /\* foo \*/\z}) do
      Post.annotate("bar").merge(Post.annotate("foo")).merge(posts).to_a
    end
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
      where.not("authors.name": "David").
      merge(Author.order(:name)).pluck("authors.name")

    assert_equal ["Bob", "Bob", "Mary"], posts_by_author_name

    posts_by_author_name = Post.limit(3).joins(:author).
      where.not("authors.name": "David").
      merge(Author.order("name")).pluck("authors.name")

    assert_equal ["Bob", "Bob", "Mary"], posts_by_author_name
  end

  test "merging order relations (using a hash argument)" do
    posts_by_author_name = Post.limit(4).joins(:author).
      where.not("authors.name": "David").
      merge(Author.order(name: :desc)).pluck("authors.name")

    assert_equal ["Mary", "Mary", "Mary", "Bob"], posts_by_author_name
  end

  test "relation merging (using a proc argument)" do
    dev = Developer.where(name: "Jamis").first

    comment_1 = dev.comments.create!(body: "I'm Jamis", post: Post.first)
    rating_1 = comment_1.ratings.create!

    comment_2 = dev.comments.create!(body: "I'm John", post: Post.first)
    comment_2.ratings.create!

    assert_equal dev.ratings, [rating_1]
  end

  if ActiveRecord::Base.lease_connection.supports_common_table_expressions?
    test "merging relation with common table expression" do
      posts_with_tags = Post.with(posts_with_tags: Post.where("tags_count > 0")).from("posts_with_tags AS posts")
      posts_with_comments = Post.where("legacy_comments_count > 0")
      relation = posts_with_comments.merge(posts_with_tags).order("posts.id")

      assert_equal [1, 2, 7], relation.pluck(:id)
    end

    test "merging multiple relations with common table expression" do
      posts_with_tags = Post.with(posts_with_tags: Post.where("tags_count > 0"))
      posts_with_comments = Post.with(posts_with_comments: Post.where("legacy_comments_count > 0"))
      relation = posts_with_comments.merge(posts_with_tags)
        .joins("JOIN posts_with_tags pwt ON pwt.id = posts.id JOIN posts_with_comments pwc ON pwc.id = posts.id").order("posts.id")

      assert_equal [1, 2, 7], relation.pluck(:id)
    end

    test "relation merger leaves to database to decide what to do when multiple CTEs with same alias are passed" do
      posts_with_tags = Post.with(popular_posts: Post.where("tags_count > 0"))
      posts_with_comments = Post.with(popular_posts: Post.where("legacy_comments_count > 0"))
      relation = posts_with_tags.merge(posts_with_comments).joins("JOIN popular_posts pp ON pp.id = posts.id")

      assert_raises ActiveRecord::StatementInvalid do
        relation.load
      end
    end
  end
end
