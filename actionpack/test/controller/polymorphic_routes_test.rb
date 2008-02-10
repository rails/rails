require File.dirname(__FILE__) + '/../abstract_unit'

class Article
  attr_reader :id
  def save; @id = 1 end
  def new_record?; @id.nil? end
  def name
    model = self.class.name.downcase
    @id.nil? ? "new #{model}" : "#{model} ##{@id}"
  end
end

class Comment < Article
  def post_id; 1 end
end

class Tag < Article
  def comment_id; 1 end
end

# TODO: test nested models
class Comment::Nested < Comment; end

uses_mocha 'polymorphic URL helpers' do
  class PolymorphicRoutesTest < Test::Unit::TestCase

    include ActionController::PolymorphicRoutes

    def setup
      @article = Article.new
      @comment = Comment.new
    end
  
    def test_with_record
      @article.save
      expects(:article_url).with(@article)
      polymorphic_url(@article)
    end

    def test_with_new_record
      expects(:articles_url).with()
      @article.expects(:new_record?).returns(true)
      polymorphic_url(@article)
    end

    def test_with_record_and_action
      expects(:new_article_url).with()
      @article.expects(:new_record?).never
      polymorphic_url(@article, :action => 'new')
    end

    def test_url_helper_prefixed_with_new
      expects(:new_article_url).with()
      new_polymorphic_url(@article)
    end

    def test_url_helper_prefixed_with_edit
      @article.save
      expects(:edit_article_url).with(@article)
      edit_polymorphic_url(@article)
    end

    def test_formatted_url_helper
      expects(:formatted_article_url).with(@article, :pdf)
      formatted_polymorphic_url([@article, :pdf])
    end

    # TODO: should this work?
    def xtest_format_option
      @article.save
      expects(:article_url).with(@article, :format => :pdf)
      polymorphic_url(@article, :format => :pdf)
    end

    def test_with_nested
      @comment.save
      expects(:article_comment_url).with(@article, @comment)
      polymorphic_url([@article, @comment])
    end

    def test_with_nested_unsaved
      expects(:article_comments_url).with(@article)
      polymorphic_url([@article, @comment])
    end

    def test_new_with_array_and_namespace
      expects(:new_admin_article_url).with()
      polymorphic_url([:admin, @article], :action => 'new')
    end

    def test_unsaved_with_array_and_namespace
      expects(:admin_articles_url).with()
      polymorphic_url([:admin, @article])
    end

    def test_nested_unsaved_with_array_and_namespace
      @article.save
      expects(:admin_article_url).with(@article)
      polymorphic_url([:admin, @article])
      expects(:admin_article_comments_url).with(@article)
      polymorphic_url([:admin, @article, @comment])
    end

    def test_nested_with_array_and_namespace
      @comment.save
      expects(:admin_article_comment_url).with(@article, @comment)
      polymorphic_url([:admin, @article, @comment])

      # a ridiculously long named route tests correct ordering of namespaces and nesting:
      @tag = Tag.new
      @tag.save
      expects(:site_admin_article_comment_tag_url).with(@article, @comment, @tag)
      polymorphic_url([:site, :admin, @article, @comment, @tag])
    end

    # TODO: Needs to be updated to correctly know about whether the object is in a hash or not
    def xtest_with_hash
      expects(:article_url).with(@article)
      @article.save
      polymorphic_url(:id => @article)
    end

    def test_polymorphic_path_accepts_options
      expects(:new_article_path).with()
      polymorphic_path(@article, :action => :new)
    end

  end
end
