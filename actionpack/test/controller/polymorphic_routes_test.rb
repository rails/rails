require 'abstract_unit'

class Article
  attr_reader :id
  def save; @id = 1 end
  def new_record?; @id.nil? end
  def name
    model = self.class.name.downcase
    @id.nil? ? "new #{model}" : "#{model} ##{@id}"
  end
end

class Response < Article
  def post_id; 1 end
end

class Tag < Article
  def response_id; 1 end
end

# TODO: test nested models
class Response::Nested < Response; end

class PolymorphicRoutesTest < ActiveSupport::TestCase
  include ActionController::PolymorphicRoutes

  def setup
    @article = Article.new
    @response = Response.new
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

  def test_url_helper_prefixed_with_edit_with_url_options
    @article.save
    expects(:edit_article_url).with(@article, :param1 => '10')
    edit_polymorphic_url(@article, :param1 => '10')
  end

  def test_url_helper_with_url_options
    @article.save
    expects(:article_url).with(@article, :param1 => '10')
    polymorphic_url(@article, :param1 => '10')
  end

  def test_formatted_url_helper_is_deprecated
    expects(:articles_url).with(:format => :pdf)
    assert_deprecated do
      formatted_polymorphic_url([@article, :pdf])
    end
  end

  def test_format_option
    @article.save
    expects(:article_url).with(@article, :format => :pdf)
    polymorphic_url(@article, :format => :pdf)
  end

  def test_format_option_with_url_options
    @article.save
    expects(:article_url).with(@article, :format => :pdf, :param1 => '10')
    polymorphic_url(@article, :format => :pdf, :param1 => '10')
  end

  def test_id_and_format_option
    @article.save
    expects(:article_url).with(:id => @article, :format => :pdf)
    polymorphic_url(:id => @article, :format => :pdf)
  end

  def test_with_nested
    @response.save
    expects(:article_response_url).with(@article, @response)
    polymorphic_url([@article, @response])
  end

  def test_with_nested_unsaved
    expects(:article_responses_url).with(@article)
    polymorphic_url([@article, @response])
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
    expects(:admin_article_responses_url).with(@article)
    polymorphic_url([:admin, @article, @response])
  end

  def test_nested_with_array_and_namespace
    @response.save
    expects(:admin_article_response_url).with(@article, @response)
    polymorphic_url([:admin, @article, @response])

    # a ridiculously long named route tests correct ordering of namespaces and nesting:
    @tag = Tag.new
    @tag.save
    expects(:site_admin_article_response_tag_url).with(@article, @response, @tag)
    polymorphic_url([:site, :admin, @article, @response, @tag])
  end

  def test_nesting_with_array_ending_in_singleton_resource
    expects(:article_response_url).with(@article)
    polymorphic_url([@article, :response])
  end

  def test_nesting_with_array_containing_singleton_resource
    @tag = Tag.new
    @tag.save
    expects(:article_response_tag_url).with(@article, @tag)
    polymorphic_url([@article, :response, @tag])
  end

  def test_nesting_with_array_containing_namespace_and_singleton_resource
    @tag = Tag.new
    @tag.save
    expects(:admin_article_response_tag_url).with(@article, @tag)
    polymorphic_url([:admin, @article, :response, @tag])
  end

  def test_nesting_with_array_containing_singleton_resource_and_format
    @tag = Tag.new
    @tag.save
    expects(:article_response_tag_url).with(@article, @tag, :format => :pdf)
    polymorphic_url([@article, :response, @tag], :format => :pdf)
  end

  def test_nesting_with_array_containing_singleton_resource_and_format_option
    @tag = Tag.new
    @tag.save
    expects(:article_response_tag_url).with(@article, @tag, :format => :pdf)
    polymorphic_url([@article, :response, @tag], :format => :pdf)
  end

  def test_nesting_with_array_containing_nil
    expects(:article_response_url).with(@article)
    polymorphic_url([@article, nil, :response])
  end

  def test_with_array_containing_single_object
    @article.save
    expects(:article_url).with(@article)
    polymorphic_url([nil, @article])
  end

  def test_with_array_containing_single_name
    @article.save
    expects(:articles_url)
    polymorphic_url([:articles])
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

  def test_polymorphic_path_does_not_modify_arguments
    expects(:admin_article_responses_url).with(@article)
    path = [:admin, @article, @response]
    assert_no_difference 'path.size' do
      polymorphic_url(path)
    end
  end
end
