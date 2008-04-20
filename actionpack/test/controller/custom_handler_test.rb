require 'abstract_unit'

class CustomHandler < ActionView::TemplateHandler
  def initialize( view )
    @view = view
  end

  def render( template )
    [ template.source,
      template.locals,
      @view ]
  end
end

class CustomHandlerTest < Test::Unit::TestCase
  def setup
    ActionView::Template.register_template_handler "foo", CustomHandler
    ActionView::Template.register_template_handler :foo2, CustomHandler
    @view = ActionView::Base.new
  end

  def test_custom_render
    template = ActionView::InlineTemplate.new(@view, "hello <%= one %>", { :one => "two" }, "foo")

    result = @view.render_template(template)
    assert_equal(
      [ "hello <%= one %>", { :one => "two" }, @view ],
      result )
  end

  def test_custom_render2
    template = ActionView::InlineTemplate.new(@view, "hello <%= one %>", { :one => "two" }, "foo2")
    result = @view.render_template(template)
    assert_equal(
      [ "hello <%= one %>", { :one => "two" }, @view ],
      result )
  end

  def test_unhandled_extension
    # uses the ERb handler by default if the extension isn't recognized
    template = ActionView::InlineTemplate.new(@view, "hello <%= one %>", { :one => "two" }, "bar")
    result = @view.render_template(template)
    assert_equal "hello two", result
  end
end
