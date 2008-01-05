require 'abstract_unit'

class ContentTypeController < ActionController::Base
  def render_content_type_from_body
    response.content_type = Mime::RSS
    render :text => "hello world!"
  end

  def render_defaults
    render :text => "hello world!"
  end

  def render_content_type_from_render
    render :text => "hello world!", :content_type => Mime::RSS
  end
  
  def render_charset_from_body
    response.charset = "utf-16"
    render :text => "hello world!"
  end
  
  def render_default_for_rhtml
  end

  def render_default_for_rxml
  end

  def render_default_for_rjs
  end

  def render_change_for_rxml
    response.content_type = Mime::HTML
    render :action => "render_default_for_rxml"
  end

  def render_default_content_types_for_respond_to
    respond_to do |format|
      format.html { render :text   => "hello world!" }
      format.xml  { render :action => "render_default_content_types_for_respond_to.rhtml" }
      format.js   { render :text   => "hello world!" }
      format.rss  { render :text   => "hello world!", :content_type => Mime::XML }
    end
  end

  def rescue_action(e) raise end
end

ContentTypeController.view_paths = [ File.dirname(__FILE__) + "/../fixtures/" ]

class ContentTypeTest < Test::Unit::TestCase
  def setup
    @controller = ContentTypeController.new

    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = Logger.new(nil)

    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_render_defaults
    get :render_defaults
    assert_equal "utf-8", @response.charset
    assert_equal Mime::HTML, @response.content_type
  end

  def test_render_changed_charset_default
    ContentTypeController.default_charset = "utf-16"
    get :render_defaults
    assert_equal "utf-16", @response.charset    
    assert_equal Mime::HTML, @response.content_type
    ContentTypeController.default_charset = "utf-8"
  end

  def test_content_type_from_body
    get :render_content_type_from_body
    assert_equal "application/rss+xml", @response.content_type
    assert_equal "utf-8", @response.charset    
  end

  def test_content_type_from_render
    get :render_content_type_from_render
    assert_equal "application/rss+xml", @response.content_type
    assert_equal "utf-8", @response.charset    
  end

  def test_charset_from_body
    get :render_charset_from_body
    assert_equal "utf-16", @response.charset
    assert_equal Mime::HTML, @response.content_type
  end

  def test_default_for_rhtml
    get :render_default_for_rhtml
    assert_equal Mime::HTML, @response.content_type
    assert_equal "utf-8", @response.charset    
  end

  def test_default_for_rxml
    get :render_default_for_rxml
    assert_equal Mime::XML, @response.content_type
    assert_equal "utf-8", @response.charset    
  end

  def test_default_for_rjs
    xhr :post, :render_default_for_rjs
    assert_equal Mime::JS, @response.content_type
    assert_equal "utf-8", @response.charset    
  end

  def test_change_for_rxml
    get :render_change_for_rxml
    assert_equal Mime::HTML, @response.content_type
    assert_equal "utf-8", @response.charset    
  end
  
  def test_render_default_content_types_for_respond_to
    @request.env["HTTP_ACCEPT"] = Mime::HTML.to_s
    get :render_default_content_types_for_respond_to
    assert_equal Mime::HTML, @response.content_type

    @request.env["HTTP_ACCEPT"] = Mime::JS.to_s
    get :render_default_content_types_for_respond_to
    assert_equal Mime::JS, @response.content_type
  end

  def test_render_default_content_types_for_respond_to_with_template
    @request.env["HTTP_ACCEPT"] = Mime::XML.to_s
    get :render_default_content_types_for_respond_to
    assert_equal Mime::XML, @response.content_type
  end
  
  def test_render_default_content_types_for_respond_to_with_overwrite
    @request.env["HTTP_ACCEPT"] = Mime::RSS.to_s
    get :render_default_content_types_for_respond_to
    assert_equal Mime::XML, @response.content_type
  end
end
