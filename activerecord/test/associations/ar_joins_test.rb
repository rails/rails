require 'abstract_unit'
require 'fixtures/post'
require 'fixtures/comment'
require 'fixtures/author'
require 'fixtures/category'
require 'fixtures/categorization'
require 'fixtures/company'
require 'fixtures/topic'
require 'fixtures/reply'
require 'fixtures/developer'
require 'fixtures/project'

class ArJoinsTest < Test::Unit::TestCase
  fixtures :authors, :posts, :comments, :categories, :categories_posts, :people,
           :developers, :projects, :developers_projects,
           :categorizations, :companies, :accounts, :topics

  def test_ar_joins
    authors = Author.find(:all, :joins => :posts, :conditions => ['posts.type = ?', "Post"])
    assert_not_equal(0 , authors.length)
    authors.each do |author|
      assert !(author.send(:instance_variables).include? "@posts")
      assert(!author.readonly?, "non-string join value produced read-only result.")
    end
  end

  def test_ar_joins_with_cascaded_two_levels
    authors = Author.find(:all, :joins=>{:posts=>:comments})
    assert_equal(2, authors.length)
    authors.each do |author|
      assert !(author.send(:instance_variables).include? "@posts")
      assert(!author.readonly?, "non-string join value produced read-only result.")
    end
    authors = Author.find(:all, :joins=>{:posts=>:comments}, :conditions => ["comments.body = ?", "go crazy" ])
    assert_equal(1, authors.length)
    authors.each do |author|
      assert !(author.send(:instance_variables).include? "@posts")
      assert(!author.readonly?, "non-string join value produced read-only result.")
    end
  end


  def test_ar_joins_with_complex_conditions
    authors = Author.find(:all, :joins=>{:posts=>[:comments, :categories]},
    :conditions => ["categories.name = ?  AND posts.title = ?", "General", "So I was thinking"]
    )
    assert_equal(1, authors.length)
    authors.each do |author|
      assert !(author.send(:instance_variables).include? "@posts")
      assert(!author.readonly?, "non-string join value produced read-only result.")
    end
    assert_equal("David", authors.first.name)
  end

  def test_ar_join_with_has_many_and_limit_and_scoped_and_explicit_conditions
    Post.with_scope(:find => { :conditions => "1=1" }) do
      posts = authors(:david).posts.find(:all,
        :joins    => :comments,
        :conditions => "comments.body like 'Normal%' OR comments.#{QUOTED_TYPE}= 'SpecialComment'",
        :limit      => 2
      )
      assert_equal 2, posts.size

      count = Post.count(
        :joins    => [ :comments, :author ],
        :conditions => "authors.name = 'David' AND (comments.body like 'Normal%' OR comments.#{QUOTED_TYPE}= 'SpecialComment')",
        :limit      => 2
      )
      assert_equal count, posts.size
    end
  end

  def test_ar_join_with_scoped_order_using_association_limiting_without_explicit_scope
    posts_with_explicit_order = Post.find(:all, :conditions => 'comments.id is not null', :joins => :comments, :order => 'posts.id DESC', :limit => 2)
    posts_with_scoped_order = Post.with_scope(:find => {:order => 'posts.id DESC'}) do
      Post.find(:all, :conditions => 'comments.id is not null', :joins => :comments, :limit => 2)
    end
    assert_equal posts_with_explicit_order, posts_with_scoped_order
  end

  def test_scoped_find_include
    # with the include, will retrieve only developers for the given project
    scoped_developers = Developer.with_scope(:find => { :joins => :projects }) do
      Developer.find(:all, :conditions => 'projects.id = 2')
    end
    assert scoped_developers.include?(developers(:david))
    assert !scoped_developers.include?(developers(:jamis))
    assert_equal 1, scoped_developers.size
  end


  def test_nested_scoped_find_ar_join
    Developer.with_scope(:find => { :joins => :projects }) do
      Developer.with_scope(:find => { :conditions => "projects.id = 2" }) do
        assert_equal('David', Developer.find(:first).name)
      end
    end
  end

  def test_nested_scoped_find_merged_ar_join
    # :include's remain unique and don't "double up" when merging
    Developer.with_scope(:find => { :joins => :projects, :conditions => "projects.id = 2" }) do
      Developer.with_scope(:find => { :joins => :projects }) do
        assert_equal 1, Developer.instance_eval('current_scoped_methods')[:find][:ar_joins].length
        assert_equal('David', Developer.find(:first).name)
      end
    end
    # the nested scope doesn't remove the first :include
    Developer.with_scope(:find => { :joins => :projects, :conditions => "projects.id = 2" }) do
      Developer.with_scope(:find => { :joins => [] }) do
        assert_equal 1, Developer.instance_eval('current_scoped_methods')[:find][:ar_joins].length
        assert_equal('David', Developer.find(:first).name)
      end
    end
    # mixing array and symbol include's will merge correctly
    Developer.with_scope(:find => { :joins => [:projects], :conditions => "projects.id = 2" }) do
      Developer.with_scope(:find => { :joins => :projects }) do
        assert_equal 1, Developer.instance_eval('current_scoped_methods')[:find][:ar_joins].length
        assert_equal('David', Developer.find(:first).name)
      end
    end
  end

  def test_nested_scoped_find_replace_include
    Developer.with_scope(:find => { :joins => :projects }) do
      Developer.with_exclusive_scope(:find => { :joins => [] }) do
        assert_equal 0, Developer.instance_eval('current_scoped_methods')[:find][:ar_joins].length
      end
    end
  end

#
# Calculations
#
  def test_count_with_ar_joins
    assert_equal(2, Author.count(:joins => :posts, :conditions => ['posts.type = ?', "Post"]))
    assert_equal(1, Author.count(:joins => :posts, :conditions => ['posts.type = ?', "SpecialPost"]))
  end

  def test_should_get_maximum_of_field_with_joins
    assert_equal 50, Account.maximum(:credit_limit, :joins=> :firm, :conditions => "companies.name != 'Summit'")
  end

  def test_should_get_maximum_of_field_with_scoped_include
    Account.with_scope :find => { :joins => :firm, :conditions => "companies.name != 'Summit'" } do
      assert_equal 50, Account.maximum(:credit_limit)
    end
  end

  def test_should_not_modify_options_when_using_ar_joins_on_count
    options = {:conditions => 'companies.id > 1', :joins => :firm}
    options_copy = options.dup

    Account.count(:all, options)
    assert_equal options_copy, options
  end

end
