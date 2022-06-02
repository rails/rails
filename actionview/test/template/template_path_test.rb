# frozen_string_literal: true

require "abstract_unit"

class TemplatePathTest < ActiveSupport::TestCase
  def test_build_returns_path_object
    path = ActionView::TemplatePath.build("bar", "foo", true)

    assert_equal "foo/_bar", path.virtual
    assert_equal "foo", path.prefix
    assert_equal "bar", path.name
    assert path.partial?
  end

  def test_virtual
    assert_equal "foo/bar", ActionView::TemplatePath.virtual("bar", "foo", false)
    assert_equal "foo/_bar", ActionView::TemplatePath.virtual("bar", "foo", true)
    assert_equal "bar", ActionView::TemplatePath.virtual("bar", "", false)
    assert_equal "_bar", ActionView::TemplatePath.virtual("bar", "", true)
    assert_equal "foo/bar/baz", ActionView::TemplatePath.virtual("baz", "foo/bar", false)
  end

  def test_parse_root_template
    path = ActionView::TemplatePath.parse("foo")
    assert_equal "", path.prefix
    assert_equal "foo", path.name
    assert_not path.partial?
  end

  def test_parse_root_template_with_slash
    path = ActionView::TemplatePath.parse("/foo")
    assert_equal "", path.prefix
    assert_equal "foo", path.name
    assert_not path.partial?
  end

  def test_parse_root_partial
    path = ActionView::TemplatePath.parse("_foo")
    assert_equal "", path.prefix
    assert_equal "foo", path.name
    assert path.partial?
  end

  def test_parse_root_partial_with_slash
    path = ActionView::TemplatePath.parse("/_foo")
    assert_equal "", path.prefix
    assert_equal "foo", path.name
    assert path.partial?
  end

  def test_parse_template
    path = ActionView::TemplatePath.parse("foo/bar")
    assert_equal "foo", path.prefix
    assert_equal "bar", path.name
    assert_not path.partial?
  end

  def test_parse_partial
    path = ActionView::TemplatePath.parse("foo/_bar")
    assert_equal "foo", path.prefix
    assert_equal "bar", path.name
    assert path.partial?
  end

  def test_parse_deep_partial
    path = ActionView::TemplatePath.parse("foo/bar/_baz")
    assert_equal "foo/bar", path.prefix
    assert_equal "baz", path.name
    assert path.partial?
  end

  def test_parse_deep_partial_with_slash
    path = ActionView::TemplatePath.parse("/foo/bar/_baz")
    assert_equal "foo/bar", path.prefix
    assert_equal "baz", path.name
    assert path.partial?
  end
end
