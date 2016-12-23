require "abstract_unit"

class StarStarMimeController < ActionController::Base
  layout nil

  def index
    render
  end
end

class StarStarMimeControllerTest < ActionController::TestCase
  def test_javascript_with_format
    @request.accept = "text/javascript"
    get :index, format: "js"
    assert_match "function addition(a,b){ return a+b; }", @response.body
  end

  def test_javascript_with_no_format
    @request.accept = "text/javascript"
    get :index
    assert_match "function addition(a,b){ return a+b; }", @response.body
  end

  def test_javascript_with_no_format_only_star_star
    @request.accept = "*/*"
    get :index
    assert_match "function addition(a,b){ return a+b; }", @response.body
  end
end

class AbstractPostController < ActionController::Base
  self.view_paths = File.dirname(__FILE__) + "/../../fixtures/post_test/"
end

# For testing layouts which are set automatically
class PostController < AbstractPostController
  around_action :with_iphone

  def index
    respond_to(:html, :iphone, :js)
  end

private

  def with_iphone
    request.format = "iphone" if request.env["HTTP_ACCEPT"] == "text/iphone"
    yield
  end
end

class SuperPostController < PostController
end

class MimeControllerLayoutsTest < ActionController::TestCase
  tests PostController

  def setup
    super
    @request.host = "www.example.com"
    Mime::Type.register_alias("text/html", :iphone)
  end

  def teardown
    super
    Mime::Type.unregister(:iphone)
  end

  def test_missing_layout_renders_properly
    get :index
    assert_equal '<html><div id="html">Hello Firefox</div></html>', @response.body

    @request.accept = "text/iphone"
    get :index
    assert_equal "Hello iPhone", @response.body
  end

  def test_format_with_inherited_layouts
    @controller = SuperPostController.new

    get :index
    assert_equal '<html><div id="html">Super Firefox</div></html>', @response.body

    @request.accept = "text/iphone"
    get :index
    assert_equal '<html><div id="super_iphone">Super iPhone</div></html>', @response.body
  end

  def test_non_navigational_format_with_no_template_fallbacks_to_html_template_with_no_layout
    get :index, format: :js
    assert_equal "Hello Firefox", @response.body
  end
end
