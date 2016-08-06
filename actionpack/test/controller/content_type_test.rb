require "abstract_unit"

class OldContentTypeController < ActionController::Base
  # :ported:
  def render_content_type_from_body
    response.content_type = Mime[:rss]
    render body: "hello world!"
  end

  # :ported:
  def render_defaults
    render body: "hello world!"
  end

  # :ported:
  def render_content_type_from_render
    render body: "hello world!", content_type: Mime[:rss]
  end

  # :ported:
  def render_charset_from_body
    response.charset = "utf-16"
    render body: "hello world!"
  end

  # :ported:
  def render_nil_charset_from_body
    response.charset = nil
    render body: "hello world!"
  end

  def render_default_for_erb
  end

  def render_default_for_builder
  end

  def render_change_for_builder
    response.content_type = Mime[:html]
    render action: "render_default_for_builder"
  end

  def render_default_content_types_for_respond_to
    respond_to do |format|
      format.html { render body: "hello world!" }
      format.xml  { render action: "render_default_content_types_for_respond_to" }
      format.js   { render body: "hello world!" }
      format.rss  { render body: "hello world!", content_type: Mime[:xml] }
    end
  end
end

class ContentTypeTest < ActionController::TestCase
  tests OldContentTypeController

  def setup
    super
    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    @controller.logger = ActiveSupport::Logger.new(nil)
  end

  # :ported:
  def test_render_defaults
    get :render_defaults
    assert_equal "utf-8", @response.charset
    assert_equal Mime[:text], @response.content_type
  end

  def test_render_changed_charset_default
    with_default_charset "utf-16" do
      get :render_defaults
      assert_equal "utf-16", @response.charset
      assert_equal Mime[:text], @response.content_type
    end
  end

  # :ported:
  def test_content_type_from_body
    get :render_content_type_from_body
    assert_equal Mime[:rss], @response.content_type
    assert_equal "utf-8", @response.charset
  end

  # :ported:
  def test_content_type_from_render
    get :render_content_type_from_render
    assert_equal Mime[:rss], @response.content_type
    assert_equal "utf-8", @response.charset
  end

  # :ported:
  def test_charset_from_body
    get :render_charset_from_body
    assert_equal Mime[:text], @response.content_type
    assert_equal "utf-16", @response.charset
  end

  # :ported:
  def test_nil_charset_from_body
    get :render_nil_charset_from_body
    assert_equal Mime[:text], @response.content_type
    assert_equal "utf-8", @response.charset, @response.headers.inspect
  end

  def test_nil_default_for_erb
    with_default_charset nil do
      get :render_default_for_erb
      assert_equal Mime[:html], @response.content_type
      assert_nil @response.charset, @response.headers.inspect
    end
  end

  def test_default_for_erb
    get :render_default_for_erb
    assert_equal Mime[:html], @response.content_type
    assert_equal "utf-8", @response.charset
  end

  def test_default_for_builder
    get :render_default_for_builder
    assert_equal Mime[:xml], @response.content_type
    assert_equal "utf-8", @response.charset
  end

  def test_change_for_builder
    get :render_change_for_builder
    assert_equal Mime[:html], @response.content_type
    assert_equal "utf-8", @response.charset
  end

  private

  def with_default_charset(charset)
    old_default_charset = ActionDispatch::Response.default_charset
    ActionDispatch::Response.default_charset = charset
    yield
  ensure
    ActionDispatch::Response.default_charset = old_default_charset
  end
end

class AcceptBasedContentTypeTest < ActionController::TestCase
  tests OldContentTypeController

  def test_render_default_content_types_for_respond_to
    @request.accept = Mime[:html].to_s
    get :render_default_content_types_for_respond_to
    assert_equal Mime[:html], @response.content_type

    @request.accept = Mime[:js].to_s
    get :render_default_content_types_for_respond_to
    assert_equal Mime[:js], @response.content_type
  end

  def test_render_default_content_types_for_respond_to_with_template
    @request.accept = Mime[:xml].to_s
    get :render_default_content_types_for_respond_to
    assert_equal Mime[:xml], @response.content_type
  end

  def test_render_default_content_types_for_respond_to_with_overwrite
    @request.accept = Mime[:rss].to_s
    get :render_default_content_types_for_respond_to
    assert_equal Mime[:xml], @response.content_type
  end
end
