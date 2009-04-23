require "cases/helper"
require 'models/post'
require 'models/author'
require 'models/developer'
require 'models/project'
require 'models/comment'
require 'models/category'

class MethodScopingTest < ActiveRecord::TestCase
  fixtures :authors, :developers, :projects, :comments, :posts, :developers_projects

  def test_set_conditions
    Developer.with_scope(:find => { :conditions => 'just a test...' }) do
      assert_equal 'just a test...', Developer.send(:current_scoped_methods)[:find][:conditions]
    end
  end

  def test_scoped_find
    Developer.with_scope(:find => { :conditions => "name = 'David'" }) do
      assert_nothing_raised { Developer.find(1) }
    end
  end

  def test_scoped_find_first
    Developer.with_scope(:find => { :conditions => "salary = 100000" }) do
      assert_equal Developer.find(10), Developer.find(:first, :order => 'name')
    end
  end

  def test_scoped_find_last
    highest_salary = Developer.find(:first, :order => "salary DESC")

    Developer.with_scope(:find => { :order => "salary" }) do
      assert_equal highest_salary, Developer.last
    end
  end

  def test_scoped_find_last_preserves_scope
    lowest_salary = Developer.find(:first, :order => "salary ASC")
    highest_salary = Developer.find(:first, :order => "salary DESC")

    Developer.with_scope(:find => { :order => "salary" }) do
      assert_equal highest_salary, Developer.last
      assert_equal lowest_salary, Developer.first
    end
  end

  def test_scoped_find_combines_conditions
    Developer.with_scope(:find => { :conditions => "salary = 9000" }) do
      assert_equal developers(:poor_jamis), Developer.find(:first, :conditions => "name = 'Jamis'")
    end
  end

  def test_scoped_find_sanitizes_conditions
    Developer.with_scope(:find => { :conditions => ['salary = ?', 9000] }) do
      assert_equal developers(:poor_jamis), Developer.find(:first)
    end
  end

  def test_scoped_find_combines_and_sanitizes_conditions
    Developer.with_scope(:find => { :conditions => ['salary = ?', 9000] }) do
      assert_equal developers(:poor_jamis), Developer.find(:first, :conditions => ['name = ?', 'Jamis'])
    end
  end

  def test_scoped_find_all
    Developer.with_scope(:find => { :conditions => "name = 'David'" }) do
      assert_equal [developers(:david)], Developer.find(:all)
    end
  end

  def test_scoped_find_select
    Developer.with_scope(:find => { :select => "id, name" }) do
      developer = Developer.find(:first, :conditions => "name = 'David'")
      assert_equal "David", developer.name
      assert !developer.has_attribute?(:salary)
    end
  end

  def test_options_select_replaces_scope_select
    Developer.with_scope(:find => { :select => "id, name" }) do
      developer = Developer.find(:first, :select => 'id, salary', :conditions => "name = 'David'")
      assert_equal 80000, developer.salary
      assert !developer.has_attribute?(:name)
    end
  end

  def test_scoped_count
    Developer.with_scope(:find => { :conditions => "name = 'David'" }) do
      assert_equal 1, Developer.count
    end

    Developer.with_scope(:find => { :conditions => 'salary = 100000' }) do
      assert_equal 8, Developer.count
      assert_equal 1, Developer.count(:conditions => "name LIKE 'fixture_1%'")
    end
  end

  def test_scoped_find_include
    # with the include, will retrieve only developers for the given project
    scoped_developers = Developer.with_scope(:find => { :include => :projects }) do
      Developer.find(:all, :conditions => 'projects.id = 2')
    end
    assert scoped_developers.include?(developers(:david))
    assert !scoped_developers.include?(developers(:jamis))
    assert_equal 1, scoped_developers.size
  end

  def test_scoped_find_joins
    scoped_developers = Developer.with_scope(:find => { :joins => 'JOIN developers_projects ON id = developer_id' } ) do
      Developer.find(:all, :conditions => 'developers_projects.project_id = 2')
    end
    assert scoped_developers.include?(developers(:david))
    assert !scoped_developers.include?(developers(:jamis))
    assert_equal 1, scoped_developers.size
    assert_equal developers(:david).attributes, scoped_developers.first.attributes
  end

  def test_scoped_find_using_new_style_joins
    scoped_developers = Developer.with_scope(:find => { :joins => :projects }) do
      Developer.find(:all, :conditions => 'projects.id = 2')
    end
    assert scoped_developers.include?(developers(:david))
    assert !scoped_developers.include?(developers(:jamis))
    assert_equal 1, scoped_developers.size
    assert_equal developers(:david).attributes, scoped_developers.first.attributes
  end

  def test_scoped_find_merges_old_style_joins
    scoped_authors = Author.with_scope(:find => { :joins => 'INNER JOIN posts ON authors.id = posts.author_id ' }) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => 'INNER JOIN comments ON posts.id = comments.post_id', :conditions => 'comments.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_find_merges_new_style_joins
    scoped_authors = Author.with_scope(:find => { :joins => :posts }) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => :comments, :conditions => 'comments.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_find_merges_new_and_old_style_joins
    scoped_authors = Author.with_scope(:find => { :joins => :posts }) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => 'JOIN comments ON posts.id = comments.post_id', :conditions => 'comments.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_find_merges_string_array_style_and_string_style_joins
    scoped_authors = Author.with_scope(:find => { :joins => ["INNER JOIN posts ON posts.author_id = authors.id"]}) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => 'INNER JOIN comments ON posts.id = comments.post_id', :conditions => 'comments.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_find_merges_string_array_style_and_hash_style_joins
    scoped_authors = Author.with_scope(:find => { :joins => :posts}) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => ['INNER JOIN comments ON posts.id = comments.post_id'], :conditions => 'comments.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_find_merges_joins_and_eliminates_duplicate_string_joins
    scoped_authors = Author.with_scope(:find => { :joins => 'INNER JOIN posts ON posts.author_id = authors.id'}) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => ["INNER JOIN posts ON posts.author_id = authors.id", "INNER JOIN comments ON posts.id = comments.post_id"], :conditions => 'comments.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_find_strips_spaces_from_string_joins_and_eliminates_duplicate_string_joins
    scoped_authors = Author.with_scope(:find => { :joins => ' INNER JOIN posts ON posts.author_id = authors.id '}) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => ['INNER JOIN posts ON posts.author_id = authors.id'], :conditions => 'posts.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_count_include
    # with the include, will retrieve only developers for the given project
    Developer.with_scope(:find => { :include => :projects }) do
      assert_equal 1, Developer.count(:conditions => 'projects.id = 2')
    end
  end

  def test_scoped_create
    new_comment = nil

    VerySpecialComment.with_scope(:create => { :post_id => 1 }) do
      assert_equal({ :post_id => 1 }, VerySpecialComment.send(:current_scoped_methods)[:create])
      new_comment = VerySpecialComment.create :body => "Wonderful world"
    end

    assert Post.find(1).comments.include?(new_comment)
  end

  def test_immutable_scope
    options = { :conditions => "name = 'David'" }
    Developer.with_scope(:find => options) do
      assert_equal %w(David), Developer.find(:all).map { |d| d.name }
      options[:conditions] = "name != 'David'"
      assert_equal %w(David), Developer.find(:all).map { |d| d.name }
    end

    scope = { :find => { :conditions => "name = 'David'" }}
    Developer.with_scope(scope) do
      assert_equal %w(David), Developer.find(:all).map { |d| d.name }
      scope[:find][:conditions] = "name != 'David'"
      assert_equal %w(David), Developer.find(:all).map { |d| d.name }
    end
  end

  def test_scoped_with_duck_typing
    scoping = Struct.new(:method_scoping).new(:find => { :conditions => ["name = ?", 'David'] })
    Developer.with_scope(scoping) do
       assert_equal %w(David), Developer.find(:all).map { |d| d.name }
    end
  end

  def test_ensure_that_method_scoping_is_correctly_restored
    scoped_methods = Developer.instance_eval('current_scoped_methods')

    begin
      Developer.with_scope(:find => { :conditions => "name = 'Jamis'" }) do
        raise "an exception"
      end
    rescue
    end
    assert_equal scoped_methods, Developer.instance_eval('current_scoped_methods')
  end
end

class NestedScopingTest < ActiveRecord::TestCase
  fixtures :authors, :developers, :projects, :comments, :posts

  def test_merge_options
    Developer.with_scope(:find => { :conditions => 'salary = 80000' }) do
      Developer.with_scope(:find => { :limit => 10 }) do
        merged_option = Developer.instance_eval('current_scoped_methods')[:find]
        assert_equal({ :conditions => 'salary = 80000', :limit => 10 }, merged_option)
      end
    end
  end

  def test_merge_inner_scope_has_priority
    Developer.with_scope(:find => { :limit => 5 }) do
      Developer.with_scope(:find => { :limit => 10 }) do
        merged_option = Developer.instance_eval('current_scoped_methods')[:find]
        assert_equal({ :limit => 10 }, merged_option)
      end
    end
  end

  def test_replace_options
    Developer.with_scope(:find => { :conditions => "name = 'David'" }) do
      Developer.with_exclusive_scope(:find => { :conditions => "name = 'Jamis'" }) do
        assert_equal({:find => { :conditions => "name = 'Jamis'" }}, Developer.instance_eval('current_scoped_methods'))
        assert_equal({:find => { :conditions => "name = 'Jamis'" }}, Developer.send(:scoped_methods)[-1])
      end
    end
  end

  def test_append_conditions
    Developer.with_scope(:find => { :conditions => "name = 'David'" }) do
      Developer.with_scope(:find => { :conditions => 'salary = 80000' }) do
        appended_condition = Developer.instance_eval('current_scoped_methods')[:find][:conditions]
        assert_equal("(name = 'David') AND (salary = 80000)", appended_condition)
        assert_equal(1, Developer.count)
      end
      Developer.with_scope(:find => { :conditions => "name = 'Maiha'" }) do
        assert_equal(0, Developer.count)
      end
    end
  end

  def test_merge_and_append_options
    Developer.with_scope(:find => { :conditions => 'salary = 80000', :limit => 10 }) do
      Developer.with_scope(:find => { :conditions => "name = 'David'" }) do
        merged_option = Developer.instance_eval('current_scoped_methods')[:find]
        assert_equal({ :conditions => "(salary = 80000) AND (name = 'David')", :limit => 10 }, merged_option)
      end
    end
  end

  def test_nested_scoped_find
    Developer.with_scope(:find => { :conditions => "name = 'Jamis'" }) do
      Developer.with_exclusive_scope(:find => { :conditions => "name = 'David'" }) do
        assert_nothing_raised { Developer.find(1) }
        assert_equal('David', Developer.find(:first).name)
      end
      assert_equal('Jamis', Developer.find(:first).name)
    end
  end

  def test_nested_scoped_find_include
    Developer.with_scope(:find => { :include => :projects }) do
      Developer.with_scope(:find => { :conditions => "projects.id = 2" }) do
        assert_nothing_raised { Developer.find(1) }
        assert_equal('David', Developer.find(:first).name)
      end
    end
  end

  def test_nested_scoped_find_merged_include
    # :include's remain unique and don't "double up" when merging
    Developer.with_scope(:find => { :include => :projects, :conditions => "projects.id = 2" }) do
      Developer.with_scope(:find => { :include => :projects }) do
        assert_equal 1, Developer.instance_eval('current_scoped_methods')[:find][:include].length
        assert_equal('David', Developer.find(:first).name)
      end
    end

    # the nested scope doesn't remove the first :include
    Developer.with_scope(:find => { :include => :projects, :conditions => "projects.id = 2" }) do
      Developer.with_scope(:find => { :include => [] }) do
        assert_equal 1, Developer.instance_eval('current_scoped_methods')[:find][:include].length
        assert_equal('David', Developer.find(:first).name)
      end
    end

    # mixing array and symbol include's will merge correctly
    Developer.with_scope(:find => { :include => [:projects], :conditions => "projects.id = 2" }) do
      Developer.with_scope(:find => { :include => :projects }) do
        assert_equal 1, Developer.instance_eval('current_scoped_methods')[:find][:include].length
        assert_equal('David', Developer.find(:first).name)
      end
    end
  end

  def test_nested_scoped_find_replace_include
    Developer.with_scope(:find => { :include => :projects }) do
      Developer.with_exclusive_scope(:find => { :include => [] }) do
        assert_equal 0, Developer.instance_eval('current_scoped_methods')[:find][:include].length
      end
    end
  end

  def test_three_level_nested_exclusive_scoped_find
    Developer.with_scope(:find => { :conditions => "name = 'Jamis'" }) do
      assert_equal('Jamis', Developer.find(:first).name)

      Developer.with_exclusive_scope(:find => { :conditions => "name = 'David'" }) do
        assert_equal('David', Developer.find(:first).name)

        Developer.with_exclusive_scope(:find => { :conditions => "name = 'Maiha'" }) do
          assert_equal(nil, Developer.find(:first))
        end

        # ensure that scoping is restored
        assert_equal('David', Developer.find(:first).name)
      end

      # ensure that scoping is restored
      assert_equal('Jamis', Developer.find(:first).name)
    end
  end

  def test_merged_scoped_find
    poor_jamis = developers(:poor_jamis)
    Developer.with_scope(:find => { :conditions => "salary < 100000" }) do
      Developer.with_scope(:find => { :offset => 1, :order => 'id asc' }) do
        assert_sql /ORDER BY id asc / do
          assert_equal(poor_jamis, Developer.find(:first, :order => 'id asc'))
        end
      end
    end
  end

  def test_merged_scoped_find_sanitizes_conditions
    Developer.with_scope(:find => { :conditions => ["name = ?", 'David'] }) do
      Developer.with_scope(:find => { :conditions => ['salary = ?', 9000] }) do
        assert_raise(ActiveRecord::RecordNotFound) { developers(:poor_jamis) }
      end
    end
  end

  def test_nested_scoped_find_combines_and_sanitizes_conditions
    Developer.with_scope(:find => { :conditions => ["name = ?", 'David'] }) do
      Developer.with_exclusive_scope(:find => { :conditions => ['salary = ?', 9000] }) do
        assert_equal developers(:poor_jamis), Developer.find(:first)
        assert_equal developers(:poor_jamis), Developer.find(:first, :conditions => ['name = ?', 'Jamis'])
      end
    end
  end

  def test_merged_scoped_find_combines_and_sanitizes_conditions
    Developer.with_scope(:find => { :conditions => ["name = ?", 'David'] }) do
      Developer.with_scope(:find => { :conditions => ['salary > ?', 9000] }) do
        assert_equal %w(David), Developer.find(:all).map { |d| d.name }
      end
    end
  end

  def test_nested_scoped_create
    comment = nil
    Comment.with_scope(:create => { :post_id => 1}) do
      Comment.with_scope(:create => { :post_id => 2}) do
        assert_equal({ :post_id => 2 }, Comment.send(:current_scoped_methods)[:create])
        comment = Comment.create :body => "Hey guys, nested scopes are broken. Please fix!"
      end
    end
    assert_equal 2, comment.post_id
  end

  def test_nested_exclusive_scope_for_create
    comment = nil
    Comment.with_scope(:create => { :body => "Hey guys, nested scopes are broken. Please fix!" }) do
      Comment.with_exclusive_scope(:create => { :post_id => 1 }) do
        assert_equal({ :post_id => 1 }, Comment.send(:current_scoped_methods)[:create])
        comment = Comment.create :body => "Hey guys"
      end
    end
    assert_equal 1, comment.post_id
    assert_equal 'Hey guys', comment.body
  end

  def test_merged_scoped_find_on_blank_conditions
    [nil, " ", [], {}].each do |blank|
      Developer.with_scope(:find => {:conditions => blank}) do
        Developer.with_scope(:find => {:conditions => blank}) do
          assert_nothing_raised { Developer.find(:first) }
        end
      end
    end
  end

  def test_merged_scoped_find_on_blank_bind_conditions
    [ [""], ["",{}] ].each do |blank|
      Developer.with_scope(:find => {:conditions => blank}) do
        Developer.with_scope(:find => {:conditions => blank}) do
          assert_nothing_raised { Developer.find(:first) }
        end
      end
    end
  end

  def test_immutable_nested_scope
    options1 = { :conditions => "name = 'Jamis'" }
    options2 = { :conditions => "name = 'David'" }
    Developer.with_scope(:find => options1) do
      Developer.with_exclusive_scope(:find => options2) do
        assert_equal %w(David), Developer.find(:all).map { |d| d.name }
        options1[:conditions] = options2[:conditions] = nil
        assert_equal %w(David), Developer.find(:all).map { |d| d.name }
      end
    end
  end

  def test_immutable_merged_scope
    options1 = { :conditions => "name = 'Jamis'" }
    options2 = { :conditions => "salary > 10000" }
    Developer.with_scope(:find => options1) do
      Developer.with_scope(:find => options2) do
        assert_equal %w(Jamis), Developer.find(:all).map { |d| d.name }
        options1[:conditions] = options2[:conditions] = nil
        assert_equal %w(Jamis), Developer.find(:all).map { |d| d.name }
      end
    end
  end

  def test_ensure_that_method_scoping_is_correctly_restored
    Developer.with_scope(:find => { :conditions => "name = 'David'" }) do
      scoped_methods = Developer.instance_eval('current_scoped_methods')
      begin
        Developer.with_scope(:find => { :conditions => "name = 'Maiha'" }) do
          raise "an exception"
        end
      rescue
      end
      assert_equal scoped_methods, Developer.instance_eval('current_scoped_methods')
    end
  end

  def test_nested_scoped_find_merges_old_style_joins
    scoped_authors = Author.with_scope(:find => { :joins => 'INNER JOIN posts ON authors.id = posts.author_id' }) do
      Author.with_scope(:find => { :joins => 'INNER JOIN comments ON posts.id = comments.post_id' }) do
        Author.find(:all, :select => 'DISTINCT authors.*', :conditions => 'comments.id = 1')
      end
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_nested_scoped_find_merges_new_style_joins
    scoped_authors = Author.with_scope(:find => { :joins => :posts }) do
      Author.with_scope(:find => { :joins => :comments }) do
        Author.find(:all, :select => 'DISTINCT authors.*', :conditions => 'comments.id = 1')
      end
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_nested_scoped_find_merges_new_and_old_style_joins
    scoped_authors = Author.with_scope(:find => { :joins => :posts }) do
      Author.with_scope(:find => { :joins => 'INNER JOIN comments ON posts.id = comments.post_id' }) do
        Author.find(:all, :select => 'DISTINCT authors.*', :joins => '', :conditions => 'comments.id = 1')
      end
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
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

  def test_nested_scope
    Comment.with_scope(:find => { :conditions => '1=1' }) do
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

  def test_nested_scope
    Category.with_scope(:find => { :conditions => '1=1' }) do
      assert_equal 'a comment...', @welcome.comments.what_are_you
    end
  end
end

class DefaultScopingTest < ActiveRecord::TestCase
  fixtures :developers

  def test_default_scope
    expected = Developer.find(:all, :order => 'salary DESC').collect { |dev| dev.salary }
    received = DeveloperOrderedBySalary.find(:all).collect { |dev| dev.salary }
    assert_equal expected, received
  end

  def test_default_scope_with_conditions_string
    assert_equal Developer.find_all_by_name('David').map(&:id).sort, DeveloperCalledDavid.all.map(&:id).sort
    assert_equal nil, DeveloperCalledDavid.create!.name
  end

  def test_default_scope_with_conditions_hash
    assert_equal Developer.find_all_by_name('Jamis').map(&:id).sort, DeveloperCalledJamis.all.map(&:id).sort
    assert_equal 'Jamis', DeveloperCalledJamis.create!.name
  end

  def test_default_scoping_with_threads
    scope = [{ :create => {}, :find => { :order => 'salary DESC' } }]

    2.times do
      Thread.new { assert_equal scope, DeveloperOrderedBySalary.send(:scoped_methods) }.join
    end
  end

  def test_default_scoping_with_inheritance
    scope = [{ :create => {}, :find => { :order => 'salary DESC' } }]

    # Inherit a class having a default scope and define a new default scope
    klass = Class.new(DeveloperOrderedBySalary)
    klass.send :default_scope, {}

    # Scopes added on children should append to parent scope
    expected_klass_scope = [{ :create => {}, :find => { :order => 'salary DESC' }}, { :create => {}, :find => {} }]
    assert_equal expected_klass_scope, klass.send(:scoped_methods)

    # Parent should still have the original scope
    assert_equal scope, DeveloperOrderedBySalary.send(:scoped_methods)
  end

  def test_method_scope
    expected = Developer.find(:all, :order => 'name DESC').collect { |dev| dev.salary }
    received = DeveloperOrderedBySalary.all_ordered_by_name.collect { |dev| dev.salary }
    assert_equal expected, received
  end

  def test_nested_scope
    expected = Developer.find(:all, :order => 'name DESC').collect { |dev| dev.salary }
    received = DeveloperOrderedBySalary.with_scope(:find => { :order => 'name DESC'}) do
      DeveloperOrderedBySalary.find(:all).collect { |dev| dev.salary }
    end
    assert_equal expected, received
  end

  def test_named_scope_overwrites_default
    expected = Developer.find(:all, :order => 'name DESC').collect { |dev| dev.name }
    received = DeveloperOrderedBySalary.by_name.find(:all).collect { |dev| dev.name }
    assert_equal expected, received
  end

  def test_nested_exclusive_scope
    expected = Developer.find(:all, :limit => 100).collect { |dev| dev.salary }
    received = DeveloperOrderedBySalary.with_exclusive_scope(:find => { :limit => 100 }) do
      DeveloperOrderedBySalary.find(:all).collect { |dev| dev.salary }
    end
    assert_equal expected, received
  end

  def test_overwriting_default_scope
    expected = Developer.find(:all, :order => 'salary').collect { |dev| dev.salary }
    received = DeveloperOrderedBySalary.find(:all, :order => 'salary').collect { |dev| dev.salary }
    assert_equal expected, received
  end
end

=begin
# We disabled the scoping for has_one and belongs_to as we can't think of a proper use case

class BelongsToScopingTest< ActiveRecord::TestCase
  fixtures :comments, :posts

  def setup
    @greetings = Comment.find(1)
  end

  def test_forwarding_of_static_method
    assert_equal 'a post...', Post.what_are_you
    assert_equal 'a post...', @greetings.post.what_are_you
  end

  def test_forwarding_to_dynamic_finders
    assert_equal 4, Post.find_all_by_type('Post').size
    assert_equal 1, @greetings.post.find_all_by_type('Post').size
  end

end

class HasOneScopingTest< ActiveRecord::TestCase
  fixtures :comments, :posts

  def setup
    @sti_comments = Post.find(4)
  end

  def test_forwarding_of_static_methods
    assert_equal 'a comment...', Comment.what_are_you
    assert_equal 'a very special comment...', @sti_comments.very_special_comment.what_are_you
  end

  def test_forwarding_to_dynamic_finders
    assert_equal 1, Comment.find_all_by_type('VerySpecialComment').size
    assert_equal 1, @sti_comments.very_special_comment.find_all_by_type('VerySpecialComment').size
    assert_equal 0, @sti_comments.very_special_comment.find_all_by_type('Comment').size
  end

end

=end
