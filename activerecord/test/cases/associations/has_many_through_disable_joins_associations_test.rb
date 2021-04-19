# frozen_string_literal: true

require "cases/helper"

require "models/post"
require "models/author"
require "models/comment"
require "models/rating"
require "models/member"
require "models/member_type"

require "models/pirate"
require "models/treasure"

require "models/hotel"
require "models/department"

class HasManyThroughDisableJoinsAssociationsTest < ActiveRecord::TestCase
  fixtures :posts, :authors, :comments, :pirates

  def setup
    @author = authors(:mary)
    @post = @author.posts.create(title: "title", body: "body")
    @member_type = MemberType.create(name: "club")
    @member = Member.create(member_type: @member_type)
    @comment = @post.comments.create(body: "text", origin: @member)
    @post2 = @author.posts.create(title: "title", body: "body")
    @member2 = Member.create(member_type: @member_type)
    @comment2 = @post2.comments.create(body: "text", origin: @member2)
    @rating1 = @comment.ratings.create(value: 8)
    @rating2 = @comment.ratings.create(value: 9)
  end

  def test_counting_on_disable_joins_through
    assert_equal @author.comments.count, @author.no_joins_comments.count
    assert_queries(2) { @author.no_joins_comments.count }
    assert_queries(1) { @author.comments.count }
  end

  def test_counting_on_disable_joins_through_using_custom_foreign_key
    assert_equal @author.comments_with_foreign_key.count, @author.no_joins_comments_with_foreign_key.count
    assert_queries(2) { @author.no_joins_comments_with_foreign_key.count }
    assert_queries(1) { @author.comments_with_foreign_key.count }
  end

  def test_pluck_on_disable_joins_through
    assert_equal @author.comments.pluck(:id), @author.no_joins_comments.pluck(:id)
    assert_queries(2) { @author.no_joins_comments.pluck(:id) }
    assert_queries(1) { @author.comments.pluck(:id) }
  end

  def test_pluck_on_disable_joins_through_using_custom_foreign_key
    assert_equal @author.comments_with_foreign_key.pluck(:id), @author.no_joins_comments_with_foreign_key.pluck(:id)
    assert_queries(2) { @author.no_joins_comments_with_foreign_key.pluck(:id) }
    assert_queries(1) { @author.comments_with_foreign_key.pluck(:id) }
  end

  def test_fetching_on_disable_joins_through
    assert_equal @author.comments.first.id, @author.no_joins_comments.first.id
    assert_queries(2) { @author.no_joins_comments.first.id }
    assert_queries(1) { @author.comments.first.id }
  end

  def test_fetching_on_disable_joins_through_using_custom_foreign_key
    assert_equal @author.comments_with_foreign_key.first.id, @author.no_joins_comments_with_foreign_key.first.id
    assert_queries(2) { @author.no_joins_comments_with_foreign_key.first.id }
    assert_queries(1) { @author.comments_with_foreign_key.first.id }
  end

  def test_to_a_on_disable_joins_through
    assert_equal @author.comments.to_a, @author.no_joins_comments.to_a
    @author.reload
    assert_queries(2) { @author.no_joins_comments.to_a }
    assert_queries(1) { @author.comments.to_a }
  end

  def test_appending_on_disable_joins_through
    assert_difference(->() { @author.no_joins_comments.reload.size }) do
      @post.comments.create(body: "text")
    end
    assert_queries(2) { @author.no_joins_comments.reload.size }
    assert_queries(1) { @author.comments.reload.size }
  end

  def test_appending_on_disable_joins_through_using_custom_foreign_key
    assert_difference(->() { @author.no_joins_comments_with_foreign_key.reload.size }) do
      @post.comments.create(body: "text")
    end
    assert_queries(2) { @author.no_joins_comments_with_foreign_key.reload.size }
    assert_queries(1) { @author.comments_with_foreign_key.reload.size }
  end

  def test_empty_on_disable_joins_through
    empty_author = authors(:bob)
    assert_equal [], assert_queries(0) { empty_author.comments.all }
    assert_equal [], assert_queries(1) { empty_author.no_joins_comments.all }
  end

  def test_empty_on_disable_joins_through_using_custom_foreign_key
    empty_author = authors(:bob)
    assert_equal [], assert_queries(0) { empty_author.comments_with_foreign_key.all }
    assert_equal [], assert_queries(1) { empty_author.no_joins_comments_with_foreign_key.all }
  end

  def test_pluck_on_disable_joins_through_a_through
    rating_ids = Rating.where(comment: @comment).pluck(:id)
    assert_equal rating_ids, assert_queries(1) { @author.ratings.pluck(:id) }
    assert_equal rating_ids, assert_queries(3) { @author.no_joins_ratings.pluck(:id) }
  end

  def test_count_on_disable_joins_through_a_through
    ratings_count = Rating.where(comment: @comment).count
    assert_equal ratings_count, assert_queries(1) { @author.ratings.count }
    assert_equal ratings_count, assert_queries(3) { @author.no_joins_ratings.count }
  end

  def test_count_on_disable_joins_using_relation_with_scope
    assert_equal 2, assert_queries(1) { @author.good_ratings.count }
    assert_equal 2, assert_queries(3) { @author.no_joins_good_ratings.count }
  end

  def test_to_a_on_disable_joins_with_multiple_scopes
    assert_equal [@rating1, @rating2], assert_queries(1) { @author.good_ratings.to_a }
    assert_equal [@rating1, @rating2], assert_queries(3) { @author.no_joins_good_ratings.to_a }
  end

  def test_preloading_has_many_through_disable_joins
    assert_queries(3) { Author.all.preload(:good_ratings).map(&:good_ratings) }
    assert_queries(4) { Author.all.preload(:no_joins_good_ratings).map(&:good_ratings) }
  end

  def test_polymophic_disable_joins_through_counting
    assert_equal 2, assert_queries(1) { @author.ordered_members.count }
    assert_equal 2, assert_queries(3) { @author.no_joins_ordered_members.count }
  end

  def test_polymophic_disable_joins_through_ordering
    assert_equal [@member2, @member], assert_queries(1) { @author.ordered_members.to_a }
    assert_equal [@member2, @member], assert_queries(3) { @author.no_joins_ordered_members.to_a }
  end

  def test_polymorphic_disable_joins_through_reordering
    assert_equal [@member, @member2], assert_queries(1) { @author.ordered_members.reorder(id: :asc).to_a }
    assert_equal [@member, @member2], assert_queries(3) { @author.no_joins_ordered_members.reorder(id: :asc).to_a }
  end

  def test_polymorphic_disable_joins_through_ordered_scopes
    assert_equal [@member2, @member], assert_queries(1) { @author.ordered_members.unnamed.to_a }
    assert_equal [@member2, @member], assert_queries(3) { @author.no_joins_ordered_members.unnamed.to_a }
  end

  def test_polymorphic_disable_joins_through_ordered_chained_scopes
    member3 = Member.create(member_type: @member_type)
    member4 = Member.create(member_type: @member_type, name: "named")
    @post2.comments.create(body: "text", origin: member3)
    @post2.comments.create(body: "text", origin: member4)

    assert_equal [member3, @member2, @member], assert_queries(1) { @author.ordered_members.unnamed.with_member_type_id(@member_type.id).to_a }
    assert_equal [member3, @member2, @member], assert_queries(3) { @author.no_joins_ordered_members.unnamed.with_member_type_id(@member_type.id).to_a }
  end

  def test_polymorphic_disable_joins_through_ordered_scope_limits
    assert_equal [@member2], assert_queries(1) { @author.ordered_members.unnamed.limit(1).to_a }
    assert_equal [@member2], assert_queries(3) { @author.no_joins_ordered_members.unnamed.limit(1).to_a }
  end

  def test_polymorphic_disable_joins_through_ordered_scope_first
    assert_equal @member2, assert_queries(1) { @author.ordered_members.unnamed.first }
    assert_equal @member2, assert_queries(3) { @author.no_joins_ordered_members.unnamed.first }
  end

  def test_order_applied_in_double_join
    assert_equal [@member2, @member], assert_queries(1) { @author.members.to_a }
    assert_equal [@member2, @member], assert_queries(3) { @author.no_joins_members.to_a }
  end

  def test_first_and_scope_applied_in_double_join
    assert_equal @member2, assert_queries(1) { @author.members.unnamed.first }
    assert_equal @member2, assert_queries(3) { @author.no_joins_members.unnamed.first }
  end

  def test_first_and_scope_in_double_join_applies_order_in_memory
    disable_joins_sql = capture_sql { @author.no_joins_members.unnamed.first }
    assert_no_match(/ORDER BY/, disable_joins_sql.last)
  end

  def test_limit_and_scope_applied_in_double_join
    assert_equal [@member2], assert_queries(1) { @author.members.unnamed.limit(1).to_a }
    assert_equal [@member2], assert_queries(3) { @author.no_joins_members.unnamed.limit(1) }
  end

  def test_limit_and_scope_in_double_join_applies_limit_in_memory
    disable_joins_sql = capture_sql { @author.no_joins_members.unnamed.first }
    assert_no_match(/LIMIT 1/, disable_joins_sql.last)
  end
end
