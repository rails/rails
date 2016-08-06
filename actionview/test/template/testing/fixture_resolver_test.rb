require "abstract_unit"

class FixtureResolverTest < ActiveSupport::TestCase
  def test_should_return_empty_list_for_unknown_path
    resolver = ActionView::FixtureResolver.new()
    templates = resolver.find_all("path", "arbitrary", false, {locale: [], formats: [:html], variants: [], handlers: []})
    assert_equal [], templates, "expected an empty list of templates"
  end

  def test_should_return_template_for_declared_path
    resolver = ActionView::FixtureResolver.new("arbitrary/path.erb" => "this text")
    templates = resolver.find_all("path", "arbitrary", false, {locale: [], formats: [:html], variants: [], handlers: [:erb]})
    assert_equal 1, templates.size, "expected one template"
    assert_equal "this text",      templates.first.source
    assert_equal "arbitrary/path", templates.first.virtual_path
    assert_equal [:html],          templates.first.formats
  end
end
