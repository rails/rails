# frozen_string_literal: true

require "abstract_unit"
require "template/resolver_shared_tests"
require "active_support/testing/ractors_assertions"

class FileSystemResolverTest < ActiveSupport::TestCase
  include ResolverSharedTests
  include ActiveSupport::Testing::RactorsAssertions

  def resolver
    ActionView::FileSystemResolver.new(tmpdir)
  end

  DETAILS = { locale: [:en], formats: [:html], variants: [], handlers: [:erb] }.freeze

  def find_all(resolver, name = "hello_world", prefix = "test", partial = false, locals = [])
    resolver.find_all(name, prefix, partial, DETAILS, nil, locals)
  end

  def compile_view
    ActionView::Base.with_empty_template_cache.empty
  end

  def test_freeze_raises_for_uncompiled_template
    with_file "test/hello_world.html.erb", "<%# locals: () %>Hi"
    resolver = ActionView::FileSystemResolver.new(tmpdir)
    resolver.eager_load_templates

    error = assert_raises(ArgumentError) { resolver.freeze }
    assert_match "must be compiled first", error.message
  end

  def test_eager_load_templates_populates_cache_without_freezing
    with_file "test/hello_world.html.erb", "Hello!"
    resolver = ActionView::FileSystemResolver.new(tmpdir)
    resolver.eager_load_templates

    assert_not resolver.frozen?
    templates = find_all(resolver)
    assert_equal 1, templates.size
    assert_equal "Hello!", templates[0].source
  end

  def test_eager_load_templates_compiles_templates_when_given_a_view
    with_file "test/hello_world.html.erb", "Hello!"
    view = ActionView::Base.with_empty_template_cache.empty
    resolver = ActionView::FileSystemResolver.new(tmpdir)

    assert_difference -> { view.compiled_method_container.instance_methods.size }, 1 do
      resolver.eager_load_templates(view)
    end
  end

  def test_eager_loaded_resolver_still_binds_new_locals
    with_file "test/hello_world.html.erb", "<%= message %>"
    resolver = ActionView::FileSystemResolver.new(tmpdir)
    resolver.eager_load_templates

    a = find_all(resolver, "hello_world", "test", false, [:message])[0]
    b = find_all(resolver, "hello_world", "test", false, [:message, :other])[0]

    assert_not_same a, b
    assert_not resolver.frozen?
  end

  def test_freeze_after_eager_load_makes_resolver_shareable
    with_file "test/hello_world.html.erb", "<%# locals: () %>Hi"
    ActiveSupport::Ractors.make_shareable(Mime[:html])
    resolver = ActionView::FileSystemResolver.new(tmpdir)
    resolver.eager_load_templates(compile_view)
    resolver.freeze

    assert_predicate resolver, :frozen?
    assert_ractor_shareable resolver

    templates = find_all(resolver)
    assert_equal 1, templates.size
    assert_predicate templates[0], :frozen?
  end

  def test_freeze_raises_for_non_strict_partial
    with_file "test/_card.html.erb", "<%= post %>"
    resolver = ActionView::FileSystemResolver.new(tmpdir)
    resolver.eager_load_templates

    error = assert_raises(ArgumentError) { resolver.freeze }
    assert_match "test/_card", error.message
    assert_match "strict locals", error.message
  end

  def test_freeze_raises_for_non_strict_template
    with_file "test/hello_world.html.erb", "no locals here"
    resolver = ActionView::FileSystemResolver.new(tmpdir)
    resolver.eager_load_templates

    error = assert_raises(ArgumentError) { resolver.freeze }
    assert_match "test/hello_world", error.message
    assert_match "strict locals", error.message
  end

  def test_frozen_resolver_returns_empty_for_missing_template
    with_file "test/hello_world.html.erb", "<%# locals: () %>Hi"
    resolver = ActionView::FileSystemResolver.new(tmpdir)
    resolver.eager_load_templates(compile_view)
    resolver.freeze

    assert_empty find_all(resolver, "nonexistent")
  end
end
