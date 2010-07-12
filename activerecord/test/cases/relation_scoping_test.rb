require "cases/helper"
require 'models/post'
require 'models/author'
require 'models/developer'
require 'models/project'
require 'models/comment'
require 'models/category'

class RelationScopingTest < ActiveRecord::TestCase
  fixtures :authors, :developers, :projects, :comments, :posts, :developers_projects

  def test_scoped_find
    Developer.where("name = 'David'").scoping do
      assert_nothing_raised { Developer.find(1) }
    end
  end

  def test_scoped_find_first
    developer = Developer.find(10)
    Developer.where("salary = 100000").scoping do
      assert_equal developer, Developer.order("name").first
    end
  end

  def test_scoped_find_last
    highest_salary = Developer.order("salary DESC").first

    Developer.order("salary").scoping do
      assert_equal highest_salary, Developer.last
    end
  end

  def test_scoped_find_last_preserves_scope
    lowest_salary  = Developer.first :order => "salary ASC"
    highest_salary = Developer.first :order => "salary DESC"

    Developer.order("salary").scoping do
      assert_equal highest_salary, Developer.last
      assert_equal lowest_salary, Developer.first
    end
  end

  def test_scoped_find_combines_and_sanitizes_conditions
    Developer.where("salary = 9000").scoping do
      assert_equal developers(:poor_jamis), Developer.where("name = 'Jamis'").first
    end
  end

  def test_scoped_find_all
    Developer.where("name = 'David'").scoping do
      assert_equal [developers(:david)], Developer.all
    end
  end

  def test_scoped_find_select
    Developer.select("id, name").scoping do
      developer = Developer.where("name = 'David'").first
      assert_equal "David", developer.name
      assert !developer.has_attribute?(:salary)
    end
  end

  def test_scope_select_concatenates
    Developer.select("id, name").scoping do
      developer = Developer.select('id, salary').where("name = 'David'").first
      assert_equal 80000, developer.salary
      assert developer.has_attribute?(:id)
      assert developer.has_attribute?(:name)
      assert developer.has_attribute?(:salary)
    end
  end

  def test_scoped_count
    Developer.where("name = 'David'").scoping do
      assert_equal 1, Developer.count
    end

    Developer.where('salary = 100000').scoping do
      assert_equal 8, Developer.count
      assert_equal 1, Developer.where("name LIKE 'fixture_1%'").count
    end
  end

  def test_scoped_find_include
    # with the include, will retrieve only developers for the given project
    scoped_developers = Developer.includes(:projects).scoping do
      Developer.where('projects.id = 2').all
    end
    assert scoped_developers.include?(developers(:david))
    assert !scoped_developers.include?(developers(:jamis))
    assert_equal 1, scoped_developers.size
  end

  def test_scoped_find_joins
    scoped_developers = Developer.joins('JOIN developers_projects ON id = developer_id').scoping do
      Developer.where('developers_projects.project_id = 2').all
    end

    assert scoped_developers.include?(developers(:david))
    assert !scoped_developers.include?(developers(:jamis))
    assert_equal 1, scoped_developers.size
    assert_equal developers(:david).attributes, scoped_developers.first.attributes
  end

  def test_scoped_create_with_where
    new_comment = VerySpecialComment.where(:post_id => 1).scoping do
      VerySpecialComment.create :body => "Wonderful world"
    end

    assert_equal 1, new_comment.post_id
    assert Post.find(1).comments.include?(new_comment)
  end

  def test_scoped_create_with_create_with
    new_comment = VerySpecialComment.create_with(:post_id => 1).scoping do
      VerySpecialComment.create :body => "Wonderful world"
    end

    assert_equal 1, new_comment.post_id
    assert Post.find(1).comments.include?(new_comment)
  end

  def test_scoped_create_with_create_with_has_higher_priority
    new_comment = VerySpecialComment.where(:post_id => 2).create_with(:post_id => 1).scoping do
      VerySpecialComment.create :body => "Wonderful world"
    end

    assert_equal 1, new_comment.post_id
    assert Post.find(1).comments.include?(new_comment)
  end

  def test_ensure_that_method_scoping_is_correctly_restored
    scoped_methods = Developer.send(:current_scoped_methods)

    begin
      Developer.where("name = 'Jamis'").scoping do
        raise "an exception"
      end
    rescue
    end

    assert_equal scoped_methods, Developer.send(:current_scoped_methods)
  end
end

class NestedRelationScopingTest < ActiveRecord::TestCase
  fixtures :authors, :developers, :projects, :comments, :posts

  def test_merge_options
    Developer.where('salary = 80000').scoping do
      Developer.limit(10).scoping do
        devs = Developer.scoped
        assert_equal '(salary = 80000)', devs.arel.send(:where_clauses).join(' AND ')
        assert_equal 10, devs.taken
      end
    end
  end

  def test_merge_inner_scope_has_priority
    Developer.limit(5).scoping do
      Developer.limit(10).scoping do
        assert_equal 10, Developer.count
      end
    end
  end

  def test_replace_options
    Developer.where(:name => 'David').scoping do
      Developer.unscoped do
        assert_equal 'Jamis', Developer.where(:name => 'Jamis').first[:name]
      end

      assert_equal 'David', Developer.first[:name]
    end
  end

  def test_three_level_nested_exclusive_scoped_find
    Developer.where("name = 'Jamis'").scoping do
      assert_equal 'Jamis', Developer.first.name

      Developer.unscoped.where("name = 'David'") do
        assert_equal 'David', Developer.first.name

        Developer.unscoped.where("name = 'Maiha'") do
          assert_equal nil, Developer.first
        end

        # ensure that scoping is restored
        assert_equal 'David', Developer.first.name
      end

      # ensure that scoping is restored
      assert_equal 'Jamis', Developer.first.name
    end
  end

  def test_nested_scoped_create
    comment = Comment.create_with(:post_id => 1).scoping do
      Comment.create_with(:post_id => 2).scoping do
        Comment.create :body => "Hey guys, nested scopes are broken. Please fix!"
      end
    end

    assert_equal 2, comment.post_id
  end

  def test_nested_exclusive_scope_for_create
    comment = Comment.create_with(:body => "Hey guys, nested scopes are broken. Please fix!").scoping do
      Comment.unscoped.create_with(:post_id => 1).scoping do
        assert Comment.new.body.blank?
        Comment.create :body => "Hey guys"
      end
    end

    assert_equal 1, comment.post_id
    assert_equal 'Hey guys', comment.body
  end
end

class HasManyScopingTest< ActiveRecord::TestCase
  fixtures :comments, :posts

  def setup
    @welcome = Post.find(1)
  end

  def test_forwarding_of_static_methods
    assert_equal 'a comment...', Comment.what_are_you
    assert_equal 'a comment...', @welcome.comments.what_are_you
  end

  def test_forwarding_to_scoped
    assert_equal 4, Comment.search_by_type('Comment').size
    assert_equal 2, @welcome.comments.search_by_type('Comment').size
  end

  def test_forwarding_to_dynamic_finders
    assert_equal 4, Comment.find_all_by_type('Comment').size
    assert_equal 2, @welcome.comments.find_all_by_type('Comment').size
  end

  def test_nested_scope_finder
    Comment.where('1=0').scoping do
      assert_equal 0, @welcome.comments.count
      assert_equal 'a comment...', @welcome.comments.what_are_you
    end

    Comment.where('1=1').scoping do
      assert_equal 2, @welcome.comments.count
      assert_equal 'a comment...', @welcome.comments.what_are_you
    end
  end
end

class HasAndBelongsToManyScopingTest< ActiveRecord::TestCase
  fixtures :posts, :categories, :categories_posts

  def setup
    @welcome = Post.find(1)
  end

  def test_forwarding_of_static_methods
    assert_equal 'a category...', Category.what_are_you
    assert_equal 'a category...', @welcome.categories.what_are_you
  end

  def test_forwarding_to_dynamic_finders
    assert_equal 4, Category.find_all_by_type('SpecialCategory').size
    assert_equal 0, @welcome.categories.find_all_by_type('SpecialCategory').size
    assert_equal 2, @welcome.categories.find_all_by_type('Category').size
  end

  def test_nested_scope_finder
    Category.where('1=0').scoping do
      assert_equal 0, @welcome.categories.count
      assert_equal 'a category...', @welcome.categories.what_are_you
    end

    Category.where('1=1').scoping do
      assert_equal 2, @welcome.categories.count
      assert_equal 'a category...', @welcome.categories.what_are_you
    end
  end
end

class DefaultScopingTest < ActiveRecord::TestCase
  fixtures :developers, :posts

  def test_default_scope
    expected = Developer.find(:all, :order => 'salary DESC').collect { |dev| dev.salary }
    received = DeveloperOrderedBySalary.find(:all).collect { |dev| dev.salary }
    assert_equal expected, received
  end

  def test_default_scope_is_unscoped_on_find
    assert_equal 1, DeveloperCalledDavid.count
    assert_equal 11, DeveloperCalledDavid.unscoped.count
  end

  def test_default_scope_is_unscoped_on_create
    assert_nil DeveloperCalledJamis.unscoped.create!.name
  end

  def test_default_scope_with_conditions_string
    assert_equal Developer.find_all_by_name('David').map(&:id).sort, DeveloperCalledDavid.find(:all).map(&:id).sort
    assert_equal nil, DeveloperCalledDavid.create!.name
  end

  def test_default_scope_with_conditions_hash
    assert_equal Developer.find_all_by_name('Jamis').map(&:id).sort, DeveloperCalledJamis.find(:all).map(&:id).sort
    assert_equal 'Jamis', DeveloperCalledJamis.create!.name
  end

  def test_default_scoping_with_threads
    2.times do
      Thread.new { assert_equal ['salary DESC'], DeveloperOrderedBySalary.scoped.order_values }.join
    end
  end

  def test_default_scoping_with_inheritance
    # Inherit a class having a default scope and define a new default scope
    klass = Class.new(DeveloperOrderedBySalary)
    klass.send :default_scope, :limit => 1 

    # Scopes added on children should append to parent scope
    assert_equal 1,               klass.scoped.limit_value
    assert_equal ['salary DESC'], klass.scoped.order_values

    # Parent should still have the original scope
    assert_nil DeveloperOrderedBySalary.scoped.limit_value
    assert_equal ['salary DESC'], DeveloperOrderedBySalary.scoped.order_values
  end

  def test_default_scope_called_twice_merges_conditions
    Developer.destroy_all
    Developer.create!(:name => "David", :salary => 80000)
    Developer.create!(:name => "David", :salary => 100000)
    Developer.create!(:name => "Brian", :salary => 100000)

    klass = Class.new(Developer)
    klass.__send__ :default_scope, :conditions => { :name => "David" }
    klass.__send__ :default_scope, :conditions => { :salary => 100000 }
    assert_equal 1,       klass.count
    assert_equal "David", klass.first.name
    assert_equal 100000,  klass.first.salary
  end
  def test_method_scope
    expected = Developer.find(:all, :order => 'name DESC').collect { |dev| dev.salary }
    received = DeveloperOrderedBySalary.all_ordered_by_name.collect { |dev| dev.salary }
    assert_equal expected, received
  end

  def test_nested_scope
    expected = Developer.find(:all, :order => 'name DESC').collect { |dev| dev.salary }
    received = DeveloperOrderedBySalary.send(:with_scope, :find => { :order => 'name DESC'}) do
      DeveloperOrderedBySalary.find(:all).collect { |dev| dev.salary }
    end
    assert_equal expected, received
  end

  def test_named_scope_overwrites_default
    expected = Developer.find(:all, :order => 'name DESC').collect { |dev| dev.name }
    received = DeveloperOrderedBySalary.by_name.find(:all).collect { |dev| dev.name }
    assert_equal expected, received
  end

  def test_named_scope_reorders_default
    expected = Developer.find(:all, :order => 'name DESC').collect { |dev| dev.name }
    received = DeveloperOrderedBySalary.reordered_by_name.find(:all).collect { |dev| dev.name }
    assert_equal expected, received
  end

  def test_nested_exclusive_scope
    expected = Developer.find(:all, :limit => 100).collect { |dev| dev.salary }
    received = DeveloperOrderedBySalary.send(:with_exclusive_scope, :find => { :limit => 100 }) do
      DeveloperOrderedBySalary.find(:all).collect { |dev| dev.salary }
    end
    assert_equal expected, received
  end

  def test_overwriting_default_scope
    expected = Developer.find(:all, :order => 'salary').collect { |dev| dev.salary }
    received = DeveloperOrderedBySalary.find(:all, :order => 'salary').collect { |dev| dev.salary }
    assert_equal expected, received
  end

  def test_default_scope_using_relation
    posts = PostWithComment.scoped
    assert_equal 2, posts.count
    assert_equal posts(:thinking), posts.first
  end

  def test_create_attribute_overwrites_default_scoping
    assert_equal 'David', PoorDeveloperCalledJamis.create!(:name => 'David').name
    assert_equal 200000, PoorDeveloperCalledJamis.create!(:name => 'David', :salary => 200000).salary
  end
 
  def test_create_attribute_overwrites_default_values
    assert_equal nil, PoorDeveloperCalledJamis.create!(:salary => nil).salary
    assert_equal 50000, PoorDeveloperCalledJamis.create!(:name => 'David').salary
  end
end