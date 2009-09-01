require "cases/helper"
require 'models/post'
require 'models/topic'
require 'models/comment'
require 'models/reply'
require 'models/author'
require 'models/entrant'
require 'models/developer'
require 'models/company'

class RelationTest < ActiveRecord::TestCase
  fixtures :authors, :topics, :entrants, :developers, :companies, :developers_projects, :accounts, :categories, :categorizations, :posts, :comments

  def test_finding_with_conditions
    assert_equal Author.find(:all, :conditions => "name = 'David'"), Author.all.conditions("name = 'David'").to_a
  end

  def test_finding_with_order
    topics = Topic.all.order('id')
    assert_equal 4, topics.size
    assert_equal topics(:first).title, topics.first.title
  end

  def test_finding_with_order_and_take
    entrants = Entrant.all.order("id ASC").limit(2).to_a

    assert_equal(2, entrants.size)
    assert_equal(entrants(:first).name, entrants.first.name)
  end

  def test_finding_with_order_limit_and_offset
    entrants = Entrant.all.order("id ASC").limit(2).offset(1)

    assert_equal(2, entrants.size)
    assert_equal(entrants(:second).name, entrants.first.name)

    entrants = Entrant.all.order("id ASC").limit(2).offset(2)
    assert_equal(1, entrants.size)
    assert_equal(entrants(:third).name, entrants.first.name)
  end

  def test_finding_with_group
    developers = Developer.all.group("salary").select("salary").to_a
    assert_equal 4, developers.size
    assert_equal 4, developers.map(&:salary).uniq.size
  end

  def test_finding_with_hash_conditions_on_joined_table
    firms = DependentFirm.all.joins(:account).conditions({:name => 'RailsCore', :accounts => { :credit_limit => 55..60 }}).to_a
    assert_equal 1, firms.size
    assert_equal companies(:rails_core), firms.first
  end

  def test_find_all_with_join
    developers_on_project_one = Developer.all.joins('LEFT JOIN developers_projects ON developers.id = developers_projects.developer_id').conditions('project_id=1').to_a

    assert_equal 3, developers_on_project_one.length
    developer_names = developers_on_project_one.map { |d| d.name }
    assert developer_names.include?('David')
    assert developer_names.include?('Jamis')
  end

  def test_find_on_hash_conditions
    assert_equal Topic.find(:all, :conditions => {:approved => false}), Topic.all.conditions({ :approved => false }).to_a
  end

  def test_joins_with_string_array
    person_with_reader_and_post = Post.all.joins([
        "INNER JOIN categorizations ON categorizations.post_id = posts.id",
        "INNER JOIN categories ON categories.id = categorizations.category_id AND categories.type = 'SpecialCategory'"
      ]
    ).to_a
    assert_equal 1, person_with_reader_and_post.size
  end

  def test_relation_responds_to_delegated_methods
    relation = Topic.all

    ["map", "uniq", "sort", "insert", "delete", "update"].each do |method|
      assert relation.respond_to?(method)
    end
  end

  def test_find_with_readonly_option
    Developer.all.each { |d| assert !d.readonly? }
    Developer.all.readonly.each { |d| assert d.readonly? }
    Developer.all(:readonly => true).each { |d| assert d.readonly? }
  end

  def test_eager_association_loading_of_stis_with_multiple_references
    authors = Author.all(:include => { :posts => { :special_comments => { :post => [ :special_comments, :very_special_comment ] } } }, :order => 'comments.body, very_special_comments_posts.body', :conditions => 'posts.id = 4').to_a
    assert_equal [authors(:david)], authors
    assert_no_queries do
      authors.first.posts.first.special_comments.first.post.special_comments
      authors.first.posts.first.special_comments.first.post.very_special_comment
    end
  end

  def test_find_with_included_associations
    assert_queries(2) do
      posts = Post.find(:all, :include => :comments)
      posts.first.comments.first
    end
    assert_queries(2) do
      posts = Post.all(:include => :comments).to_a
      posts.first.comments.first
    end
    assert_queries(2) do
      posts = Post.find(:all, :include => :author)
      posts.first.author
    end
    assert_queries(2) do
      posts = Post.all(:include => :author).to_a
      posts.first.author
    end
  end
end

