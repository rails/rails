require 'abstract_unit'
require 'fixtures/post'
require 'fixtures/comment'
require 'fixtures/author'
require 'fixtures/category'
require 'fixtures/categorization'

class InnerJoinAssociationTest < Test::Unit::TestCase
  fixtures :authors, :posts, :comments, :categories, :categories_posts, :categorizations

  def test_construct_finder_sql_creates_inner_joins
    sql = Author.send(:construct_finder_sql, :joins => :posts)
    assert_match /INNER JOIN `?posts`? ON `?posts`?.author_id = authors.id/, sql
  end
  
  def test_construct_finder_sql_cascades_inner_joins
    sql = Author.send(:construct_finder_sql, :joins => {:posts => :comments})
    assert_match /INNER JOIN `?posts`? ON `?posts`?.author_id = authors.id/, sql
    assert_match /INNER JOIN `?comments`? ON `?comments`?.post_id = posts.id/, sql
  end
  
  def test_construct_finder_sql_inner_joins_through_associations
    sql = Author.send(:construct_finder_sql, :joins => :categorized_posts)
    assert_match /INNER JOIN `?categorizations`?.*INNER JOIN `?posts`?/, sql
  end
  
  def test_construct_finder_sql_applies_association_conditions
    sql = Author.send(:construct_finder_sql, :joins => :categories_like_general, :conditions => "TERMINATING_MARKER")
    assert_match /INNER JOIN `?categories`? ON.*AND.*`?General`?.*TERMINATING_MARKER/, sql
  end

  def test_construct_finder_sql_unpacks_nested_joins
    sql = Author.send(:construct_finder_sql, :joins => {:posts => [[:comments]]})
    assert_no_match /inner join.*inner join.*inner join/i, sql, "only two join clauses should be present"
    assert_match /INNER JOIN `?posts`? ON `?posts`?.author_id = authors.id/, sql
    assert_match /INNER JOIN `?comments`? ON `?comments`?.post_id = `?posts`?.id/, sql
  end

  def test_construct_finder_sql_ignores_empty_joins_hash
    sql = Author.send(:construct_finder_sql, :joins => {})
    assert_no_match /JOIN/i, sql
  end

  def test_construct_finder_sql_ignores_empty_joins_array
    sql = Author.send(:construct_finder_sql, :joins => [])
    assert_no_match /JOIN/i, sql
  end

  def test_find_with_implicit_inner_joins_honors_readonly_without_select
    authors = Author.find(:all, :joins => :posts)
    assert !authors.empty?, "expected authors to be non-empty"
    assert authors.all? {|a| a.readonly? }, "expected all authors to be readonly"
  end
  
  def test_find_with_implicit_inner_joins_honors_readonly_with_select
    authors = Author.find(:all, :select => 'authors.*', :joins => :posts)
    assert !authors.empty?, "expected authors to be non-empty"
    assert authors.all? {|a| !a.readonly? }, "expected no authors to be readonly"
  end

  def test_find_with_implicit_inner_joins_honors_readonly_false
    authors = Author.find(:all, :joins => :posts, :readonly => false)
    assert !authors.empty?, "expected authors to be non-empty"
    assert authors.all? {|a| !a.readonly? }, "expected no authors to be readonly"
  end

  def test_find_with_implicit_inner_joins_does_not_set_associations
    authors = Author.find(:all, :select => 'authors.*', :joins => :posts)
    assert !authors.empty?, "expected authors to be non-empty"
    assert authors.all? {|a| !a.send(:instance_variables).include?("@posts")}, "expected no authors to have the @posts association loaded"
  end
  
  def test_count_honors_implicit_inner_joins
    real_count = Author.find(:all).sum{|a| a.posts.count }
    assert_equal real_count, Author.count(:joins => :posts), "plain inner join count should match the number of referenced posts records"
  end

  def test_calculate_honors_implicit_inner_joins
    real_count = Author.find(:all).sum{|a| a.posts.count }
    assert_equal real_count, Author.calculate(:count, 'authors.id', :joins => :posts), "plain inner join count should match the number of referenced posts records"
  end

  def test_calculate_honors_implicit_inner_joins_and_distinct_and_conditions
    real_count = Author.find(:all).select {|a| a.posts.any? {|p| p.title =~ /^Welcome/} }.length
    authors_with_welcoming_post_titles = Author.calculate(:count, 'authors.id', :joins => :posts, :distinct => true, :conditions => "posts.title like 'Welcome%'")
    assert_equal real_count, authors_with_welcoming_post_titles, "inner join and conditions should have only returned authors posting titles starting with 'Welcome'"
  end
end
