require "cases/helper"
require 'models/tag'
require 'models/tagging'
require 'models/post'
require 'models/topic'
require 'models/comment'
require 'models/reply'
require 'models/author'
require 'models/comment'
require 'models/entrant'
require 'models/developer'
require 'models/company'

class RelationTest < ActiveRecord::TestCase
  fixtures :authors, :topics, :entrants, :developers, :companies, :developers_projects, :accounts, :categories, :categorizations, :posts, :comments,
    :taggings

  def test_scoped
    topics = Topic.scoped
    assert_kind_of ActiveRecord::Relation, topics
    assert_equal 4, topics.size
  end

  def test_scoped_all
    topics = Topic.scoped.all
    assert_kind_of Array, topics
    assert_no_queries { assert_equal 4, topics.size }
  end

  def test_loaded_all
    topics = Topic.scoped

    assert_queries(1) do
      2.times { assert_equal 4, topics.all.size }
    end

    assert topics.loaded?
  end

  def test_scoped_first
    topics = Topic.scoped

    assert_queries(1) do
      2.times { assert_equal "The First Topic", topics.first.title }
    end

    assert ! topics.loaded?
  end

  def test_loaded_first
    topics = Topic.scoped

    assert_queries(1) do
      topics.all # force load
      2.times { assert_equal "The First Topic", topics.first.title }
    end

    assert topics.loaded?
  end

  def test_reload
    topics = Topic.scoped

    assert_queries(1) do
      2.times { topics.to_a }
    end

    assert topics.loaded?

    topics.reload
    assert ! topics.loaded?

    assert_queries(1) { topics.to_a }
  end

  def test_finding_with_conditions
    assert_equal ["David"], Author.where(:name => 'David').map(&:name)
    assert_equal ['Mary'],  Author.where(["name = ?", 'Mary']).map(&:name)
    assert_equal ['Mary'],  Author.where("name = ?", 'Mary').map(&:name)
  end

  def test_finding_with_order
    topics = Topic.order('id')
    assert_equal 4, topics.size
    assert_equal topics(:first).title, topics.first.title
  end

  def test_finding_with_order_and_take
    entrants = Entrant.order("id ASC").limit(2).to_a

    assert_equal 2, entrants.size
    assert_equal entrants(:first).name, entrants.first.name
  end

  def test_finding_with_order_limit_and_offset
    entrants = Entrant.order("id ASC").limit(2).offset(1)

    assert_equal 2, entrants.size
    assert_equal entrants(:second).name, entrants.first.name

    entrants = Entrant.order("id ASC").limit(2).offset(2)
    assert_equal 1, entrants.size
    assert_equal entrants(:third).name, entrants.first.name
  end

  def test_finding_with_group
    developers = Developer.group("salary").select("salary").to_a
    assert_equal 4, developers.size
    assert_equal 4, developers.map(&:salary).uniq.size
  end

  def test_finding_with_hash_conditions_on_joined_table
    firms = DependentFirm.joins(:account).where({:name => 'RailsCore', :accounts => { :credit_limit => 55..60 }}).to_a
    assert_equal 1, firms.size
    assert_equal companies(:rails_core), firms.first
  end

  def test_find_all_with_join
    developers_on_project_one = Developer.joins('LEFT JOIN developers_projects ON developers.id = developers_projects.developer_id').
      where('project_id=1').to_a

    assert_equal 3, developers_on_project_one.length
    developer_names = developers_on_project_one.map { |d| d.name }
    assert developer_names.include?('David')
    assert developer_names.include?('Jamis')
  end

  def test_find_on_hash_conditions
    assert_equal Topic.find(:all, :conditions => {:approved => false}), Topic.where({ :approved => false }).to_a
  end

  def test_joins_with_string_array
    person_with_reader_and_post = Post.joins([
        "INNER JOIN categorizations ON categorizations.post_id = posts.id",
        "INNER JOIN categories ON categories.id = categorizations.category_id AND categories.type = 'SpecialCategory'"
      ]
    ).to_a
    assert_equal 1, person_with_reader_and_post.size
  end

  def test_scoped_responds_to_delegated_methods
    relation = Topic.scoped

    ["map", "uniq", "sort", "insert", "delete", "update"].each do |method|
      assert relation.respond_to?(method), "Topic.all should respond to #{method.inspect}"
    end
  end

  def test_find_with_readonly_option
    Developer.scoped.each { |d| assert !d.readonly? }
    Developer.scoped.readonly.each { |d| assert d.readonly? }
  end

  def test_eager_association_loading_of_stis_with_multiple_references
    authors = Author.eager_load(:posts => { :special_comments => { :post => [ :special_comments, :very_special_comment ] } }).
      order('comments.body, very_special_comments_posts.body').where('posts.id = 4').to_a

    assert_equal [authors(:david)], authors
    assert_no_queries do
      authors.first.posts.first.special_comments.first.post.special_comments
      authors.first.posts.first.special_comments.first.post.very_special_comment
    end
  end

  def test_find_with_included_associations
    assert_queries(2) do
      posts = Post.preload(:comments)
      assert posts.first.comments.first
    end

    assert_queries(2) do
      posts = Post.preload(:comments).to_a
      assert posts.first.comments.first
    end

    assert_queries(2) do
      posts = Post.preload(:author)
      assert posts.first.author
    end

    assert_queries(2) do
      posts = Post.preload(:author).to_a
      assert posts.first.author
    end

    assert_queries(3) do
      posts = Post.preload(:author, :comments).to_a
      assert posts.first.author
      assert posts.first.comments.first
    end
  end

  def test_default_scope_with_conditions_string
    assert_equal Developer.find_all_by_name('David').map(&:id).sort, DeveloperCalledDavid.scoped.map(&:id).sort
    assert_equal nil, DeveloperCalledDavid.create!.name
  end

  def test_default_scope_with_conditions_hash
    assert_equal Developer.find_all_by_name('Jamis').map(&:id).sort, DeveloperCalledJamis.scoped.map(&:id).sort
    assert_equal 'Jamis', DeveloperCalledJamis.create!.name
  end

  def test_default_scoping_finder_methods
    developers = DeveloperCalledDavid.order('id').map(&:id).sort
    assert_equal Developer.find_all_by_name('David').map(&:id).sort, developers
  end

  def test_loading_with_one_association
    posts = Post.preload(:comments)
    post = posts.find { |p| p.id == 1 }
    assert_equal 2, post.comments.size
    assert post.comments.include?(comments(:greetings))

    post = Post.where("posts.title = 'Welcome to the weblog'").preload(:comments).first
    assert_equal 2, post.comments.size
    assert post.comments.include?(comments(:greetings))

    posts = Post.preload(:last_comment)
    post = posts.find { |p| p.id == 1 }
    assert_equal Post.find(1).last_comment, post.last_comment
  end

  def test_loading_with_one_association_with_non_preload
    posts = Post.eager_load(:last_comment).order('comments.id DESC')
    post = posts.find { |p| p.id == 1 }
    assert_equal Post.find(1).last_comment, post.last_comment
  end

  def test_dynamic_find_by_attributes
    david = authors(:david)
    author = Author.preload(:taggings).find_by_id(david.id)
    expected_taggings = taggings(:welcome_general, :thinking_general)

    assert_no_queries do
      assert_equal expected_taggings, author.taggings.uniq.sort_by { |t| t.id }
    end

    authors = Author.scoped
    assert_equal david, authors.find_by_id_and_name(david.id, david.name)
    assert_equal david, authors.find_by_id_and_name!(david.id, david.name)
  end

  def test_dynamic_find_by_attributes_bang
    author = Author.scoped.find_by_id!(authors(:david).id)
    assert_equal "David", author.name

    assert_raises(ActiveRecord::RecordNotFound) { Author.scoped.find_by_id_and_name!('invalid', 'wt') }
  end

  def test_dynamic_find_all_by_attributes
    authors = Author.scoped

    davids = authors.find_all_by_name('David')
    assert_kind_of Array, davids
    assert_equal [authors(:david)], davids
  end

  def test_dynamic_find_or_initialize_by_attributes
    authors = Author.scoped

    lifo = authors.find_or_initialize_by_name('Lifo')
    assert_equal "Lifo", lifo.name
    assert lifo.new_record?

    assert_equal authors(:david), authors.find_or_initialize_by_name(:name => 'David')
  end

  def test_dynamic_find_or_create_by_attributes
    authors = Author.scoped

    lifo = authors.find_or_create_by_name('Lifo')
    assert_equal "Lifo", lifo.name
    assert ! lifo.new_record?

    assert_equal authors(:david), authors.find_or_create_by_name(:name => 'David')
  end

  def test_find_id
    authors = Author.scoped

    david = authors.find(authors(:david).id)
    assert_equal 'David', david.name

    assert_raises(ActiveRecord::RecordNotFound) { authors.where(:name => 'lifo').find('invalid') }
  end

  def test_find_ids
    authors = Author.order('id ASC')

    results = authors.find(authors(:david).id, authors(:mary).id)
    assert_kind_of Array, results
    assert_equal 2, results.size
    assert_equal 'David', results[0].name
    assert_equal 'Mary', results[1].name
    assert_equal results, authors.find([authors(:david).id, authors(:mary).id])

    assert_raises(ActiveRecord::RecordNotFound) { authors.where(:name => 'lifo').find(authors(:david).id, 'invalid') }
    assert_raises(ActiveRecord::RecordNotFound) { authors.find(['invalid', 'oops']) }
  end

end
