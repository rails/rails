require "cases/helper"
require "models/post"
require "models/comment"
require "models/author"
require "models/essay"
require "models/category"
require "models/categorization"
require "models/person"
require "models/tagging"
require "models/tag"

class InnerJoinAssociationTest < ActiveRecord::TestCase
  fixtures :authors, :essays, :posts, :comments, :categories, :categories_posts, :categorizations,
           :taggings, :tags

  def test_construct_finder_sql_applies_aliases_tables_on_association_conditions
    result = Author.joins(:thinking_posts, :welcome_posts).to_a
    assert_equal authors(:david), result.first
  end

  def test_construct_finder_sql_does_not_table_name_collide_on_duplicate_associations
    assert_nothing_raised do
      sql = Person.joins(:agents => {:agents => :agents}).joins(:agents => {:agents => {:primary_contact => :agents}}).to_sql
      assert_match(/agents_people_4/i, sql)
    end
  end

  def test_construct_finder_sql_ignores_empty_joins_hash
    sql = Author.joins({}).to_sql
    assert_no_match(/JOIN/i, sql)
  end

  def test_construct_finder_sql_ignores_empty_joins_array
    sql = Author.joins([]).to_sql
    assert_no_match(/JOIN/i, sql)
  end

  def test_join_conditions_added_to_join_clause
    sql = Author.joins(:essays).to_sql
    assert_match(/writer_type.*?=.*?Author/i, sql)
    assert_no_match(/WHERE/i, sql)
  end

  def test_join_association_conditions_support_string_and_arel_expressions
    assert_equal 0, Author.joins(:welcome_posts_with_one_comment).count
    assert_equal 1, Author.joins(:welcome_posts_with_comments).count
  end

  def test_join_conditions_allow_nil_associations
    authors = Author.includes(:essays).where(:essays => {:id => nil})
    assert_equal 2, authors.count
  end

  def test_find_with_implicit_inner_joins_without_select_does_not_imply_readonly
    authors = Author.joins(:posts)
    assert_not authors.empty?, "expected authors to be non-empty"
    assert authors.none?(&:readonly?), "expected no authors to be readonly"
  end

  def test_find_with_implicit_inner_joins_honors_readonly_with_select
    authors = Author.joins(:posts).select("authors.*").to_a
    assert !authors.empty?, "expected authors to be non-empty"
    assert authors.all? {|a| !a.readonly? }, "expected no authors to be readonly"
  end

  def test_find_with_implicit_inner_joins_honors_readonly_false
    authors = Author.joins(:posts).readonly(false).to_a
    assert !authors.empty?, "expected authors to be non-empty"
    assert authors.all? {|a| !a.readonly? }, "expected no authors to be readonly"
  end

  def test_find_with_implicit_inner_joins_does_not_set_associations
    authors = Author.joins(:posts).select("authors.*").to_a
    assert !authors.empty?, "expected authors to be non-empty"
    assert authors.all? { |a| !a.instance_variable_defined?(:@posts) }, "expected no authors to have the @posts association loaded"
  end

  def test_count_honors_implicit_inner_joins
    real_count = Author.all.to_a.sum{|a| a.posts.count }
    assert_equal real_count, Author.joins(:posts).count, "plain inner join count should match the number of referenced posts records"
  end

  def test_calculate_honors_implicit_inner_joins
    real_count = Author.all.to_a.sum{|a| a.posts.count }
    assert_equal real_count, Author.joins(:posts).calculate(:count, "authors.id"), "plain inner join count should match the number of referenced posts records"
  end

  def test_calculate_honors_implicit_inner_joins_and_distinct_and_conditions
    real_count = Author.all.to_a.select {|a| a.posts.any? {|p| p.title.start_with?("Welcome")} }.length
    authors_with_welcoming_post_titles = Author.all.merge!(joins: :posts, where: "posts.title like 'Welcome%'").distinct.calculate(:count, "authors.id")
    assert_equal real_count, authors_with_welcoming_post_titles, "inner join and conditions should have only returned authors posting titles starting with 'Welcome'"
  end

  def test_find_with_sti_join
    scope = Post.joins(:special_comments).where(:id => posts(:sti_comments).id)

    # The join should match SpecialComment and its subclasses only
    assert scope.where("comments.type" => "Comment").empty?
    assert !scope.where("comments.type" => "SpecialComment").empty?
    assert !scope.where("comments.type" => "SubSpecialComment").empty?
  end

  def test_find_with_conditions_on_reflection
    assert !posts(:welcome).comments.empty?
    assert Post.joins(:nonexistent_comments).where(:id => posts(:welcome).id).empty? # [sic!]
  end

  def test_find_with_conditions_on_through_reflection
    assert !posts(:welcome).tags.empty?
    assert Post.joins(:misc_tags).where(:id => posts(:welcome).id).empty?
  end

  test "the default scope of the target is applied when joining associations" do
    author = Author.create! name: "Jon"
    author.categorizations.create!
    author.categorizations.create! special: true

    assert_equal [author], Author.where(id: author).joins(:special_categorizations)
  end

  test "the default scope of the target is correctly aliased when joining associations" do
    author = Author.create! name: "Jon"
    author.categories.create! name: "Not Special"
    author.special_categories.create! name: "Special"

    categories = author.categories.includes(:special_categorizations).references(:special_categorizations).to_a
    assert_equal 2, categories.size
  end

  test "the correct records are loaded when including an aliased association" do
    author = Author.create! name: "Jon"
    author.categories.create! name: "Not Special"
    author.special_categories.create! name: "Special"

    categories = author.categories.eager_load(:special_categorizations).order(:name).to_a
    assert_equal 0, categories.first.special_categorizations.size
    assert_equal 1, categories.second.special_categorizations.size
  end
end
