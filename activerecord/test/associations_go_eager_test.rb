require 'abstract_unit'
require 'fixtures/post'
require 'fixtures/comment'
require 'fixtures/author'
require 'fixtures/category'

class EagerAssociationTest < Test::Unit::TestCase
  fixtures :posts, :comments, :authors, :categories, :categories_posts

  def test_loading_with_one_association
    posts = Post.find(:all, :include => :comments)
    assert_equal 2, posts.first.comments.size
    assert posts.first.comments.include?(@greetings)

    post = Post.find(:first, :include => :comments, :conditions => "posts.title = 'Welcome to the weblog'")
    assert_equal 2, post.comments.size
    assert post.comments.include?(@greetings)
  end

  def test_loading_with_multiple_associations
    posts = Post.find(:all, :include => [ :comments, :author, :categories ])
    assert_equal 2, posts.first.comments.size
    assert_equal 2, posts.first.categories.size
    assert_equal @greetings.body, posts.first.comments.first.body
  end

  def test_loading_from_an_association
    posts = @david.posts.find(:all, :include => :comments)
    assert_equal 2, posts.first.comments.size
  end

  def test_loading_with_no_associations
    assert_nil Post.find(@authorless.id, :include => :author).author
  end

  def test_eager_association_loading_with_belongs_to
    comments = Comment.find(:all, :include => :post)
    assert_equal @welcome.title, comments.first.post.title
    assert_equal @thinking.title, comments.last.post.title
  end

  def test_eager_association_loading_with_habtm
    posts = Post.find(:all, :include => :categories)
    assert_equal 2, posts.first.categories.size
    assert_equal 1, posts.last.categories.size
    assert_equal @technology.name, posts.first.categories.last.name
    assert_equal @general.name, posts.last.categories.first.name
  end
  
  def test_eager_with_inheritance
    posts = SpecialPost.find(:all, :include => [ :comments ])
  end  
end

