# frozen_string_literal: true

require "cases/helper"
require "models/post"
require "models/comment"
require "models/author"
require "models/categorization"
require "models/category"
require "models/company"
require "models/topic"
require "models/reply"
require "models/person"
require "models/vertex"
require "models/edge"

class CascadedEagerLoadingTest < ActiveRecord::TestCase
  fixtures :authors, :author_addresses, :mixins, :companies, :posts, :topics, :accounts, :comments,
           :categorizations, :people, :categories, :edges, :vertices

  def test_eager_association_loading_with_cascaded_two_levels
    authors = Author.all.merge!(includes: { posts: :comments }, order: "authors.id").to_a
    assert_equal 3, authors.size
    assert_equal 5, authors[0].posts.size
    assert_equal 3, authors[1].posts.size
    assert_equal 10, authors[0].posts.collect { |post| post.comments.size }.inject(0) { |sum, i| sum + i }
  end

  def test_eager_association_loading_with_cascaded_two_levels_and_one_level
    authors = Author.all.merge!(includes: [{ posts: :comments }, :categorizations], order: "authors.id").to_a
    assert_equal 3, authors.size
    assert_equal 5, authors[0].posts.size
    assert_equal 3, authors[1].posts.size
    assert_equal 10, authors[0].posts.collect { |post| post.comments.size }.inject(0) { |sum, i| sum + i }
    assert_equal 1, authors[0].categorizations.size
    assert_equal 2, authors[1].categorizations.size
  end

  def test_eager_association_loading_with_hmt_does_not_table_name_collide_when_joining_associations
    authors = Author.joins(:posts).eager_load(:comments).where(posts: { tags_count: 1 }).to_a
    assert_equal 3, assert_no_queries { authors.size }
    assert_equal 10, assert_no_queries { authors[0].comments.size }
  end

  def test_eager_association_loading_grafts_stashed_associations_to_correct_parent
    assert_equal people(:michael), Person.eager_load(primary_contact: :primary_contact).where("primary_contacts_people_2.first_name = ?", "Susan").order("people.id").first
  end

  def test_cascaded_eager_association_loading_with_join_for_count
    categories = Category.joins(:categorizations).includes([{ posts: :comments }, :authors])

    assert_equal 4, categories.count
    assert_equal 4, categories.to_a.count
    assert_equal 3, categories.distinct.count
    assert_equal 3, categories.to_a.uniq.size # Must uniq since instantiating with inner joins will get dupes
  end

  def test_cascaded_eager_association_loading_with_duplicated_includes
    categories = Category.includes(:categorizations).includes(categorizations: :author).where("categorizations.id is not null").references(:categorizations)
    assert_nothing_raised do
      assert_equal 3, categories.count
      assert_equal 3, categories.to_a.size
    end
  end

  def test_cascaded_eager_association_loading_with_twice_includes_edge_cases
    categories = Category.includes(categorizations: :author).includes(categorizations: :post).where("posts.id is not null").references(:posts)
    assert_nothing_raised do
      assert_equal 3, categories.count
      assert_equal 3, categories.to_a.size
    end
  end

  def test_eager_association_loading_with_join_for_count
    authors = Author.joins(:special_posts).includes([:posts, :categorizations])

    assert_nothing_raised { authors.count }
    assert_queries(1) { authors.to_a }
    assert_queries(2) { authors.each { |a| a.posts.first }.each { |a| a.categorizations.first } }
  end

  def test_eager_association_loading_with_cascaded_two_levels_with_two_has_many_associations
    authors = Author.all.merge!(includes: { posts: [:comments, :categorizations] }, order: "authors.id").to_a
    assert_equal 3, authors.size
    assert_equal 5, authors[0].posts.size
    assert_equal 3, authors[1].posts.size
    assert_equal 10, authors[0].posts.collect { |post| post.comments.size }.inject(0) { |sum, i| sum + i }
  end

  def test_eager_association_loading_with_cascaded_two_levels_and_self_table_reference
    authors = Author.all.merge!(includes: { posts: [:comments, :author] }, order: "authors.id").to_a
    assert_equal 3, authors.size
    assert_equal 5, authors[0].posts.size
    assert_equal authors(:david).name, authors[0].name
    assert_equal [authors(:david).name], authors[0].posts.collect { |post| post.author.name }.uniq
  end

  def test_eager_association_loading_with_cascaded_two_levels_with_condition
    authors = Author.all.merge!(includes: { posts: :comments }, where: "authors.id=1", order: "authors.id").to_a
    assert_equal 1, authors.size
    assert_equal 5, authors[0].posts.size
  end

  def test_eager_association_loading_with_cascaded_three_levels_by_ping_pong
    firms = Firm.all.merge!(includes: { account: { firm: :account } }, order: "companies.id").to_a
    assert_equal 2, firms.size
    assert_equal firms.first.account, firms.first.account.firm.account
    assert_equal companies(:first_firm).account, assert_no_queries { firms.first.account.firm.account }
    assert_equal companies(:first_firm).account.firm.account, assert_no_queries { firms.first.account.firm.account }
  end

  def test_eager_association_loading_with_has_many_sti
    topics = Topic.all.merge!(includes: :replies, order: "topics.id").to_a
    first, second, = topics(:first).replies.size, topics(:second).replies.size
    assert_queries(2) do
      assert_equal first, topics[0].replies.size
      assert_equal second, topics[1].replies.size
    end
  end

  def test_eager_association_loading_with_has_many_sti_and_subclasses
    silly = SillyReply.new(title: "gaga", content: "boo-boo", parent_id: 1)
    silly.parent_id = 1
    assert silly.save

    topics = Topic.all.merge!(includes: :replies, order: ["topics.id", "replies_topics.id"]).to_a
    assert_no_queries do
      assert_equal 2, topics[0].replies.size
      assert_equal 0, topics[1].replies.size
    end
  end

  def test_eager_association_loading_with_belongs_to_sti
    replies = Reply.all.merge!(includes: :topic, order: "topics.id").to_a
    assert_includes replies, topics(:second)
    assert_not_includes replies, topics(:first)
    assert_queries(1) { replies.each &:topic }
    assert_equal topics(:first), assert_no_queries { replies.first.topic }
  end

  def test_eager_association_loading_with_multiple_stis_and_order
    author = Author.all.merge!(includes: { posts: [ :special_comments, :very_special_comment ] }, order: ["authors.name", "comments.body", "very_special_comments_posts.body"], where: "posts.id = 4").first
    assert_equal authors(:david), author
    assert_no_queries do
      author.posts.first.special_comments
      author.posts.first.very_special_comment
    end
  end

  def test_eager_association_loading_of_stis_with_multiple_references
    authors = Author.all.merge!(includes: { posts: { special_comments: { post: [ :special_comments, :very_special_comment ] } } }, order: "comments.body, very_special_comments_posts.body", where: "posts.id = 4").to_a
    assert_equal [authors(:david)], authors
    assert_no_queries do
      authors.first.posts.first.special_comments.first.post.special_comments
      authors.first.posts.first.special_comments.first.post.very_special_comment
    end
  end

  def test_eager_association_loading_where_first_level_returns_nil
    authors = Author.all.merge!(includes: { post_about_thinking: :comments }, order: "authors.id DESC").to_a
    assert_equal [authors(:bob), authors(:mary), authors(:david)], authors

    assert_queries(2) do
      authors.each { |author| author.try(:post_about_thinking).try(:comments).try(:first) }
    end

    assert_no_queries do
      authors[2].post_about_thinking.comments.first
    end
  end

  def test_eager_association_loading_with_recursive_cascading_four_levels_has_many_through
    source = Vertex.all.merge!(includes: { sinks: { sinks: { sinks: :sinks } } }, order: "vertices.id").first
    assert_equal vertices(:vertex_4), assert_queries(6) { source.sinks.first.sinks.first.sinks.first }
  end

  def test_eager_association_loading_with_recursive_cascading_four_levels_has_and_belongs_to_many
    sink = Vertex.all.merge!(includes: { sources: { sources: { sources: :sources } } }, order: "vertices.id DESC").first
    assert_equal vertices(:vertex_1), assert_queries(8) { sink.sources.first.sources.first.sources.first.sources.first }
  end

  def test_eager_association_loading_with_cascaded_interdependent_one_level_and_two_levels
    authors_relation = Author.all.merge!(includes: [:comments, { posts: :categorizations }], order: "authors.id")
    authors = authors_relation.to_a
    assert_equal 3, authors.size
    assert_equal 10, authors[0].comments.size
    assert_equal 1, authors[1].comments.size
    assert_equal 5, authors[0].posts.size
    assert_equal 3, authors[1].posts.size
    assert_equal 3, authors[0].posts.collect { |post| post.categorizations.size }.inject(0) { |sum, i| sum + i }
  end
end
