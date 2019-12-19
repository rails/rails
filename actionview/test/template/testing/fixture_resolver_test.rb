# frozen_string_literal: true

require "abstract_unit"

class FixtureResolverTest < ActiveSupport::TestCase
  def test_should_return_empty_list_for_unknown_path
    resolver = ActionView::FixtureResolver.new()
    templates = resolver.find_all("path", "arbitrary", false, locale: [], formats: [:html], variants: [], handlers: [])
    assert_equal [], templates, "expected an empty list of templates"
  end

  def test_should_return_template_for_declared_path
    resolver = ActionView::FixtureResolver.new("arbitrary/path.erb" => "this text")
    templates = resolver.find_all("path", "arbitrary", false, locale: [], formats: [:html], variants: [], handlers: [:erb])
    assert_equal 1, templates.size, "expected one template"
    assert_equal "this text",      templates.first.source
    assert_equal "arbitrary/path", templates.first.virtual_path
    assert_nil templates.first.format
  end

  def test_should_match_templates_with_variants
    resolver = ActionView::FixtureResolver.new("arbitrary/path.html+variant.erb" => "this text")
    templates = resolver.find_all("path", "arbitrary", false, locale: [], formats: [:html], variants: [:variant], handlers: [:erb])
    assert_equal 1, templates.size, "expected one template"
    assert_equal "this text",       templates.first.source
    assert_equal "arbitrary/path",  templates.first.virtual_path
    assert_equal :html,           templates.first.format
    assert_equal "variant",       templates.first.variant
  end

  def test_should_match_locales
    resolver = ActionView::FixtureResolver.new("arbitrary/path.erb" => "this text", "arbitrary/path.fr.erb" => "ce texte")
    en = resolver.find_all("path", "arbitrary", false, locale: [:en], formats: [:html], variants: [], handlers: [:erb])
    fr = resolver.find_all("path", "arbitrary", false, locale: [:fr], formats: [:html], variants: [], handlers: [:erb])

    assert_equal 1, en.size
    assert_equal 2, fr.size

    assert_equal "this text", en[0].source
    assert_equal "ce texte",  fr[0].source
    assert_equal "this text", fr[1].source
  end

  def test_should_return_all_variants_for_any
    resolver = ActionView::FixtureResolver.new("arbitrary/path.html.erb" => "this html", "arbitrary/path.html+varient.erb" => "this text")
    templates = resolver.find_all("path", "arbitrary", false, locale: [], formats: [:html], variants: [], handlers: [:erb])
    assert_equal 1, templates.size, "expected one template"
    assert_equal "this html", templates.first.source
    templates = resolver.find_all("path", "arbitrary", false, locale: [], formats: [:html], variants: :any, handlers: [:erb])
    assert_equal 2, templates.size, "expected all templates"
  end
end
