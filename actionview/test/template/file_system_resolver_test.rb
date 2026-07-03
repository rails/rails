# frozen_string_literal: true

require "abstract_unit"
require "template/resolver_shared_tests"

class FileSystemResolverTest < ActiveSupport::TestCase
  include ResolverSharedTests

  def resolver
    ActionView::FileSystemResolver.new(tmpdir)
  end

  DETAILS = { locale: [:en], formats: [:html], variants: [], handlers: [:erb] }.freeze

  def find_all(resolver, name = "hello_world", prefix = "test", partial = false, locals = [])
    resolver.find_all(name, prefix, partial, DETAILS, nil, locals)
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
end
