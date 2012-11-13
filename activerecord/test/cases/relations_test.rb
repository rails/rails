require "cases/helper"
require 'models/tag'
require 'models/tagging'
require 'models/post'
require 'models/topic'
require 'models/comment'
require 'models/author'
require 'models/entrant'
require 'models/developer'
require 'models/reply'
require 'models/company'
require 'models/bird'
require 'models/car'
require 'models/engine'
require 'models/tyre'
require 'models/minivan'


class RelationTest < ActiveRecord::TestCase
  fixtures :authors, :topics, :entrants, :developers, :companies, :developers_projects, :accounts, :categories, :categorizations, :posts, :comments,
    :tags, :taggings, :cars, :minivans

  def test_do_not_double_quote_string_id
    van = Minivan.last
    assert van
    assert_equal van.id, Minivan.where(:minivan_id => van).to_a.first.minivan_id
  end

  def test_do_not_double_quote_string_id_with_array
    van = Minivan.last
    assert van
    assert_equal van, Minivan.where(:minivan_id => [van]).to_a.first
  end

  def test_bind_values
    relation = Post.all
    assert_equal [], relation.bind_values

    relation2 = relation.bind 'foo'
    assert_equal %w{ foo }, relation2.bind_values
    assert_equal [], relation.bind_values
  end

  def test_two_scopes_with_includes_should_not_drop_any_include
    car = Car.incl_engines.incl_tyres.first
    assert_no_queries { car.tyres.length }
    assert_no_queries { car.engines.length }
  end

  def test_dynamic_finder
    x = Post.where('author_id = ?', 1)
    assert x.klass.respond_to?(:find_by_id), '@klass should handle dynamic finders'
  end

  def test_multivalue_where
    posts = Post.where('author_id = ? AND id = ?', 1, 1)
    assert_equal 1, posts.to_a.size
  end

  def test_scoped
    topics = Topic.all
    assert_kind_of ActiveRecord::Relation, topics
    assert_equal 4, topics.size
  end

  def test_to_json
    assert_nothing_raised  { Bird.all.to_json }
    assert_nothing_raised  { Bird.all.to_a.to_json }
  end

  def test_to_yaml
    assert_nothing_raised  { Bird.all.to_yaml }
    assert_nothing_raised  { Bird.all.to_a.to_yaml }
  end

  def test_to_xml
    assert_nothing_raised  { Bird.all.to_xml }
    assert_nothing_raised  { Bird.all.to_a.to_xml }
  end

  def test_scoped_all
    topics = Topic.all.to_a
    assert_kind_of Array, topics
    assert_no_queries { assert_equal 4, topics.size }
  end

  def test_loaded_all
    topics = Topic.all

    assert_queries(1) do
      2.times { assert_equal 4, topics.to_a.size }
    end

    assert topics.loaded?
  end

  def test_scoped_first
    topics = Topic.all.order('id ASC')

    assert_queries(1) do
      2.times { assert_equal "The First Topic", topics.first.title }
    end

    assert ! topics.loaded?
  end

  def test_loaded_first
    topics = Topic.all.order('id ASC')

    assert_queries(1) do
      topics.to_a # force load
      2.times { assert_equal "The First Topic", topics.first.title }
    end

    assert topics.loaded?
  end

  def test_reload
    topics = Topic.all

    assert_queries(1) do
      2.times { topics.to_a }
    end

    assert topics.loaded?

    original_size = topics.to_a.size
    Topic.create! :title => 'fake'

    assert_queries(1) { topics.reload }
    assert_equal original_size + 1, topics.size
    assert topics.loaded?
  end

  def test_finding_with_subquery
    relation = Topic.where(:approved => true)
    assert_equal relation.to_a, Topic.select('*').from(relation).to_a
    assert_equal relation.to_a, Topic.select('subquery.*').from(relation).to_a
    assert_equal relation.to_a, Topic.select('a.*').from(relation, :a).to_a
  end

  def test_finding_with_conditions
    assert_equal ["David"], Author.where(:name => 'David').map(&:name)
    assert_equal ['Mary'],  Author.where(["name = ?", 'Mary']).map(&:name)
    assert_equal ['Mary'],  Author.where("name = ?", 'Mary').map(&:name)
  end

  def test_finding_with_order
    topics = Topic.order('id')
    assert_equal 4, topics.to_a.size
    assert_equal topics(:first).title, topics.first.title
  end


  def test_finding_with_arel_order
    topics = Topic.order(Topic.arel_table[:id].asc)
    assert_equal 4, topics.to_a.size
    assert_equal topics(:first).title, topics.first.title
  end
  
  def test_finding_with_assoc_order
    topics = Topic.order(:id => :desc)
    assert_equal 4, topics.to_a.size
    assert_equal topics(:fourth).title, topics.first.title
  end
  
  def test_finding_with_reverted_assoc_order
    topics = Topic.order(:id => :asc).reverse_order
    assert_equal 4, topics.to_a.size
    assert_equal topics(:fourth).title, topics.first.title
  end
  
  def test_raising_exception_on_invalid_hash_params
    assert_raise(ArgumentError) { Topic.order(:name, "id DESC", :id => :DeSc) }
  end

  def test_finding_last_with_arel_order
    topics = Topic.order(Topic.arel_table[:id].asc)
    assert_equal topics(:fourth).title, topics.last.title
  end

  def test_finding_with_order_concatenated
    topics = Topic.order('title').order('author_name')
    assert_equal 4, topics.to_a.size
    assert_equal topics(:fourth).title, topics.first.title
  end

  def test_finding_with_reorder
    topics = Topic.order('author_name').order('title').reorder('id').to_a
    topics_titles = topics.map{ |t| t.title }
    assert_equal ['The First Topic', 'The Second Topic of the day', 'The Third Topic of the day', 'The Fourth Topic of the day'], topics_titles
  end

  def test_finding_with_order_and_take
    entrants = Entrant.order("id ASC").limit(2).to_a

    assert_equal 2, entrants.size
    assert_equal entrants(:first).name, entrants.first.name
  end

  def test_finding_with_cross_table_order_and_limit
    tags = Tag.includes(:taggings).
              order("tags.name asc", "taggings.taggable_id asc", "REPLACE('abc', taggings.taggable_type, taggings.taggable_type)").
              limit(1).to_a
    assert_equal 1, tags.length
  end

  def test_finding_with_complex_order_and_limit
    tags = Tag.includes(:taggings).references(:taggings).order("REPLACE('abc', taggings.taggable_type, taggings.taggable_type)").limit(1).to_a
    assert_equal 1, tags.length
  end

  def test_finding_with_complex_order
    tags = Tag.includes(:taggings).references(:taggings).order("REPLACE('abc', taggings.taggable_type, taggings.taggable_type)").to_a
    assert_equal 3, tags.length
  end

  def test_finding_with_order_limit_and_offset
    entrants = Entrant.order("id ASC").limit(2).offset(1)

    assert_equal 2, entrants.to_a.size
    assert_equal entrants(:second).name, entrants.first.name

    entrants = Entrant.order("id ASC").limit(2).offset(2)
    assert_equal 1, entrants.to_a.size
    assert_equal entrants(:third).name, entrants.first.name
  end

  def test_finding_with_group
    developers = Developer.group("salary").select("salary").to_a
    assert_equal 4, developers.size
    assert_equal 4, developers.map(&:salary).uniq.size
  end

  def test_select_with_block
    even_ids = Developer.all.select {|d| d.id % 2 == 0 }.map(&:id)
    assert_equal [2, 4, 6, 8, 10], even_ids.sort
  end

  def test_none
    assert_no_queries do
      assert_equal [], Developer.none
      assert_equal [], Developer.all.none
    end
  end

  def test_none_chainable
    assert_no_queries do
      assert_equal [], Developer.none.where(:name => 'David')
    end
  end

  def test_none_chainable_to_existing_scope_extension_method
    assert_no_queries do
      assert_equal 1, Topic.anonymous_extension.none.one
    end
  end

  def test_none_chained_to_methods_firing_queries_straight_to_db
    assert_no_queries do
      assert_equal [],    Developer.none.pluck(:id) # => uses select_all
      assert_equal 0,     Developer.none.delete_all
      assert_equal 0,     Developer.none.update_all(:name => 'David')
      assert_equal 0,     Developer.none.delete(1)
      assert_equal false, Developer.none.exists?(1)
    end
  end

  def test_null_relation_content_size_methods
    assert_no_queries do
      assert_equal 0,     Developer.none.size
      assert_equal 0,     Developer.none.count
      assert_equal true,  Developer.none.empty?
      assert_equal false, Developer.none.any?
      assert_equal false, Developer.none.many?
    end
  end

  def test_null_relation_calculations_methods
    assert_no_queries do
      assert_equal 0,     Developer.none.count
      assert_equal nil,   Developer.none.calculate(:average, 'salary')
    end
  end

  def test_null_relation_metadata_methods
    assert_equal "", Developer.none.to_sql
    assert_equal({}, Developer.none.where_values_hash)
  end

  def test_joins_with_nil_argument
    assert_nothing_raised { DependentFirm.joins(nil).first }
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
    assert_equal Topic.all.merge!(:where => {:approved => false}).to_a, Topic.where({ :approved => false }).to_a
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
    relation = Topic.all

    ["map", "uniq", "sort", "insert", "delete", "update"].each do |method|
      assert_respond_to relation, method, "Topic.all should respond to #{method.inspect}"
    end
  end

  def test_respond_to_delegates_to_relation
    relation = Topic.all
    fake_arel = Struct.new(:responds) {
      def respond_to? method, access = false
        responds << [method, access]
      end
    }.new []

    relation.extend(Module.new { attr_accessor :arel })
    relation.arel = fake_arel

    relation.respond_to?(:matching_attributes)
    assert_equal [:matching_attributes, false], fake_arel.responds.first

    fake_arel.responds = []
    relation.respond_to?(:matching_attributes, true)
    assert_equal [:matching_attributes, true], fake_arel.responds.first
  end

  def test_respond_to_dynamic_finders
    relation = Topic.all

    ["find_by_title", "find_by_title_and_author_name", "find_or_create_by_title", "find_or_initialize_by_title_and_author_name"].each do |method|
      assert_respond_to relation, method, "Topic.all should respond to #{method.inspect}"
    end
  end

  def test_respond_to_class_methods_and_scopes
    assert Topic.all.respond_to?(:by_lifo)
  end

  def test_find_with_readonly_option
    Developer.all.each { |d| assert !d.readonly? }
    Developer.all.readonly.each { |d| assert d.readonly? }
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

  def test_find_with_preloaded_associations
    assert_queries(2) do
      posts = Post.preload(:comments).order('posts.id')
      assert posts.first.comments.first
    end

    assert_queries(2) do
      posts = Post.preload(:comments).order('posts.id')
      assert posts.first.comments.first
    end

    assert_queries(2) do
      posts = Post.preload(:author).order('posts.id')
      assert posts.first.author
    end

    assert_queries(2) do
      posts = Post.preload(:author).order('posts.id')
      assert posts.first.author
    end

    assert_queries(3) do
      posts = Post.preload(:author, :comments).order('posts.id')
      assert posts.first.author
      assert posts.first.comments.first
    end
  end

  def test_find_with_included_associations
    assert_queries(2) do
      posts = Post.includes(:comments).order('posts.id')
      assert posts.first.comments.first
    end

    assert_queries(2) do
      posts = Post.all.includes(:comments).order('posts.id')
      assert posts.first.comments.first
    end

    assert_queries(2) do
      posts = Post.includes(:author).order('posts.id')
      assert posts.first.author
    end

    assert_queries(3) do
      posts = Post.includes(:author, :comments).order('posts.id')
      assert posts.first.author
      assert posts.first.comments.first
    end
  end

  def test_default_scope_with_conditions_string
    assert_equal Developer.where(name: 'David').map(&:id).sort, DeveloperCalledDavid.all.map(&:id).sort
    assert_nil DeveloperCalledDavid.create!.name
  end

  def test_default_scope_with_conditions_hash
    assert_equal Developer.where(name: 'Jamis').map(&:id).sort, DeveloperCalledJamis.all.map(&:id).sort
    assert_equal 'Jamis', DeveloperCalledJamis.create!.name
  end

  def test_default_scoping_finder_methods
    developers = DeveloperCalledDavid.order('id').map(&:id).sort
    assert_equal Developer.where(name: 'David').map(&:id).sort, developers
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

    authors = Author.all
    assert_equal david, authors.find_by_id_and_name(david.id, david.name)
    assert_equal david, authors.find_by_id_and_name!(david.id, david.name)
  end

  def test_dynamic_find_by_attributes_bang
    author = Author.all.find_by_id!(authors(:david).id)
    assert_equal "David", author.name

    assert_raises(ActiveRecord::RecordNotFound) { Author.all.find_by_id_and_name!(20, 'invalid') }
  end

  def test_find_id
    authors = Author.all

    david = authors.find(authors(:david).id)
    assert_equal 'David', david.name

    assert_raises(ActiveRecord::RecordNotFound) { authors.where(:name => 'lifo').find('42') }
  end

  def test_find_ids
    authors = Author.order('id ASC')

    results = authors.find(authors(:david).id, authors(:mary).id)
    assert_kind_of Array, results
    assert_equal 2, results.size
    assert_equal 'David', results[0].name
    assert_equal 'Mary', results[1].name
    assert_equal results, authors.find([authors(:david).id, authors(:mary).id])

    assert_raises(ActiveRecord::RecordNotFound) { authors.where(:name => 'lifo').find(authors(:david).id, '42') }
    assert_raises(ActiveRecord::RecordNotFound) { authors.find(['42', 43]) }
  end

  def test_find_in_empty_array
    authors = Author.all.where(:id => [])
    assert_blank authors.to_a
  end

  def test_where_with_ar_object
    author = Author.first
    authors = Author.all.where(:id => author)
    assert_equal 1, authors.to_a.length
  end

  def test_find_with_list_of_ar
    author = Author.first
    authors = Author.find([author])
    assert_equal author, authors.first
  end

  class Mary < Author; end

  def test_find_by_classname
    Author.create!(:name => Mary.name)
    assert_equal 1, Author.where(:name => Mary).size
  end

  def test_find_by_id_with_list_of_ar
    author = Author.first
    authors = Author.find_by_id([author])
    assert_equal author, authors
  end

  def test_find_all_using_where_twice_should_or_the_relation
    david = authors(:david)
    relation = Author.unscoped
    relation = relation.where(:name => david.name)
    relation = relation.where(:name => 'Santiago')
    relation = relation.where(:id => david.id)
    assert_equal [], relation.to_a
  end

  def test_multi_where_ands_queries
    relation = Author.unscoped
    david = authors(:david)
    sql = relation.where(:name => david.name).where(:name => 'Santiago').to_sql
    assert_match('AND', sql)
  end

  def test_find_all_with_multiple_should_use_and
    david = authors(:david)
    relation = [
      { :name => david.name },
      { :name => 'Santiago' },
      { :name => 'tenderlove' },
    ].inject(Author.unscoped) do |memo, param|
      memo.where(param)
    end
    assert_equal [], relation.to_a
  end

  def test_find_all_using_where_with_relation
    david = authors(:david)
    # switching the lines below would succeed in current rails
    # assert_queries(2) {
    assert_queries(1) {
      relation = Author.where(:id => Author.where(:id => david.id))
      assert_equal [david], relation.to_a
    }
  end

  def test_find_all_using_where_with_relation_and_alternate_primary_key
    cool_first = minivans(:cool_first)
    # switching the lines below would succeed in current rails
    # assert_queries(2) {
    assert_queries(1) {
      relation = Minivan.where(:minivan_id => Minivan.where(:name => cool_first.name))
      assert_equal [cool_first], relation.to_a
    }
  end

  def test_find_all_using_where_with_relation_does_not_alter_select_values
    david = authors(:david)

    subquery = Author.where(:id => david.id)

    assert_queries(1) {
      relation = Author.where(:id => subquery)
      assert_equal [david], relation.to_a
    }

    assert_equal 0, subquery.select_values.size
  end

  def test_find_all_using_where_with_relation_with_joins
    david = authors(:david)
    assert_queries(1) {
      relation = Author.where(:id => Author.joins(:posts).where(:id => david.id))
      assert_equal [david], relation.to_a
    }
  end


  def test_find_all_using_where_with_relation_with_select_to_build_subquery
    david = authors(:david)
    assert_queries(1) {
      relation = Author.where(:name => Author.where(:id => david.id).select(:name))
      assert_equal [david], relation.to_a
    }
  end

  def test_exists
    davids = Author.where(:name => 'David')
    assert davids.exists?
    assert davids.exists?(authors(:david).id)
    assert ! davids.exists?(authors(:mary).id)
    assert ! davids.exists?("42")
    assert ! davids.exists?(42)
    assert ! davids.exists?(davids.new)

    fake  = Author.where(:name => 'fake author')
    assert ! fake.exists?
    assert ! fake.exists?(authors(:david).id)
  end

  def test_last
    authors = Author.all
    assert_equal authors(:bob), authors.last
  end

  def test_destroy_all
    davids = Author.where(:name => 'David')

    # Force load
    assert_equal [authors(:david)], davids.to_a
    assert davids.loaded?

    assert_difference('Author.count', -1) { davids.destroy_all }

    assert_equal [], davids.to_a
    assert davids.loaded?
  end

  def test_delete_all
    davids = Author.where(:name => 'David')

    assert_difference('Author.count', -1) { davids.delete_all }
    assert ! davids.loaded?
  end

  def test_delete_all_loaded
    davids = Author.where(:name => 'David')

    # Force load
    assert_equal [authors(:david)], davids.to_a
    assert davids.loaded?

    assert_difference('Author.count', -1) { davids.delete_all }

    assert_equal [], davids.to_a
    assert davids.loaded?
  end

  def test_delete_all_limit_error
    assert_raises(ActiveRecord::ActiveRecordError) { Author.limit(10).delete_all }
  end

  def test_select_takes_a_variable_list_of_args
    david = developers(:david)

    developer = Developer.where(id: david.id).select(:name, :salary).first
    assert_equal david.name, developer.name
    assert_equal david.salary, developer.salary
  end

  def test_select_argument_error
    assert_raises(ArgumentError) { Developer.select }
  end

  def test_relation_merging
    devs = Developer.where("salary >= 80000").merge(Developer.limit(2)).merge(Developer.order('id ASC').where("id < 3"))
    assert_equal [developers(:david), developers(:jamis)], devs.to_a

    dev_with_count = Developer.limit(1).merge(Developer.order('id DESC')).merge(Developer.select('developers.*'))
    assert_equal [developers(:poor_jamis)], dev_with_count.to_a
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
      Arel::Nodes::NamedFunction.new('abs', [salary_attr]).eq(80000)
    ).merge(
      Developer.where(
        Arel::Nodes::NamedFunction.new('abs', [salary_attr]).eq(9000)
      )
    )
    assert_equal [developers(:poor_jamis)], devs.to_a
  end

  def test_relation_merging_with_eager_load
    relations = []
    relations << Post.order('comments.id DESC').merge(Post.eager_load(:last_comment)).merge(Post.all)
    relations << Post.eager_load(:last_comment).merge(Post.order('comments.id DESC')).merge(Post.all)

    relations.each do |posts|
      post = posts.find { |p| p.id == 1 }
      assert_equal Post.find(1).last_comment, post.last_comment
    end
  end

  def test_relation_merging_with_locks
    devs = Developer.lock.where("salary >= 80000").order("id DESC").merge(Developer.limit(2))
    assert_present devs.locked
  end

  def test_relation_merging_with_preload
    [Post.all.merge(Post.preload(:author)), Post.preload(:author).merge(Post.all)].each do |posts|
      assert_queries(2) { assert posts.first.author }
    end
  end

  def test_relation_merging_with_joins
    comments = Comment.joins(:post).where(:body => 'Thank you for the welcome').merge(Post.where(:body => 'Such a lovely day'))
    assert_equal 1, comments.count
  end

  def test_relation_merging_with_association
    assert_queries(2) do  # one for loading post, and another one merged query
      post = Post.where(:body => 'Such a lovely day').first
      comments = Comment.where(:body => 'Thank you for the welcome').merge(post.comments)
      assert_equal 1, comments.count
    end
  end

  def test_count
    posts = Post.all

    assert_equal 11, posts.count
    assert_equal 11, posts.count(:all)
    assert_equal 11, posts.count(:id)

    assert_equal 1, posts.where('comments_count > 1').count
    assert_equal 9, posts.where(:comments_count => 0).count
  end

  def test_count_with_distinct
    posts = Post.all

    assert_equal 3, posts.count(:comments_count, :distinct => true)
    assert_equal 11, posts.count(:comments_count, :distinct => false)

    assert_equal 3, posts.select(:comments_count).count(:distinct => true)
    assert_equal 11, posts.select(:comments_count).count(:distinct => false)
  end

  def test_count_explicit_columns
    Post.update_all(:comments_count => nil)
    posts = Post.all

    assert_equal [0], posts.select('comments_count').where('id is not null').group('id').order('id').count.values.uniq
    assert_equal 0, posts.where('id is not null').select('comments_count').count

    assert_equal 11, posts.select('comments_count').count('id')
    assert_equal 0, posts.select('comments_count').count
    assert_equal 0, posts.count(:comments_count)
    assert_equal 0, posts.count('comments_count')
  end

  def test_multiple_selects
    post = Post.all.select('comments_count').select('title').order("id ASC").first
    assert_equal "Welcome to the weblog", post.title
    assert_equal 2, post.comments_count
  end

  def test_size
    posts = Post.all

    assert_queries(1) { assert_equal 11, posts.size }
    assert ! posts.loaded?

    best_posts = posts.where(:comments_count => 0)
    best_posts.to_a # force load
    assert_no_queries { assert_equal 9, best_posts.size }
  end

  def test_size_with_limit
    posts = Post.limit(10)

    assert_queries(1) { assert_equal 10, posts.size }
    assert ! posts.loaded?

    best_posts = posts.where(:comments_count => 0)
    best_posts.to_a # force load
    assert_no_queries { assert_equal 9, best_posts.size }
  end

  def test_size_with_zero_limit
    posts = Post.limit(0)

    assert_no_queries { assert_equal 0, posts.size }
    assert ! posts.loaded?

    posts.to_a # force load
    assert_no_queries { assert_equal 0, posts.size }
  end

  def test_empty_with_zero_limit
    posts = Post.limit(0)

    assert_no_queries { assert_equal true, posts.empty? }
    assert ! posts.loaded?
  end

  def test_count_complex_chained_relations
    posts = Post.select('comments_count').where('id is not null').group("author_id").where("comments_count > 0")

    expected = { 1 => 2 }
    assert_equal expected, posts.count
  end

  def test_empty
    posts = Post.all

    assert_queries(1) { assert_equal false, posts.empty? }
    assert ! posts.loaded?

    no_posts = posts.where(:title => "")
    assert_queries(1) { assert_equal true, no_posts.empty? }
    assert ! no_posts.loaded?

    best_posts = posts.where(:comments_count => 0)
    best_posts.to_a # force load
    assert_no_queries { assert_equal false, best_posts.empty? }
  end

  def test_empty_complex_chained_relations
    posts = Post.select("comments_count").where("id is not null").group("author_id").where("comments_count > 0")

    assert_queries(1) { assert_equal false, posts.empty? }
    assert ! posts.loaded?

    no_posts = posts.where(:title => "")
    assert_queries(1) { assert_equal true, no_posts.empty? }
    assert ! no_posts.loaded?
  end

  def test_any
    posts = Post.all

    # This test was failing when run on its own (as opposed to running the entire suite).
    # The second line in the assert_queries block was causing visit_Arel_Attributes_Attribute
    # in Arel::Visitors::ToSql to trigger a SHOW TABLES query. Running that line here causes
    # the SHOW TABLES result to be cached so we don't have to do it again in the block.
    #
    # This is obviously a rubbish fix but it's the best I can come up with for now...
    posts.where(:id => nil).any?

    assert_queries(3) do
      assert posts.any? # Uses COUNT()
      assert ! posts.where(:id => nil).any?

      assert posts.any? {|p| p.id > 0 }
      assert ! posts.any? {|p| p.id <= 0 }
    end

    assert posts.loaded?
  end

  def test_many
    posts = Post.all

    assert_queries(2) do
      assert posts.many? # Uses COUNT()
      assert posts.many? {|p| p.id > 0 }
      assert ! posts.many? {|p| p.id < 2 }
    end

    assert posts.loaded?
  end

  def test_many_with_limits
    posts = Post.all

    assert posts.many?
    assert ! posts.limit(1).many?
  end

  def test_build
    posts = Post.all

    post = posts.new
    assert_kind_of Post, post
  end

  def test_scoped_build
    posts = Post.where(:title => 'You told a lie')

    post = posts.new
    assert_kind_of Post, post
    assert_equal 'You told a lie', post.title
  end

  def test_create
    birds = Bird.all

    sparrow = birds.create
    assert_kind_of Bird, sparrow
    assert !sparrow.persisted?

    hen = birds.where(:name => 'hen').create
    assert hen.persisted?
    assert_equal 'hen', hen.name
  end

  def test_create_bang
    birds = Bird.all

    assert_raises(ActiveRecord::RecordInvalid) { birds.create! }

    hen = birds.where(:name => 'hen').create!
    assert_kind_of Bird, hen
    assert hen.persisted?
    assert_equal 'hen', hen.name
  end

  def test_first_or_create
    parrot = Bird.where(:color => 'green').first_or_create(:name => 'parrot')
    assert_kind_of Bird, parrot
    assert parrot.persisted?
    assert_equal 'parrot', parrot.name
    assert_equal 'green', parrot.color

    same_parrot = Bird.where(:color => 'green').first_or_create(:name => 'parakeet')
    assert_kind_of Bird, same_parrot
    assert same_parrot.persisted?
    assert_equal parrot, same_parrot
  end

  def test_first_or_create_with_no_parameters
    parrot = Bird.where(:color => 'green').first_or_create
    assert_kind_of Bird, parrot
    assert !parrot.persisted?
    assert_equal 'green', parrot.color
  end

  def test_first_or_create_with_block
    parrot = Bird.where(:color => 'green').first_or_create { |bird| bird.name = 'parrot' }
    assert_kind_of Bird, parrot
    assert parrot.persisted?
    assert_equal 'green', parrot.color
    assert_equal 'parrot', parrot.name

    same_parrot = Bird.where(:color => 'green').first_or_create { |bird| bird.name = 'parakeet' }
    assert_equal parrot, same_parrot
  end

  def test_first_or_create_with_array
    several_green_birds = Bird.where(:color => 'green').first_or_create([{:name => 'parrot'}, {:name => 'parakeet'}])
    assert_kind_of Array, several_green_birds
    several_green_birds.each { |bird| assert bird.persisted? }

    same_parrot = Bird.where(:color => 'green').first_or_create([{:name => 'hummingbird'}, {:name => 'macaw'}])
    assert_kind_of Bird, same_parrot
    assert_equal several_green_birds.first, same_parrot
  end

  def test_first_or_create_bang_with_valid_options
    parrot = Bird.where(:color => 'green').first_or_create!(:name => 'parrot')
    assert_kind_of Bird, parrot
    assert parrot.persisted?
    assert_equal 'parrot', parrot.name
    assert_equal 'green', parrot.color

    same_parrot = Bird.where(:color => 'green').first_or_create!(:name => 'parakeet')
    assert_kind_of Bird, same_parrot
    assert same_parrot.persisted?
    assert_equal parrot, same_parrot
  end

  def test_first_or_create_bang_with_invalid_options
    assert_raises(ActiveRecord::RecordInvalid) { Bird.where(:color => 'green').first_or_create!(:pirate_id => 1) }
  end

  def test_first_or_create_bang_with_no_parameters
    assert_raises(ActiveRecord::RecordInvalid) { Bird.where(:color => 'green').first_or_create! }
  end

  def test_first_or_create_bang_with_valid_block
    parrot = Bird.where(:color => 'green').first_or_create! { |bird| bird.name = 'parrot' }
    assert_kind_of Bird, parrot
    assert parrot.persisted?
    assert_equal 'green', parrot.color
    assert_equal 'parrot', parrot.name

    same_parrot = Bird.where(:color => 'green').first_or_create! { |bird| bird.name = 'parakeet' }
    assert_equal parrot, same_parrot
  end

  def test_first_or_create_bang_with_invalid_block
    assert_raise(ActiveRecord::RecordInvalid) do
      Bird.where(:color => 'green').first_or_create! { |bird| bird.pirate_id = 1 }
    end
  end

  def test_first_or_create_with_valid_array
    several_green_birds = Bird.where(:color => 'green').first_or_create!([{:name => 'parrot'}, {:name => 'parakeet'}])
    assert_kind_of Array, several_green_birds
    several_green_birds.each { |bird| assert bird.persisted? }

    same_parrot = Bird.where(:color => 'green').first_or_create!([{:name => 'hummingbird'}, {:name => 'macaw'}])
    assert_kind_of Bird, same_parrot
    assert_equal several_green_birds.first, same_parrot
  end

  def test_first_or_create_with_invalid_array
    assert_raises(ActiveRecord::RecordInvalid) { Bird.where(:color => 'green').first_or_create!([ {:name => 'parrot'}, {:pirate_id => 1} ]) }
  end

  def test_first_or_initialize
    parrot = Bird.where(:color => 'green').first_or_initialize(:name => 'parrot')
    assert_kind_of Bird, parrot
    assert !parrot.persisted?
    assert parrot.valid?
    assert parrot.new_record?
    assert_equal 'parrot', parrot.name
    assert_equal 'green', parrot.color
  end

  def test_first_or_initialize_with_no_parameters
    parrot = Bird.where(:color => 'green').first_or_initialize
    assert_kind_of Bird, parrot
    assert !parrot.persisted?
    assert !parrot.valid?
    assert parrot.new_record?
    assert_equal 'green', parrot.color
  end

  def test_first_or_initialize_with_block
    parrot = Bird.where(:color => 'green').first_or_initialize { |bird| bird.name = 'parrot' }
    assert_kind_of Bird, parrot
    assert !parrot.persisted?
    assert parrot.valid?
    assert parrot.new_record?
    assert_equal 'green', parrot.color
    assert_equal 'parrot', parrot.name
  end

  def test_find_or_create_by
    assert_nil Bird.find_by(name: 'bob')

    bird = Bird.find_or_create_by(name: 'bob')
    assert bird.persisted?

    assert_equal bird, Bird.find_or_create_by(name: 'bob')
  end

  def test_find_or_create_by_with_create_with
    assert_nil Bird.find_by(name: 'bob')

    bird = Bird.create_with(color: 'green').find_or_create_by(name: 'bob')
    assert bird.persisted?
    assert_equal 'green', bird.color

    assert_equal bird, Bird.create_with(color: 'blue').find_or_create_by(name: 'bob')
  end

  def test_find_or_create_by!
    assert_raises(ActiveRecord::RecordInvalid) { Bird.find_or_create_by!(color: 'green') }
  end

  def test_find_or_initialize_by
    assert_nil Bird.find_by(name: 'bob')

    bird = Bird.find_or_initialize_by(name: 'bob')
    assert bird.new_record?
    bird.save!

    assert_equal bird, Bird.find_or_initialize_by(name: 'bob')
  end

  def test_explicit_create_scope
    hens = Bird.where(:name => 'hen')
    assert_equal 'hen', hens.new.name

    hens = hens.create_with(:name => 'cock')
    assert_equal 'cock', hens.new.name
  end

  def test_except
    relation = Post.where(:author_id => 1).order('id ASC').limit(1)
    assert_equal [posts(:welcome)], relation.to_a

    author_posts = relation.except(:order, :limit)
    assert_equal Post.where(:author_id => 1).to_a, author_posts.to_a

    all_posts = relation.except(:where, :order, :limit)
    assert_equal Post.all, all_posts
  end

  def test_only
    relation = Post.where(:author_id => 1).order('id ASC').limit(1)
    assert_equal [posts(:welcome)], relation.to_a

    author_posts = relation.only(:where)
    assert_equal Post.where(:author_id => 1).to_a, author_posts.to_a

    all_posts = relation.only(:limit)
    assert_equal Post.limit(1).to_a.first, all_posts.first
  end

  def test_anonymous_extension
    relation = Post.where(:author_id => 1).order('id ASC').extending do
      def author
        'lifo'
      end
    end

    assert_equal "lifo", relation.author
    assert_equal "lifo", relation.limit(1).author
  end

  def test_named_extension
    relation = Post.where(:author_id => 1).order('id ASC').extending(Post::NamedExtension)
    assert_equal "lifo", relation.author
    assert_equal "lifo", relation.limit(1).author
  end

  def test_order_by_relation_attribute
    assert_equal Post.order(Post.arel_table[:title]).to_a, Post.order("title").to_a
  end

  def test_default_scope_order_with_scope_order
    assert_equal 'honda', CoolCar.order_using_new_style.limit(1).first.name
    assert_equal 'honda', FastCar.order_using_new_style.limit(1).first.name
  end

  def test_order_using_scoping
    car1 = CoolCar.order('id DESC').scoping do
      CoolCar.all.merge!(:order => 'id asc').first
    end
    assert_equal 'honda', car1.name

    car2 = FastCar.order('id DESC').scoping do
      FastCar.all.merge!(:order => 'id asc').first
    end
    assert_equal 'honda', car2.name
  end

  def test_unscoped_block_style
    assert_equal 'honda', CoolCar.unscoped { CoolCar.order_using_new_style.limit(1).first.name}
    assert_equal 'honda', FastCar.unscoped { FastCar.order_using_new_style.limit(1).first.name}
  end

  def test_intersection_with_array
    relation = Author.where(:name => "David")
    rails_author = relation.first

    assert_equal [rails_author], [rails_author] & relation
    assert_equal [rails_author], relation & [rails_author]
  end

  def test_primary_key
    assert_equal "id", Post.all.primary_key
  end

  def test_eager_loading_with_conditions_on_joins
    scope = Post.includes(:comments)

    # This references the comments table, and so it should cause the comments to be eager
    # loaded via a JOIN, rather than by subsequent queries.
    scope = scope.joins(
      Post.arel_table.create_join(
        Post.arel_table,
        Post.arel_table.create_on(Comment.arel_table[:id].eq(3))
      )
    )

    assert_deprecated do
      assert scope.eager_loading?
    end
  end

  def test_ordering_with_extra_spaces
    assert_equal authors(:david), Author.order('id DESC , name DESC').last
  end

  def test_update_all_with_blank_argument
    assert_raises(ArgumentError) { Comment.update_all({}) }
  end

  def test_update_all_with_joins
    comments = Comment.joins(:post).where('posts.id' => posts(:welcome).id)
    count    = comments.count

    assert_equal count, comments.update_all(:post_id => posts(:thinking).id)
    assert_equal posts(:thinking), comments(:greetings).post
  end

  def test_update_all_with_joins_and_limit
    comments = Comment.joins(:post).where('posts.id' => posts(:welcome).id).limit(1)
    assert_equal 1, comments.update_all(:post_id => posts(:thinking).id)
  end

  def test_update_all_with_joins_and_limit_and_order
    comments = Comment.joins(:post).where('posts.id' => posts(:welcome).id).order('comments.id').limit(1)
    assert_equal 1, comments.update_all(:post_id => posts(:thinking).id)
    assert_equal posts(:thinking), comments(:greetings).post
    assert_equal posts(:welcome),  comments(:more_greetings).post
  end

  def test_update_all_with_joins_and_offset
    all_comments = Comment.joins(:post).where('posts.id' => posts(:welcome).id)
    count        = all_comments.count
    comments     = all_comments.offset(1)

    assert_equal count - 1, comments.update_all(:post_id => posts(:thinking).id)
  end

  def test_update_all_with_joins_and_offset_and_order
    all_comments = Comment.joins(:post).where('posts.id' => posts(:welcome).id).order('posts.id', 'comments.id')
    count        = all_comments.count
    comments     = all_comments.offset(1)

    assert_equal count - 1, comments.update_all(:post_id => posts(:thinking).id)
    assert_equal posts(:thinking), comments(:more_greetings).post
    assert_equal posts(:welcome),  comments(:greetings).post
  end

  def test_uniq
    tag1 = Tag.create(:name => 'Foo')
    tag2 = Tag.create(:name => 'Foo')

    query = Tag.select(:name).where(:id => [tag1.id, tag2.id])

    assert_equal ['Foo', 'Foo'], query.map(&:name)
    assert_sql(/DISTINCT/) do
      assert_equal ['Foo'], query.uniq.map(&:name)
    end
    assert_sql(/DISTINCT/) do
      assert_equal ['Foo'], query.uniq(true).map(&:name)
    end
    assert_equal ['Foo', 'Foo'], query.uniq(true).uniq(false).map(&:name)
  end

  def test_references_triggers_eager_loading
    scope = Post.includes(:comments)
    assert !scope.eager_loading?
    assert scope.references(:comments).eager_loading?
  end

  def test_references_doesnt_trigger_eager_loading_if_reference_not_included
    scope = Post.references(:comments)
    assert !scope.eager_loading?
  end

  def test_automatically_added_where_references
    scope = Post.where(:comments => { :body => "Bla" })
    assert_equal ['comments'], scope.references_values

    scope = Post.where('comments.body' => 'Bla')
    assert_equal ['comments'], scope.references_values
  end

  def test_automatically_added_having_references
    scope = Post.having(:comments => { :body => "Bla" })
    assert_equal ['comments'], scope.references_values

    scope = Post.having('comments.body' => 'Bla')
    assert_equal ['comments'], scope.references_values
  end

  def test_automatically_added_order_references
    scope = Post.order('comments.body')
    assert_equal ['comments'], scope.references_values

    scope = Post.order('comments.body', 'yaks.body')
    assert_equal ['comments', 'yaks'], scope.references_values

    # Don't infer yaks, let's not go down that road again...
    scope = Post.order('comments.body, yaks.body')
    assert_equal ['comments'], scope.references_values

    scope = Post.order('comments.body asc')
    assert_equal ['comments'], scope.references_values

    scope = Post.order('foo(comments.body)')
    assert_equal [], scope.references_values
  end

  def test_presence
    topics = Topic.all

    # the first query is triggered because there are no topics yet.
    assert_queries(1) { assert topics.present? }

    # checking if there are topics is used before you actually display them,
    # thus it shouldn't invoke an extra count query.
    assert_no_queries { assert topics.present? }
    assert_no_queries { assert !topics.blank? }

    # shows count of topics and loops after loading the query should not trigger extra queries either.
    assert_no_queries { topics.size }
    assert_no_queries { topics.length }
    assert_no_queries { topics.each }

    # count always trigger the COUNT query.
    assert_queries(1) { topics.count }

    assert topics.loaded?
  end

  test "find_by with hash conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.order(:id).find_by(author_id: 2)
  end

  test "find_by with non-hash conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.order(:id).find_by("author_id = 2")
  end

  test "find_by with multi-arg conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.order(:id).find_by('author_id = ?', 2)
  end

  test "find_by returns nil if the record is missing" do
    assert_equal nil, Post.all.find_by("1 = 0")
  end

  test "find_by doesn't have implicit ordering" do
    assert_sql(/^((?!ORDER).)*$/) { Post.find_by(author_id: 2) }
  end

  test "find_by! with hash conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.order(:id).find_by!(author_id: 2)
  end

  test "find_by! with non-hash conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.order(:id).find_by!("author_id = 2")
  end

  test "find_by! with multi-arg conditions returns the first matching record" do
    assert_equal posts(:eager_other), Post.order(:id).find_by!('author_id = ?', 2)
  end

  test "find_by! doesn't have implicit ordering" do
    assert_sql(/^((?!ORDER).)*$/) { Post.find_by!(author_id: 2) }
  end

  test "find_by! raises RecordNotFound if the record is missing" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Post.all.find_by!("1 = 0")
    end
  end

  test "loaded relations cannot be mutated by multi value methods" do
    relation = Post.all
    relation.to_a

    assert_raises(ActiveRecord::ImmutableRelation) do
      relation.where! 'foo'
    end
  end

  test "loaded relations cannot be mutated by single value methods" do
    relation = Post.all
    relation.to_a

    assert_raises(ActiveRecord::ImmutableRelation) do
      relation.limit! 5
    end
  end

  test "loaded relations cannot be mutated by merge!" do
    relation = Post.all
    relation.to_a

    assert_raises(ActiveRecord::ImmutableRelation) do
      relation.merge! where: 'foo'
    end
  end

  test "loaded relations cannot be mutated by extending!" do
    relation = Post.all
    relation.to_a

    assert_raises(ActiveRecord::ImmutableRelation) do
      relation.extending! Module.new
    end
  end

  test "relations show the records in #inspect" do
    relation = Post.limit(2)
    assert_equal "#<ActiveRecord::Relation [#{Post.limit(2).map(&:inspect).join(', ')}]>", relation.inspect
  end

  test "relations limit the records in #inspect at 10" do
    relation = Post.limit(11)
    assert_equal "#<ActiveRecord::Relation [#{Post.limit(10).map(&:inspect).join(', ')}, ...]>", relation.inspect
  end

  test "already-loaded relations don't perform a new query in #inspect" do
    relation = Post.limit(2)
    relation.to_a

    expected = "#<ActiveRecord::Relation [#{Post.limit(2).map(&:inspect).join(', ')}]>"

    assert_no_queries do
      assert_equal expected, relation.inspect
    end
  end

  test 'using a custom table affects the wheres' do
    table_alias = Post.arel_table.alias('omg_posts')

    relation = ActiveRecord::Relation.new Post, table_alias
    relation.where!(:foo => "bar")

    node = relation.arel.constraints.first.grep(Arel::Attributes::Attribute).first
    assert_equal table_alias, node.relation
  end

  test '#load' do
    relation = Post.all
    assert_queries(1) do
      assert_equal relation, relation.load
    end
    assert_no_queries { relation.to_a }
  end
end
