# encoding: US-ASCII
# frozen_string_literal: true

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

  class Context < ActionView::Base
    def initialize(*)
      super
      @output_buffer = "original"
    end

    def hello
      "Hello"
    end

    def apostrophe
      "l'apostrophe"
    end

    def partial
      ActionView::Template.new(
        "<%= @current_template.virtual_path %>",
        "partial",
        ERBHandler,
        virtual_path: "partial",
        format: :html,
        locals: []
      )
    end

    def lookup_context
      @lookup_context ||= LookupContext.new
    end

    def logger
      ActiveSupport::Logger.new($stderr)
    end

    def my_buffer
      @output_buffer
    end
  end

  def new_template(body = "<%= hello %>", details = {})
    details = { format: :html, locals: [] }.merge details
    ActionView::Template.new(body.dup, "hello template", details.delete(:handler) || ERBHandler, **{ virtual_path: "hello" }.merge!(details))
  end

  def render(locals = {})
    @template.render(@context, locals)
  end

  def setup
    @context = Context.with_empty_template_cache.empty
    super
  end

  def test_basic_template
    @template = new_template
    assert_equal "Hello", render
  end

  def test_basic_template_does_html_escape
    @template = new_template("<%= apostrophe %>")
    assert_equal "l&#39;apostrophe", render
  end

  def test_text_template_does_not_html_escape
    @template = new_template("<%= apostrophe %> <%== apostrophe %>", format: :text)
    assert_equal "l'apostrophe l'apostrophe", render
  end

  def test_raw_template
    @template = new_template("<%= hello %>", handler: ActionView::Template::Handlers::Raw.new)
    assert_equal "<%= hello %>", render
  end

  def test_template_does_not_lose_its_source_after_rendering
    @template = new_template
    render
    assert_equal "<%= hello %>", @template.source
  end

  def test_template_does_not_lose_its_source_after_rendering_if_it_does_not_have_a_virtual_path
    @template = new_template("Hello", virtual_path: nil)
    render
    assert_equal "Hello", @template.source
  end

  def test_locals
    @template = new_template("<%= my_local %>", locals: [:my_local])
    assert_equal "I am a local", render(my_local: "I am a local")
  end

  def test_restores_buffer
    @template = new_template
    assert_equal "Hello", render
    assert_equal "original", @context.my_buffer
  end

  def test_virtual_path
    @template = new_template("<%= @current_template.virtual_path %>" \
                             "<%= partial.render(self, {}) %>" \
                             "<%= @current_template.virtual_path %>")
    assert_equal "hellopartialhello", render
  end

  def test_refresh_is_deprecated
    @template = new_template("Hello", virtual_path: "test/foo/bar", locals: [:key])
    assert_deprecated do
      assert_same @template, @template.refresh(@context)
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
      @template = new_template("# encoding: UTF-8\nhello \xFCmlat", virtual_path: nil)
      render
    end
  end

  def test_encoding_can_be_specified_with_magic_comment_in_erb
    with_external_encoding Encoding::UTF_8 do
      @template = new_template("<%# encoding: ISO-8859-1 %>hello \xFCmlat", virtual_path: nil)
      assert_equal Encoding::UTF_8, render.encoding
      assert_equal "hello \u{fc}mlat", render
    end
  end

  def test_error_when_template_isnt_valid_utf8
    e = assert_raises ActionView::Template::Error do
      @template = new_template("hello \xFCmlat", virtual_path: nil)
      render
    end
    # Hack: We write the regexp this way because the parser of RuboCop
    # errs with /\xFC/.
    assert_match(Regexp.new("\xFC"), e.message)
  end

  def test_template_is_marshalable
    template = new_template
    serialized = Marshal.load(Marshal.dump(template))
    assert_equal template.identifier, serialized.identifier
    assert_equal template.source, serialized.source
  end

  def with_external_encoding(encoding)
    old = Encoding.default_external
    Encoding::Converter.new old, encoding if old != encoding
    silence_warnings { Encoding.default_external = encoding }
    yield
  ensure
    silence_warnings { Encoding.default_external = old }
  end

  def test_short_identifier
    @template = new_template("hello")
    assert_equal "hello template", @template.short_identifier
  end

  def test_template_inspect
    @template = new_template("hello")
    assert_equal "#<ActionView::Template hello template locals=[]>", @template.inspect
  end
end
