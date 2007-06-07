require File.dirname(__FILE__) + '/../abstract_unit'

class Article
  attr_reader :id
  def save; @id = 1 end
  def new_record?; @id.nil? end
  def name
    @id.nil? ? 'new post' : "post ##{@id}"
  end
end

class Comment
  attr_reader :id
  def post_id; 1 end
  def save; @id = 1 end
  def new_record?; @id.nil? end
  def name
    @id.nil? ? 'new comment' : "comment ##{@id}"
  end
end

class Comment::Nested < Comment; end

class Test::Unit::TestCase
  protected
  def articles_url
    'http://www.example.com/articles'
  end
  alias_method :new_article_url, :articles_url
  
  def article_url(article)
    "http://www.example.com/articles/#{article.id}"
  end

  def article_comments_url(article)
    "http://www.example.com/articles/#{article.id}/comments"
  end
  
  def article_comment_url(article, comment)
    "http://www.example.com/articles/#{article.id}/comments/#{comment.id}"
  end
end


class PolymorphicRoutesTest < Test::Unit::TestCase
  include ActionController::PolymorphicRoutes

  def setup
    @article = Article.new
    @comment = Comment.new
  end
  
  def test_with_record
    assert_equal(articles_url, polymorphic_url(@article, :action => 'new'))
    assert_equal(articles_url, polymorphic_url(@article))
    @article.save
    assert_equal(article_url(@article), polymorphic_url(@article))
  end
  
  def test_with_hash
    @article.save
    assert_equal(article_url(@article), polymorphic_url(:id => @article))
  end
  
  def test_with_array
    assert_equal(article_comments_url(@article), polymorphic_url([@article, @comment]))
    @comment.save
    assert_equal(article_comment_url(@article, @comment), polymorphic_url([@article, @comment]))
  end
end
