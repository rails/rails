require File.dirname(__FILE__) + '/../abstract_unit'

class CustomHandler
  def initialize( view )
    @view = view
  end

  def render( template, local_assigns )
    [ template,
      local_assigns,
      @view ]
  end
end

class CustomHandlerTest < Test::Unit::TestCase
  def setup
    ActionView::Base.register_template_handler "foo", CustomHandler
    ActionView::Base.register_template_handler :foo2, CustomHandler
    @view = ActionView::Base.new
  end

  def test_custom_render
    result = @view.render_template( "foo", "hello <%= one %>", nil, :one => "two" )
    assert_equal(
      [ "hello <%= one %>", { :one => "two" }, @view ],
      result )
  end

  def test_custom_render2
    result = @view.render_template( "foo2", "hello <%= one %>", nil, :one => "two" )
    assert_equal(
      [ "hello <%= one %>", { :one => "two" }, @view ],
      result )
  end

  def test_unhandled_extension
    # uses the ERb handler by default if the extension isn't recognized
    result = @view.render_template( "bar", "hello <%= one %>", nil, :one => "two" )
    assert_equal "hello two", result
  end
end
