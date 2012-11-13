# encoding: US-ASCII
require "abstract_unit"
require "logger"

class TestERBTemplate < ActiveSupport::TestCase
  ERBHandler = ActionView::Template::Handlers::ERB.new

  class LookupContext
    def disable_cache
      yield
    end

    def find_template(*args)
    end

    attr_accessor :formats
  end

  class Context
    def initialize
      @output_buffer = "original"
      @virtual_path = nil
    end

    def hello
      "Hello"
    end

    def partial
      ActionView::Template.new(
        "<%= @virtual_path %>",
        "partial",
        ERBHandler,
        :virtual_path => "partial"
      )
    end

    def lookup_context
      @lookup_context ||= LookupContext.new
    end

    def logger
      ActiveSupport::Logger.new(STDERR)
    end

    def my_buffer
      @output_buffer
    end
  end

  def new_template(body = "<%= hello %>", details = {})
    ActionView::Template.new(body, "hello template", details.fetch(:handler) { ERBHandler }, {:virtual_path => "hello"}.merge!(details))
  end

  def render(locals = {})
    @template.render(@context, locals)
  end

  def setup
    @context = Context.new
  end

  def test_mime_type_is_deprecated
    template = new_template
    assert_deprecated 'Template#mime_type is deprecated and will be removed' do
      template.mime_type
    end
  end

  def test_basic_template
    @template = new_template
    assert_equal "Hello", render
  end

  def test_raw_template
    @template = new_template("<%= hello %>", :handler => ActionView::Template::Handlers::Raw.new)
    assert_equal "<%= hello %>", render
  end

  def test_template_loses_its_source_after_rendering
    @template = new_template
    render
    assert_nil @template.source
  end

  def test_template_does_not_lose_its_source_after_rendering_if_it_does_not_have_a_virtual_path
    @template = new_template("Hello", :virtual_path => nil)
    render
    assert_equal "Hello", @template.source
  end

  def test_locals
    @template = new_template("<%= my_local %>")
    @template.locals = [:my_local]
    assert_equal "I am a local", render(:my_local => "I am a local")
  end

  def test_restores_buffer
    @template = new_template
    assert_equal "Hello", render
    assert_equal "original", @context.my_buffer
  end

  def test_virtual_path
    @template = new_template("<%= @virtual_path %>" \
                             "<%= partial.render(self, {}) %>" \
                             "<%= @virtual_path %>")
    assert_equal "hellopartialhello", render
  end

  def test_refresh_with_templates
    @template = new_template("Hello", :virtual_path => "test/foo/bar")
    @template.locals = [:key]
    @context.lookup_context.expects(:find_template).with("bar", %w(test/foo), false, [:key]).returns("template")
    assert_equal "template", @template.refresh(@context)
  end

  def test_refresh_with_partials
    @template = new_template("Hello", :virtual_path => "test/_foo")
    @template.locals = [:key]
    @context.lookup_context.expects(:find_template).with("foo", %w(test), true, [:key]).returns("partial")
    assert_equal "partial", @template.refresh(@context)
  end

  def test_refresh_raises_an_error_without_virtual_path
    @template = new_template("Hello", :virtual_path => nil)
    assert_raise RuntimeError do
      @template.refresh(@context)
    end
  end

  def test_resulting_string_is_utf8
    @template = new_template
    assert_equal Encoding::UTF_8, render.encoding
  end

  def test_no_magic_comment_word_with_utf_8
    @template = new_template("hello \u{fc}mlat")
    assert_equal Encoding::UTF_8, render.encoding
    assert_equal "hello \u{fc}mlat", render
  end

  # This test ensures that if the default_external
  # is set to something other than UTF-8, we don't
  # get any errors and get back a UTF-8 String.
  def test_default_external_works
    with_external_encoding "ISO-8859-1" do
      @template = new_template("hello \xFCmlat")
      assert_equal Encoding::UTF_8, render.encoding
      assert_equal "hello \u{fc}mlat", render
    end
  end

  def test_encoding_can_be_specified_with_magic_comment
    @template = new_template("# encoding: ISO-8859-1\nhello \xFCmlat")
    assert_equal Encoding::UTF_8, render.encoding
    assert_equal "\nhello \u{fc}mlat", render
  end

  # TODO: This is currently handled inside ERB. The case of explicitly
  # lying about encodings via the normal Rails API should be handled
  # inside Rails.
  def test_lying_with_magic_comment
    assert_raises(ActionView::Template::Error) do
      @template = new_template("# encoding: UTF-8\nhello \xFCmlat", :virtual_path => nil)
      render
    end
  end

  def test_encoding_can_be_specified_with_magic_comment_in_erb
    with_external_encoding Encoding::UTF_8 do
      @template = new_template("<%# encoding: ISO-8859-1 %>hello \xFCmlat", :virtual_path => nil)
      assert_equal Encoding::UTF_8, render.encoding
      assert_equal "hello \u{fc}mlat", render
    end
  end

  def test_error_when_template_isnt_valid_utf8
    assert_raises(ActionView::Template::Error, /\xFC/) do
      @template = new_template("hello \xFCmlat", :virtual_path => nil)
      render
    end
  end

  def with_external_encoding(encoding)
    old = Encoding.default_external
    Encoding::Converter.new old, encoding if old != encoding
    silence_warnings { Encoding.default_external = encoding }
    yield
  ensure
    silence_warnings { Encoding.default_external = old }
  end
end
