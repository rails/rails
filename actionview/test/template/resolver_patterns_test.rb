require "abstract_unit"

class ResolverPatternsTest < ActiveSupport::TestCase
  def setup
    path = File.expand_path("../../fixtures/", __FILE__)
    pattern = ":prefix/{:formats/,}:action{.:formats,}{+:variants,}{.:handlers,}"
    @resolver = ActionView::FileSystemResolver.new(path, pattern)
  end

  def test_should_return_empty_list_for_unknown_path
    templates = @resolver.find_all("unknown", "custom_pattern", false, {locale: [], formats: [:html], variants: [], handlers: [:erb]})
    assert_equal [], templates, "expected an empty list of templates"
  end

  def test_should_return_template_for_declared_path
    templates = @resolver.find_all("path", "custom_pattern", false, {locale: [], formats: [:html], variants: [], handlers: [:erb]})
    assert_equal 1, templates.size, "expected one template"
    assert_equal "Hello custom patterns!", templates.first.source
    assert_equal "custom_pattern/path",    templates.first.virtual_path
    assert_equal [:html],                  templates.first.formats
  end

  def test_should_return_all_templates_when_ambiguous_pattern
    templates = @resolver.find_all("another", "custom_pattern", false, {locale: [], formats: [:html], variants: [], handlers: [:erb]})
    assert_equal 2, templates.size, "expected two templates"
    assert_equal "Another template!",      templates[0].source
    assert_equal "custom_pattern/another", templates[0].virtual_path
    assert_equal "Hello custom patterns!", templates[1].source
    assert_equal "custom_pattern/another", templates[1].virtual_path
  end

  def test_should_return_all_variants_for_any
    templates = @resolver.find_all("hello_world", "test", false, {locale: [], formats: [:html, :text], variants: :any, handlers: [:erb]})
    assert_equal 3, templates.size, "expected three templates"
    assert_equal "Hello phone!",       templates[0].source
    assert_equal "test/hello_world",   templates[0].virtual_path
    assert_equal "Hello texty phone!", templates[1].source
    assert_equal "test/hello_world",   templates[1].virtual_path
    assert_equal "Hello world!",       templates[2].source
    assert_equal "test/hello_world",   templates[2].virtual_path
  end
end
