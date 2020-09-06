# frozen_string_literal: true

require 'abstract_unit'

class TestController < ActionController::Base
end

class SetupFiberedBase < ActiveSupport::TestCase
  def setup
    ActionView::LookupContext::DetailsKey.clear

    view_paths = ActionController::Base.view_paths

    @assigns = { secret: 'in the sauce', name: nil }
    @view = ActionView::Base.with_empty_template_cache.with_view_paths(view_paths, @assigns)
    @controller_view = TestController.new.view_context
  end

  def render_body(options)
    @view.view_renderer.render_body(@view, options)
  end

  def buffered_render(options)
    body = render_body(options)
    string = +''
    body.each do |piece|
      string << piece
    end
    string
  end
end

class FiberedTest < SetupFiberedBase
  def test_streaming_works
    content = []
    body = render_body(template: 'test/hello_world', layout: 'layouts/yield')

    body.each do |piece|
      content << piece
    end

    assert_equal '<title>',      content[0]
    assert_equal '',             content[1]
    assert_equal "</title>\n",   content[2]
    assert_equal 'Hello world!', content[3]
    assert_equal "\n",           content[4]
  end

  def test_render_file
    assert_equal 'Hello world!', assert_deprecated { buffered_render(file: 'test/hello_world') }
  end

  def test_render_file_with_locals
    locals = { secret: 'in the sauce' }
    assert_equal "The secret is in the sauce\n", assert_deprecated { buffered_render(file: 'test/render_file_with_locals', locals: locals) }
  end

  def test_render_partial
    assert_equal 'only partial', buffered_render(partial: 'test/partial_only')
  end

  def test_render_inline
    assert_equal 'Hello, World!', buffered_render(inline: 'Hello, World!')
  end

  def test_render_without_layout
    assert_equal 'Hello world!', buffered_render(template: 'test/hello_world')
  end

  def test_render_with_layout
    assert_equal %(<title></title>\nHello world!\n),
      buffered_render(template: 'test/hello_world', layout: 'layouts/yield')
  end

  def test_render_with_layout_which_has_render_inline
    assert_equal %(welcome\nHello world!\n),
      buffered_render(template: 'test/hello_world', layout: 'layouts/yield_with_render_inline_inside')
  end

  def test_render_with_layout_which_renders_another_partial
    assert_equal %(partial html\nHello world!\n),
      buffered_render(template: 'test/hello_world', layout: 'layouts/yield_with_render_partial_inside')
  end

  def test_render_with_nested_layout
    assert_equal %(<title>title</title>\n\n<div id="column">column</div>\n<div id="content">content</div>\n),
      buffered_render(template: 'test/nested_layout', layout: 'layouts/yield')
  end

  def test_render_with_file_in_layout
    assert_equal %(\n<title>title</title>\n\n),
      buffered_render(template: 'test/layout_render_file')
  end

  def test_render_with_handler_without_streaming_support
    assert_match '<p>This is grand!</p>', buffered_render(template: 'test/hello')
  end

  def test_render_with_streaming_multiple_yields_provide_and_content_for
    assert_equal "Yes, \nthis works\n like a charm.",
      buffered_render(template: 'test/streaming', layout: 'layouts/streaming')
  end

  def test_render_with_streaming_with_fake_yields_and_streaming_buster
    assert_equal "This won't look\n good.",
      buffered_render(template: 'test/streaming_buster', layout: 'layouts/streaming')
  end

  def test_render_with_nested_streaming_multiple_yields_provide_and_content_for
    assert_equal "?Yes, \n\nthis works\n\n? like a charm.",
      buffered_render(template: 'test/nested_streaming', layout: 'layouts/streaming')
  end

  def test_render_with_streaming_and_capture
    assert_equal "Yes, \n this works\n like a charm.",
      buffered_render(template: 'test/streaming', layout: 'layouts/streaming_with_capture')
  end
end

class FiberedWithLocaleTest < SetupFiberedBase
  def setup
    @old_locale = I18n.locale
    I18n.locale = 'da'
    super
  end

  def teardown
    I18n.locale = @old_locale
  end

  def test_render_with_streaming_and_locale
    assert_equal "layout.locale: da\nview.locale: da\n\n",
      buffered_render(template: 'test/streaming_with_locale', layout: 'layouts/streaming_with_locale')
  end
end
