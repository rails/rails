# This file can be removed once with_exclusive_scope and with_scope are removed.
# All the tests were already ported to relation_scoping_test.rb when the new
# relation scoping API was added.

require "cases/helper"
require 'models/post'
require 'models/author'
require 'models/developer'
require 'models/project'
require 'models/comment'

class MethodScopingTest < ActiveRecord::TestCase
  fixtures :authors, :developers, :projects, :comments, :posts, :developers_projects

  def test_set_conditions
    Developer.send(:with_scope, :find => { :conditions => 'just a test...' }) do
      assert_match '(just a test...)', Developer.scoped.to_sql
    end
  end

  def test_scoped_find
    Developer.send(:with_scope, :find => { :conditions => "name = 'David'" }) do
      assert_nothing_raised { Developer.find(1) }
    end
  end

  def test_scoped_find_first
    Developer.send(:with_scope, :find => { :conditions => "salary = 100000" }) do
      assert_equal Developer.find(10), Developer.find(:first, :order => 'name')
    end
  end

  def test_scoped_find_last
    highest_salary = Developer.find(:first, :order => "salary DESC")

    Developer.send(:with_scope, :find => { :order => "salary" }) do
      assert_equal highest_salary, Developer.last
    end
  end

  def test_scoped_find_last_preserves_scope
    lowest_salary = Developer.find(:first, :order => "salary ASC")
    highest_salary = Developer.find(:first, :order => "salary DESC")

    Developer.send(:with_scope, :find => { :order => "salary" }) do
      assert_equal highest_salary, Developer.last
      assert_equal lowest_salary, Developer.first
    end
  end

  def test_scoped_find_combines_conditions
    Developer.send(:with_scope, :find => { :conditions => "salary = 9000" }) do
      assert_equal developers(:poor_jamis), Developer.find(:first, :conditions => "name = 'Jamis'")
    end
  end

  def test_scoped_find_sanitizes_conditions
    Developer.send(:with_scope, :find => { :conditions => ['salary = ?', 9000] }) do
      assert_equal developers(:poor_jamis), Developer.find(:first)
    end
  end

  def test_scoped_find_combines_and_sanitizes_conditions
    Developer.send(:with_scope, :find => { :conditions => ['salary = ?', 9000] }) do
      assert_equal developers(:poor_jamis), Developer.find(:first, :conditions => ['name = ?', 'Jamis'])
    end
  end

  def test_scoped_find_all
    Developer.send(:with_scope, :find => { :conditions => "name = 'David'" }) do
      assert_equal [developers(:david)], Developer.all
    end
  end

  def test_scoped_find_select
    Developer.send(:with_scope, :find => { :select => "id, name" }) do
      developer = Developer.find(:first, :conditions => "name = 'David'")
      assert_equal "David", developer.name
      assert !developer.has_attribute?(:salary)
    end
  end

  def test_scope_select_concatenates
    Developer.send(:with_scope, :find => { :select => "name" }) do
      developer = Developer.find(:first, :select => 'id, salary', :conditions => "name = 'David'")
      assert_equal 80000, developer.salary
      assert developer.has_attribute?(:id)
      assert developer.has_attribute?(:name)
      assert developer.has_attribute?(:salary)
    end
  end

  def test_scoped_count
    Developer.send(:with_scope, :find => { :conditions => "name = 'David'" }) do
      assert_equal 1, Developer.count
    end

    Developer.send(:with_scope, :find => { :conditions => 'salary = 100000' }) do
      assert_equal 8, Developer.count
      assert_equal 1, Developer.count(:conditions => "name LIKE 'fixture_1%'")
    end
  end

  def test_scoped_find_include
    # with the include, will retrieve only developers for the given project
    scoped_developers = Developer.send(:with_scope, :find => { :include => :projects }) do
      Developer.find(:all, :conditions => 'projects.id = 2')
    end
    assert scoped_developers.include?(developers(:david))
    assert !scoped_developers.include?(developers(:jamis))
    assert_equal 1, scoped_developers.size
  end

  def test_scoped_find_joins
    scoped_developers = Developer.send(:with_scope, :find => { :joins => 'JOIN developers_projects ON id = developer_id' } ) do
      Developer.find(:all, :conditions => 'developers_projects.project_id = 2')
    end
    assert scoped_developers.include?(developers(:david))
    assert !scoped_developers.include?(developers(:jamis))
    assert_equal 1, scoped_developers.size
    assert_equal developers(:david).attributes, scoped_developers.first.attributes
  end

  def test_scoped_find_using_new_style_joins
    scoped_developers = Developer.send(:with_scope, :find => { :joins => :projects }) do
      Developer.find(:all, :conditions => 'projects.id = 2')
    end
    assert scoped_developers.include?(developers(:david))
    assert !scoped_developers.include?(developers(:jamis))
    assert_equal 1, scoped_developers.size
    assert_equal developers(:david).attributes, scoped_developers.first.attributes
  end

  def test_scoped_find_merges_old_style_joins
    scoped_authors = Author.send(:with_scope, :find => { :joins => 'INNER JOIN posts ON authors.id = posts.author_id ' }) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => 'INNER JOIN comments ON posts.id = comments.post_id', :conditions => 'comments.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_find_merges_new_style_joins
    scoped_authors = Author.send(:with_scope, :find => { :joins => :posts }) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => :comments, :conditions => 'comments.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_find_merges_new_and_old_style_joins
    scoped_authors = Author.send(:with_scope, :find => { :joins => :posts }) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => 'JOIN comments ON posts.id = comments.post_id', :conditions => 'comments.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_find_merges_string_array_style_and_string_style_joins
    scoped_authors = Author.send(:with_scope, :find => { :joins => ["INNER JOIN posts ON posts.author_id = authors.id"]}) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => 'INNER JOIN comments ON posts.id = comments.post_id', :conditions => 'comments.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_find_merges_string_array_style_and_hash_style_joins
    scoped_authors = Author.send(:with_scope, :find => { :joins => :posts}) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => ['INNER JOIN comments ON posts.id = comments.post_id'], :conditions => 'comments.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_find_merges_joins_and_eliminates_duplicate_string_joins
    scoped_authors = Author.send(:with_scope, :find => { :joins => 'INNER JOIN posts ON posts.author_id = authors.id'}) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => ["INNER JOIN posts ON posts.author_id = authors.id", "INNER JOIN comments ON posts.id = comments.post_id"], :conditions => 'comments.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_find_strips_spaces_from_string_joins_and_eliminates_duplicate_string_joins
    scoped_authors = Author.send(:with_scope, :find => { :joins => ' INNER JOIN posts ON posts.author_id = authors.id '}) do
      Author.find(:all, :select => 'DISTINCT authors.*', :joins => ['INNER JOIN posts ON posts.author_id = authors.id'], :conditions => 'posts.id = 1')
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_scoped_count_include
    # with the include, will retrieve only developers for the given project
    Developer.send(:with_scope, :find => { :include => :projects }) do
      assert_equal 1, Developer.count(:conditions => 'projects.id = 2')
    end
  end

  def test_scope_for_create_only_uses_equal
    table = VerySpecialComment.arel_table
    relation = VerySpecialComment.scoped
    relation.where_values << table[:id].not_eq(1)
    assert_equal({'type' => "VerySpecialComment"}, relation.send(:scope_for_create))
  end

  def test_scoped_create
    new_comment = nil

    VerySpecialComment.send(:with_scope, :create => { :post_id => 1 }) do
      assert_equal({'post_id' => 1, 'type' => 'VerySpecialComment' }, VerySpecialComment.scoped.send(:scope_for_create))
      new_comment = VerySpecialComment.create :body => "Wonderful world"
    end

    assert Post.find(1).comments.include?(new_comment)
  end

  def test_scoped_create_with_join_and_merge
    Comment.where(:body => "but Who's Buying?").joins(:post).merge(Post.where(:body => 'Peace Sells...')).with_scope do
      assert_equal({'body' => "but Who's Buying?"}, Comment.scoped.scope_for_create)
    end
  end

  def test_immutable_scope
    options = { :conditions => "name = 'David'" }
    Developer.send(:with_scope, :find => options) do
      assert_equal %w(David), Developer.all.map(&:name)
      options[:conditions] = "name != 'David'"
      assert_equal %w(David), Developer.all.map(&:name)
    end

    scope = { :find => { :conditions => "name = 'David'" }}
    Developer.send(:with_scope, scope) do
      assert_equal %w(David), Developer.all.map(&:name)
      scope[:find][:conditions] = "name != 'David'"
      assert_equal %w(David), Developer.all.map(&:name)
    end
  end

  def test_scoped_with_duck_typing
    scoping = Struct.new(:current_scope).new(:find => { :conditions => ["name = ?", 'David'] })
    Developer.send(:with_scope, scoping) do
       assert_equal %w(David), Developer.all.map(&:name)
    end
  end

  def test_ensure_that_method_scoping_is_correctly_restored
    begin
      Developer.send(:with_scope, :find => { :conditions => "name = 'Jamis'" }) do
        raise "an exception"
      end
    rescue
    end

    assert !Developer.scoped.where_values.include?("name = 'Jamis'")
  end
end

class NestedScopingTest < ActiveRecord::TestCase
  fixtures :authors, :developers, :projects, :comments, :posts

  def test_merge_options
    Developer.send(:with_scope, :find => { :conditions => 'salary = 80000' }) do
      Developer.send(:with_scope, :find => { :limit => 10 }) do
        devs = Developer.scoped
        assert_match '(salary = 80000)', devs.to_sql
        assert_equal 10, devs.taken
      end
    end
  end

  def test_merge_inner_scope_has_priority
    Developer.send(:with_scope, :find => { :limit => 5 }) do
      Developer.send(:with_scope, :find => { :limit => 10 }) do
        assert_equal 10, Developer.scoped.taken
      end
    end
  end

  def test_replace_options
    Developer.send(:with_scope, :find => { :conditions => {:name => 'David'} }) do
      Developer.send(:with_exclusive_scope, :find => { :conditions => {:name => 'Jamis'} }) do
        assert_equal 'Jamis', Developer.scoped.send(:scope_for_create)[:name]
      end

      assert_equal 'David', Developer.scoped.send(:scope_for_create)[:name]
    end
  end

  def test_with_exclusive_scope_with_relation
    assert_raise(ArgumentError) do
      Developer.all_johns
    end
  end

  def test_append_conditions
    Developer.send(:with_scope, :find => { :conditions => "name = 'David'" }) do
      Developer.send(:with_scope, :find => { :conditions => 'salary = 80000' }) do
        devs = Developer.scoped
        assert_match "(name = 'David') AND (salary = 80000)", devs.to_sql
        assert_equal(1, Developer.count)
      end
      Developer.send(:with_scope, :find => { :conditions => "name = 'Maiha'" }) do
        assert_equal(0, Developer.count)
      end
    end
  end

  def test_merge_and_append_options
    Developer.send(:with_scope, :find => { :conditions => 'salary = 80000', :limit => 10 }) do
      Developer.send(:with_scope, :find => { :conditions => "name = 'David'" }) do
        devs = Developer.scoped
        assert_match "(salary = 80000) AND (name = 'David')", devs.to_sql
        assert_equal 10, devs.taken
      end
    end
  end

  def test_nested_scoped_find
    Developer.send(:with_scope, :find => { :conditions => "name = 'Jamis'" }) do
      Developer.send(:with_exclusive_scope, :find => { :conditions => "name = 'David'" }) do
        assert_nothing_raised { Developer.find(1) }
        assert_equal('David', Developer.find(:first).name)
      end
      assert_equal('Jamis', Developer.find(:first).name)
    end
  end

  def test_nested_scoped_find_include
    Developer.send(:with_scope, :find => { :include => :projects }) do
      Developer.send(:with_scope, :find => { :conditions => "projects.id = 2" }) do
        assert_nothing_raised { Developer.find(1) }
        assert_equal('David', Developer.find(:first).name)
      end
    end
  end

  def test_nested_scoped_find_merged_include
    # :include's remain unique and don't "double up" when merging
    Developer.send(:with_scope, :find => { :include => :projects, :conditions => "projects.id = 2" }) do
      Developer.send(:with_scope, :find => { :include => :projects }) do
        assert_equal 1, Developer.scoped.includes_values.uniq.length
        assert_equal 'David', Developer.find(:first).name
      end
    end

    # the nested scope doesn't remove the first :include
    Developer.send(:with_scope, :find => { :include => :projects, :conditions => "projects.id = 2" }) do
      Developer.send(:with_scope, :find => { :include => [] }) do
        assert_equal 1, Developer.scoped.includes_values.uniq.length
        assert_equal('David', Developer.find(:first).name)
      end
    end

    # mixing array and symbol include's will merge correctly
    Developer.send(:with_scope, :find => { :include => [:projects], :conditions => "projects.id = 2" }) do
      Developer.send(:with_scope, :find => { :include => :projects }) do
        assert_equal 1, Developer.scoped.includes_values.uniq.length
        assert_equal('David', Developer.find(:first).name)
      end
    end
  end

  def test_nested_scoped_find_replace_include
    Developer.send(:with_scope, :find => { :include => :projects }) do
      Developer.send(:with_exclusive_scope, :find => { :include => [] }) do
        assert_equal 0, Developer.scoped.includes_values.length
      end
    end
  end

  def test_three_level_nested_exclusive_scoped_find
    Developer.send(:with_scope, :find => { :conditions => "name = 'Jamis'" }) do
      assert_equal('Jamis', Developer.find(:first).name)

      Developer.send(:with_exclusive_scope, :find => { :conditions => "name = 'David'" }) do
        assert_equal('David', Developer.find(:first).name)

        Developer.send(:with_exclusive_scope, :find => { :conditions => "name = 'Maiha'" }) do
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
    Developer.send(:with_scope, :find => { :conditions => "salary < 100000" }) do
      Developer.send(:with_scope, :find => { :offset => 1, :order => 'id asc' }) do
        # Oracle adapter does not generated space after asc therefore trailing space removed from regex
        assert_sql(/ORDER BY\s+id asc/) do
          assert_equal(poor_jamis, Developer.find(:first, :order => 'id asc'))
        end
      end
    end
  end

  def test_merged_scoped_find_sanitizes_conditions
    Developer.send(:with_scope, :find => { :conditions => ["name = ?", 'David'] }) do
      Developer.send(:with_scope, :find => { :conditions => ['salary = ?', 9000] }) do
        assert_raise(ActiveRecord::RecordNotFound) { developers(:poor_jamis) }
      end
    end
  end

  def test_nested_scoped_find_combines_and_sanitizes_conditions
    Developer.send(:with_scope, :find => { :conditions => ["name = ?", 'David'] }) do
      Developer.send(:with_exclusive_scope, :find => { :conditions => ['salary = ?', 9000] }) do
        assert_equal developers(:poor_jamis), Developer.find(:first)
        assert_equal developers(:poor_jamis), Developer.find(:first, :conditions => ['name = ?', 'Jamis'])
      end
    end
  end

  def test_merged_scoped_find_combines_and_sanitizes_conditions
    Developer.send(:with_scope, :find => { :conditions => ["name = ?", 'David'] }) do
      Developer.send(:with_scope, :find => { :conditions => ['salary > ?', 9000] }) do
        assert_equal %w(David), Developer.all.map(&:name)
      end
    end
  end

  def test_nested_scoped_create
    comment = nil
    Comment.send(:with_scope, :create => { :post_id => 1}) do
      Comment.send(:with_scope, :create => { :post_id => 2}) do
        assert_equal({'post_id' => 2}, Comment.scoped.send(:scope_for_create))
        comment = Comment.create :body => "Hey guys, nested scopes are broken. Please fix!"
      end
    end
    assert_equal 2, comment.post_id
  end

  def test_nested_exclusive_scope_for_create
    comment = nil

    Comment.send(:with_scope, :create => { :body => "Hey guys, nested scopes are broken. Please fix!" }) do
      Comment.send(:with_exclusive_scope, :create => { :post_id => 1 }) do
        assert_equal({'post_id' => 1}, Comment.scoped.send(:scope_for_create))
        assert_blank Comment.new.body
        comment = Comment.create :body => "Hey guys"
      end
    end
    assert_equal 1, comment.post_id
    assert_equal 'Hey guys', comment.body
  end

  def test_merged_scoped_find_on_blank_conditions
    [nil, " ", [], {}].each do |blank|
      Developer.send(:with_scope, :find => {:conditions => blank}) do
        Developer.send(:with_scope, :find => {:conditions => blank}) do
          assert_nothing_raised { Developer.find(:first) }
        end
      end
    end
  end

  def test_merged_scoped_find_on_blank_bind_conditions
    [ [""], ["",{}] ].each do |blank|
      Developer.send(:with_scope, :find => {:conditions => blank}) do
        Developer.send(:with_scope, :find => {:conditions => blank}) do
          assert_nothing_raised { Developer.find(:first) }
        end
      end
    end
  end

  def test_immutable_nested_scope
    options1 = { :conditions => "name = 'Jamis'" }
    options2 = { :conditions => "name = 'David'" }
    Developer.send(:with_scope, :find => options1) do
      Developer.send(:with_exclusive_scope, :find => options2) do
        assert_equal %w(David), Developer.all.map(&:name)
        options1[:conditions] = options2[:conditions] = nil
        assert_equal %w(David), Developer.all.map(&:name)
      end
    end
  end

  def test_immutable_merged_scope
    options1 = { :conditions => "name = 'Jamis'" }
    options2 = { :conditions => "salary > 10000" }
    Developer.send(:with_scope, :find => options1) do
      Developer.send(:with_scope, :find => options2) do
        assert_equal %w(Jamis), Developer.all.map(&:name)
        options1[:conditions] = options2[:conditions] = nil
        assert_equal %w(Jamis), Developer.all.map(&:name)
      end
    end
  end

  def test_ensure_that_method_scoping_is_correctly_restored
    Developer.send(:with_scope, :find => { :conditions => "name = 'David'" }) do
      begin
        Developer.send(:with_scope, :find => { :conditions => "name = 'Maiha'" }) do
          raise "an exception"
        end
      rescue
      end

      assert Developer.scoped.where_values.include?("name = 'David'")
      assert !Developer.scoped.where_values.include?("name = 'Maiha'")
    end
  end

  def test_nested_scoped_find_merges_old_style_joins
    scoped_authors = Author.send(:with_scope, :find => { :joins => 'INNER JOIN posts ON authors.id = posts.author_id' }) do
      Author.send(:with_scope, :find => { :joins => 'INNER JOIN comments ON posts.id = comments.post_id' }) do
        Author.find(:all, :select => 'DISTINCT authors.*', :conditions => 'comments.id = 1')
      end
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_nested_scoped_find_merges_new_style_joins
    scoped_authors = Author.send(:with_scope, :find => { :joins => :posts }) do
      Author.send(:with_scope, :find => { :joins => :comments }) do
        Author.find(:all, :select => 'DISTINCT authors.*', :conditions => 'comments.id = 1')
      end
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end

  def test_nested_scoped_find_merges_new_and_old_style_joins
    scoped_authors = Author.send(:with_scope, :find => { :joins => :posts }) do
      Author.send(:with_scope, :find => { :joins => 'INNER JOIN comments ON posts.id = comments.post_id' }) do
        Author.find(:all, :select => 'DISTINCT authors.*', :joins => '', :conditions => 'comments.id = 1')
      end
    end
    assert scoped_authors.include?(authors(:david))
    assert !scoped_authors.include?(authors(:mary))
    assert_equal 1, scoped_authors.size
    assert_equal authors(:david).attributes, scoped_authors.first.attributes
  end
end
