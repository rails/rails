require "cases/helper"
require 'models/post'
require 'models/comment'
require 'models/author'
require 'models/category'
require 'models/categorization'
require 'models/tagging'

class InnerJoinAssociationTest < ActiveRecord::TestCase
  fixtures :authors, :posts, :comments, :categories, :categories_posts, :categorizations, :taggings, :tags

  def test_construct_finder_sql_applies_aliases_tables_on_association_conditions
    result = Author.joins(:thinking_posts, :welcome_posts).to_a
    assert_equal authors(:david), result.first
  end

  def test_construct_finder_sql_ignores_empty_joins_hash
    sql = Author.joins({}).to_sql
    assert_no_match(/JOIN/i, sql)
  end

  def test_construct_finder_sql_ignores_empty_joins_array
    sql = Author.joins([]).to_sql
    assert_no_match(/JOIN/i, sql)
  end

  def test_construct_finder_sql_on_polymorphic_through_includes_type
    # Posts has one tagging (polymorphic)
    # Author has one tagging through post.
    # Should be something like:
    # INNER JOIN taggings.taggable_id = posts.id AND taggings.taggable_type = 'Post'
    assert_match(/taggable_type/i, Author.joins(:taggings).to_sql.to_s)
  end

  def test_find_with_implicit_inner_joins_honors_readonly_without_select
    authors = Author.joins(:posts).to_a
    assert !authors.empty?, "expected authors to be non-empty"
    assert authors.all? {|a| a.readonly? }, "expected all authors to be readonly"
  end

  def test_find_with_implicit_inner_joins_honors_readonly_with_select
    authors = Author.joins(:posts).select('authors.*').to_a
    assert !authors.empty?, "expected authors to be non-empty"
    assert authors.all? {|a| !a.readonly? }, "expected no authors to be readonly"
  end

  def test_find_with_implicit_inner_joins_honors_readonly_false
    authors = Author.joins(:posts).readonly(false).to_a
    assert !authors.empty?, "expected authors to be non-empty"
    assert authors.all? {|a| !a.readonly? }, "expected no authors to be readonly"
  end

  def test_find_with_implicit_inner_joins_does_not_set_associations
    authors = Author.joins(:posts).select('authors.*')
    assert !authors.empty?, "expected authors to be non-empty"
    assert authors.all? {|a| !a.send(:instance_variable_names).include?("@posts")}, "expected no authors to have the @posts association loaded"
  end

  def test_count_honors_implicit_inner_joins
    real_count = Author.scoped.to_a.sum{|a| a.posts.count }
    assert_equal real_count, Author.count(:joins => :posts), "plain inner join count should match the number of referenced posts records"
  end

  def test_calculate_honors_implicit_inner_joins
    real_count = Author.scoped.to_a.sum{|a| a.posts.count }
    assert_equal real_count, Author.calculate(:count, 'authors.id', :joins => :posts), "plain inner join count should match the number of referenced posts records"
  end

  def test_calculate_honors_implicit_inner_joins_and_distinct_and_conditions
    real_count = Author.scoped.to_a.select {|a| a.posts.any? {|p| p.title =~ /^Welcome/} }.length
    authors_with_welcoming_post_titles = Author.calculate(:count, 'authors.id', :joins => :posts, :distinct => true, :conditions => "posts.title like 'Welcome%'")
    assert_equal real_count, authors_with_welcoming_post_titles, "inner join and conditions should have only returned authors posting titles starting with 'Welcome'"
  end

  def test_find_on_polymorphic_has_one_association
    # Author => has_one :tagging, :through => :posts
    # Post => has_one :tagging, :as => :taggable
    assert_equal Author.joins(:posts => :tagging).all, Author.joins(:tagging).all
  end
end
