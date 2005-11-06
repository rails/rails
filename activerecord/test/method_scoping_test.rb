require 'abstract_unit'
require 'fixtures/developer'
require 'fixtures/comment'
require 'fixtures/post'
require 'fixtures/category'

class MethodScopingTest < Test::Unit::TestCase
  fixtures :developers, :comments, :posts
  
  def test_set_conditions
    Developer.with_scope(:find => { :conditions => 'just a test...' }) do
      assert_equal 'just a test...', Thread.current[:scoped_methods][Developer][:find][:conditions]
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
  
  def test_scoped_find_all
    Developer.with_scope(:find => { :conditions => "name = 'David'" }) do
      assert_equal [Developer.find(1)], Developer.find(:all)
    end      
  end
  
  def test_scoped_count
    Developer.with_scope(:find => { :conditions => "name = 'David'" }) do
      assert_equal 1, Developer.count
    end        

    Developer.with_scope(:find => { :conditions => 'salary = 100000' }) do
      assert_equal 8, Developer.count
      assert_equal 1, Developer.count("name LIKE 'fixture_1%'")
    end        
  end

  def test_scoped_create
    new_comment = nil

    VerySpecialComment.with_scope(:create => { :post_id => 1 }) do
      assert_equal({ :post_id => 1 }, Thread.current[:scoped_methods][VerySpecialComment][:create])
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

  def test_raise_on_nested_scope
    Developer.with_scope(:find => { :conditions => '1=1' }) do
      assert_raise(ArgumentError) do
        Developer.with_scope(:find => { :conditions => '2=2' }) { }
      end
    end
  end
end

class HasManyScopingTest< Test::Unit::TestCase
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

  def test_raise_on_nested_scope
    Comment.with_scope(:find => { :conditions => '1=1' }) do
      assert_raise(ArgumentError) { @welcome.comments.what_are_you }
    end
  end
end


class HasAndBelongsToManyScopingTest< Test::Unit::TestCase
  fixtures :posts, :categories, :categories_posts

  def setup
    @welcome = Post.find(1)
  end

  def test_forwarding_of_static_methods
    assert_equal 'a category...', Category.what_are_you
    assert_equal 'a category...', @welcome.categories.what_are_you
  end

  def test_forwarding_to_dynamic_finders
    assert_equal 1, Category.find_all_by_type('SpecialCategory').size
    assert_equal 0, @welcome.categories.find_all_by_type('SpecialCategory').size
    assert_equal 2, @welcome.categories.find_all_by_type('Category').size
  end

  def test_raise_on_nested_scope
    Category.with_scope(:find => { :conditions => '1=1' }) do
      assert_raise(ArgumentError) { @welcome.categories.what_are_you }
    end
  end
end


=begin
# We disabled the scoping for has_one and belongs_to as we can't think of a proper use case


class BelongsToScopingTest< Test::Unit::TestCase
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


class HasOneScopingTest< Test::Unit::TestCase
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
