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

  def test_freeze_keeps_non_strict_templates_renderable
    with_file "test/_card.html.erb", "<%= post %>"
    resolver = ActionView::FileSystemResolver.new(tmpdir)
    resolver.eager_load_templates(compile_view)
    resolver.freeze

    assert_ractor_shareable resolver

    template = find_all(resolver, "card", "test", true, [:post])[0]
    assert_not_predicate template, :frozen?
    assert_equal "hello", template.render(compile_view, { post: "hello" })
  end

  def test_frozen_non_strict_templates_are_cached_per_locals
    with_file "test/_card.html.erb", "<%= post %>"
    resolver = ActionView::FileSystemResolver.new(tmpdir)
    resolver.eager_load_templates(compile_view)
    resolver.freeze

    a = find_all(resolver, "card", "test", true, [:post])[0]
    b = find_all(resolver, "card", "test", true, [:post])[0]
    c = find_all(resolver, "card", "test", true, [:post, :other])[0]
    d = find_all(resolver, "card", "test", true, [:other, :post])[0]

    assert_same a, b
    assert_not_same a, c
    assert_same c, d
  end

  def test_strict_locals_templates_bind_once_for_any_locals
    with_file "test/hello_world.html.erb", "<%# locals: () %>Hi"
    resolver = ActionView::FileSystemResolver.new(tmpdir)
    key = ActionView::TemplateDetails::Requested.new(**DETAILS)

    a = resolver.find_all("hello_world", "test", false, DETAILS, key, [])[0]
    b = resolver.find_all("hello_world", "test", false, DETAILS, key, [:extra])[0]

    assert_same a, b
    assert_equal [a], resolver.built_templates
  end

  def test_frozen_resolver_returns_empty_for_missing_template
    with_file "test/hello_world.html.erb", "<%# locals: () %>Hi"
    resolver = ActionView::FileSystemResolver.new(tmpdir)
    resolver.eager_load_templates(compile_view)
    resolver.freeze

    assert_empty find_all(resolver, "nonexistent")
  end
end

class FileSystemResolverRactorTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  include ActiveSupport::Testing::RactorsAssertions

  # Compiling methods into FakeView from another Ractor is how frozen non-strict templates
  # are compiled in a ractorized application, with the view class container built in the
  # main Ractor and other Ractors compiling methods into it. This might stop working with
  # https://bugs.ruby-lang.org/issues/22226, which would require compiling into a
  # Ractor-local container instead.
  class FakeView
    def compiled_method_container
      self.class
    end

    def _run(method, template, locals, buffer, add_to_stack:, has_strict_locals:, &block)
      @output_buffer = buffer
      public_send(method, locals, buffer, &block)
    end
  end

  test "non-strict templates compile inside a non-main Ractor" do
    Dir.mktmpdir do |dir|
      Dir.mkdir(File.join(dir, "test"))
      File.write(File.join(dir, "test", "_card.html.erb"), "<%= post %>")

      Mime.eager_load!
      ActionView::Template::Handlers::ERB.escape_ignore_list.freeze

      # Make sure subscriptions are Ractor-shareable
      ActiveSupport::Ractors.unshareable_proc_action = :raise
      # Nothing subscribes after, so record manually
      ActiveSupport::Notifications.send(:record_subscriptions)

      resolver = ActionView::FileSystemResolver.new(dir)
      resolver.eager_load_templates
      resolver.freeze

      rendered = on_ractor(resolver) do |resolver|
        details = { locale: [:en].freeze, formats: [:html].freeze, variants: [].freeze, handlers: [:erb].freeze }.freeze
        template = resolver.find_all("card", "test", true, details, nil, [:post])[0]
        template.render(FakeView.new, { post: "hello" })
      end

      assert_equal "hello", rendered
    end
  end
end
