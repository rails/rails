# frozen_string_literal: true

require "abstract_unit"
require "abstract_controller/rendering"

class LookupContextTest < ActiveSupport::TestCase
  def setup
    @lookup_context = build_lookup_context(FIXTURE_LOAD_PATH, {})
    ActionView::LookupContext::DetailsKey.clear
  end

  def build_lookup_context(paths, details)
    ActionView::LookupContext.new(paths, details)
  end

  def teardown
    I18n.locale = :en
  end

  test "allows to override default_formats with ActionView::Base.default_formats" do
    formats = ActionView::Base.default_formats
    ActionView::Base.default_formats = [:foo, :bar]

    assert_equal [:foo, :bar], ActionView::LookupContext.new([]).default_formats
  ensure
    ActionView::Base.default_formats = formats
  end

  test "process view paths on initialization" do
    assert_kind_of ActionView::PathSet, @lookup_context.view_paths
  end

  test "normalizes details on initialization" do
    assert_equal Mime::SET.to_a, @lookup_context.formats
    assert_equal :en, @lookup_context.locale
  end

  test "allows me to freeze and retrieve frozen formats" do
    @lookup_context.formats.freeze
    assert_predicate @lookup_context.formats, :frozen?
  end

  test "provides getters and setters for variants" do
    @lookup_context.variants = [:mobile]
    assert_equal [:mobile], @lookup_context.variants
  end

  test "provides getters and setters for formats" do
    @lookup_context.formats = [:html]
    assert_equal [:html], @lookup_context.formats
  end

  test "handles */* formats" do
    @lookup_context.formats = ["*/*"]
    assert_equal Mime::SET.to_a, @lookup_context.formats
  end

  test "handles explicitly defined */* formats fallback to :js" do
    @lookup_context.formats = [:js, Mime::ALL]
    assert_equal [:js, *Mime::SET.symbols].uniq, @lookup_context.formats
  end

  test "adds :html fallback to :js formats" do
    @lookup_context.formats = [:js]
    assert_equal [:js, :html], @lookup_context.formats
  end

  test "raises on invalid format assignment" do
    ex = assert_raises ArgumentError do
      @lookup_context.formats = [:html, :invalid, "also bad"]
    end

    assert_equal 'Invalid formats: :invalid, "also bad"', ex.message
  end

  test "provides getters and setters for locale" do
    @lookup_context.locale = :pt
    assert_equal :pt, @lookup_context.locale
  end

  test "changing lookup_context locale, changes I18n.locale" do
    @lookup_context.locale = :pt
    assert_equal :pt, I18n.locale
  end

  test "delegates changing the locale to the I18n configuration object if it contains a lookup_context object" do
    begin
      I18n.config = ActionView::I18nProxy.new(I18n.config, @lookup_context)
      @lookup_context.locale = :pt
      assert_equal :pt, I18n.locale
      assert_equal :pt, @lookup_context.locale
    ensure
      I18n.config = I18n.config.original_config
    end

    assert_equal :pt, I18n.locale
  end

  test "find templates using the given view paths and configured details" do
    template = @lookup_context.find("hello_world", %w(test))
    assert_equal "Hello world!", template.source

    @lookup_context.locale = :da
    template = @lookup_context.find("hello_world", %w(test))
    assert_equal "Hey verden", template.source
  end

  test "find templates with given variants" do
    @lookup_context.formats  = [:html]
    @lookup_context.variants = [:phone]

    template = @lookup_context.find("hello_world", %w(test))
    assert_equal "Hello phone!", template.source

    @lookup_context.variants = [:phone]
    @lookup_context.formats  = [:text]

    template = @lookup_context.find("hello_world", %w(test))
    assert_equal "Hello texty phone!", template.source
  end

  test "found templates have nil format if one cannot be found from template or handler" do
    assert_called(ActionView::Template::Handlers::Builder, :default_format, returns: nil) do
      @lookup_context.formats = [:text]
      template = @lookup_context.find("hello", %w(test))
      assert_nil template.format
    end
  end

  test "generates a new details key for each details hash" do
    keys = []
    keys << @lookup_context.details_key
    assert_equal 1, keys.uniq.size

    @lookup_context.locale = :da
    keys << @lookup_context.details_key
    assert_equal 2, keys.uniq.size

    @lookup_context.locale = :en
    keys << @lookup_context.details_key
    assert_equal 2, keys.uniq.size

    @lookup_context.formats = [:html]
    keys << @lookup_context.details_key
    assert_equal 3, keys.uniq.size

    @lookup_context.formats = nil
    keys << @lookup_context.details_key
    assert_equal 3, keys.uniq.size
  end

  test "uses details as part of cache key" do
    fixtures = {
      "test/_foo.erb" => "Foo",
      "test/_foo.da.erb" => "Bar",
    }
    @lookup_context = build_lookup_context(ActionView::FixtureResolver.new(fixtures), {})

    template = @lookup_context.find("foo", %w(test), true)
    original_template = template
    assert_equal "Foo", template.source

    # We should get the same template
    template = @lookup_context.find("foo", %w(test), true)
    assert_same original_template, template

    # Using a different locale we get a different view
    @lookup_context.locale = :da
    template = @lookup_context.find("foo", %w(test), true)
    assert_equal "Bar", template.source

    # Using en we get the original view
    @lookup_context.locale = :en
    template = @lookup_context.find("foo", %w(test), true)
    assert_same original_template, template
  end

  test "can disable the cache on demand" do
    @lookup_context = build_lookup_context(ActionView::FixtureResolver.new("test/_foo.erb" => "Foo"), {})
    old_template = @lookup_context.find("foo", %w(test), true)

    template = @lookup_context.find("foo", %w(test), true)
    assert_equal template, old_template

    assert @lookup_context.cache
    template = @lookup_context.disable_cache do
      assert_not @lookup_context.cache
      @lookup_context.find("foo", %w(test), true)
    end
    assert @lookup_context.cache

    assert_not_equal template, old_template
  end

  test "responds to #prefixes" do
    assert_equal [], @lookup_context.prefixes
    @lookup_context.prefixes = ["foo"]
    assert_equal ["foo"], @lookup_context.prefixes
  end
end

class TestMissingTemplate < ActiveSupport::TestCase
  def setup
    @lookup_context = ActionView::LookupContext.new("/Path/to/views", {})
  end

  test "if no template was found we get a helpful error message including the inheritance chain" do
    e = assert_raise ActionView::MissingTemplate do
      @lookup_context.find("foo", %w(parent child))
    end
    assert_match %r{Missing template parent/foo, child/foo with .*\n\nSearched in:\n  \* "/Path/to/views"\n}, e.message
  end

  test "if no partial was found we get a helpful error message including the inheritance chain" do
    e = assert_raise ActionView::MissingTemplate do
      @lookup_context.find("foo", %w(parent child), true)
    end
    assert_match %r{Missing partial parent/_foo, child/_foo with .*\n\nSearched in:\n  \* "/Path/to/views"\n}, e.message
  end

  test "if a single prefix is passed as a string and the lookup fails, MissingTemplate accepts it" do
    e = assert_raise ActionView::MissingTemplate do
      details = { handlers: [], formats: [], variants: [], locale: [] }
      @lookup_context.view_paths.find("foo", "parent", true, details)
    end
    assert_match %r{Missing partial parent/_foo with .*\n\nSearched in:\n  \* "/Path/to/views"\n}, e.message
  end
end
