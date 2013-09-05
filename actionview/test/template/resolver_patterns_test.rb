require 'abstract_unit'

class ResolverPatternsTest < ActiveSupport::TestCase
  def setup
    path = File.expand_path("../../fixtures/", __FILE__)
    pattern = ":prefix/{:formats/,}:action{.:formats,}{.:handlers,}"
    @resolver = ActionView::FileSystemResolver.new(path, pattern)
  end

  def test_should_return_empty_list_for_unknown_path
    templates = @resolver.find_all("unknown", "custom_pattern", false, {:locale => [], :formats => [:html], :handlers => [:erb]})
    assert_equal [], templates, "expected an empty list of templates"
  end

  def test_should_return_template_for_declared_path
    templates = @resolver.find_all("path", "custom_pattern", false, {:locale => [], :formats => [:html], :handlers => [:erb]})
    assert_equal 1, templates.size, "expected one template"
    assert_equal "Hello custom patterns!", templates.first.source
    assert_equal "custom_pattern/path",    templates.first.virtual_path
    assert_equal [:html],                  templates.first.formats
  end

  def test_should_return_all_templates_when_ambiguous_pattern
    templates = @resolver.find_all("another", "custom_pattern", false, {:locale => [], :formats => [:html], :handlers => [:erb]})
    assert_equal 2, templates.size, "expected two templates"
    assert_equal "Another template!",      templates[0].source
    assert_equal "custom_pattern/another", templates[0].virtual_path
    assert_equal "Hello custom patterns!", templates[1].source
    assert_equal "custom_pattern/another", templates[1].virtual_path
  end
end
