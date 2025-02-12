# encoding: US-ASCII
# frozen_string_literal: true

require "abstract_unit"

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
      @output_buffer << "original"
      @virtual_path = nil
    end

    def hello
      "Hello"
    end

    def apostrophe
      "l'apostrophe"
    end

    def partial
      ActionView::Template.new(
        "<%= @virtual_path %>",
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
      ActiveSupport::Logger.new(STDERR)
    end

    def my_buffer
      @output_buffer.to_s
    end
  end

  def new_template(body = "<%= hello %>", details = {})
    details = { format: :html, locals: [] }.merge details
    ActionView::Template.new(body.dup, "hello template", details.delete(:handler) || ERBHandler, virtual_path: "hello", **details)
  end

  def render(implicit_locals: [], **locals)
    @template.render(@context, locals, implicit_locals: implicit_locals)
  end

  def spot_highlight(compiled, highlight, first_column: nil, **options)
    # rindex by default since our tests usually put the highlight last
    first_column ||= compiled.byterindex(highlight) || 999
    last_column = first_column + highlight.bytesize
    spot = {
      first_column:, last_column:, snippet: compiled,
      first_lineno: 1, last_lineno: 1, script_lines: compiled.lines,
    }
    spot.merge!(options)
    spot
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
    @template = new_template("<%= @virtual_path %>" \
                             "<%= partial.render(self, {}) %>" \
                             "<%= @virtual_path %>")
    assert_equal "hellopartialhello", render
  end

  def test_rendering_non_string
    my_object = Object.new
    eval_handler = ->(_template, source) { source }
    @template = ActionView::Template.new("my_object", "__id__", eval_handler, virtual_path: "hello", locals: [:my_object])
    result = render(my_object: my_object)
    assert_same my_object, result
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

  def test_locals_can_be_disabled
    error = assert_raises(ActionView::Template::Error) do
      @template = new_template("<%# locals: () -%>")
      render(foo: "bar")
    end

    assert_match(/no locals accepted for hello template/, error.message)
  end

  def test_locals_can_not_be_specified_with_positional_arguments
    error = assert_raises(ActionView::Template::Error) do
      @template = new_template("<%# locals: (foo) -%>")
      render(foo: "bar")
    end

    assert_match(/`foo` set as non-keyword argument/, error.message)
  end

  def test_locals_can_be_specified_with_splat_arguments
    @template = new_template("<%# locals: (**etc) -%><%= etc[:foo] %>")
    assert_equal "bar", render(foo: "bar")
  end

  def test_locals_can_be_specified_with_keyword_and_splat_arguments
    @template = new_template("<%# locals: (id:, **attributes) -%>\n<%= tag.hr(id: id, **attributes) %>")
    assert_equal '<hr id="1" class="h-1">', render(id: 1, class: "h-1")
  end

  def test_locals_cannot_be_specified_with_positional_arguments
    @template = new_template("<%# locals: (argument = 'content') -%>\n<%= argument %>")
    assert_raises ActionView::Template::Error, match: "`argument` set as non-keyword argument for hello template. Locals can only be set as keyword arguments." do
      render
    end
  end

  def test_locals_cannot_be_specified_with_block_arguments
    @template = new_template("<%# locals: (&block) -%>\n<%= tag.div(&block) %>")
    assert_raises ActionView::Template::Error, match: "`block` set as non-keyword argument for hello template. Locals can only be set as keyword arguments." do
      render { "content" }
    end
  end

  def test_locals_can_be_specified
    @template = new_template("<%# locals: (message:) -%>\n<%= message %>")
    assert_equal "Hello", render(message: "Hello")
  end

  def test_default_locals_can_be_specified
    @template = new_template("<%# locals: (message: 'Hello') -%>\n<%= message %>")
    assert_equal "Hello", render
  end

  def test_required_locals_must_be_specified
    error = assert_raises(ActionView::Template::Error) do
      @template = new_template("<%# locals: (message:) -%>")
      render
    end

    assert_match(/missing local: :message for hello template/, error.message)
    assert_instance_of ActionView::StrictLocalsError, error.cause
  end

  def test_extra_locals_raises_strict_locals_error
    error = assert_raises(ActionView::Template::Error) do
      @template = new_template("<%# locals: (message:) -%>")
      render(message: "Hi", foo: "bar")
    end

    assert_match(/unknown local: :foo for hello template/, error.message)
    assert_instance_of ActionView::StrictLocalsError, error.cause
  end

  def test_argument_error_in_the_template_is_not_hijacked_by_strict_locals_checking
    error = assert_raises(ActionView::Template::Error) do
      @template = new_template("<%# locals: () -%>\n<%= hello(:invalid_argument) %>")
      render
    end

    assert_match(/in ['`]hello'/, error.backtrace.first)
    assert_instance_of ArgumentError, error.cause
  end

  def test_rails_injected_locals_does_not_raise_error_if_not_passed
    @template = new_template("<%# locals: (message:) -%>")
    assert_nothing_raised do
      render(message: "Hi", message_counter: 1, message_iteration: 1, implicit_locals: %i[message_counter message_iteration])
    end
  end

  def test_rails_injected_locals_can_be_specified
    @template = new_template("<%# locals: (message: 'Hello') -%>\n<%= message %>")
    assert_equal "Hello", render(message: "Hello", implicit_locals: %i[message])
  end

  def test_rails_local_assigns_and_strict_locals
    @template = new_template("<%# locals: (class: ) -%>\n<%= local_assigns[:class] %>")
    assert_equal "some-class", render(class: "some-class", implicit_locals: %i[message])
  end

  def test_rails_injected_locals_can_be_specified_as_kwargs
    @template = new_template("<%# locals: (message: 'Hello', **kwargs) -%>\n<%= kwargs[:message_counter] %>-<%= kwargs[:message_iteration] %>")
    assert_equal "1-2", render(message: "Hello", message_counter: 1, message_iteration: 2, implicit_locals: %i[message_counter message_iteration])
  end

  def test_rails_injected_locals_can_be_specified_as_required_argument
    @template = new_template("<%# locals: (message: 'Hello', message_iteration:) -%>\n<%= message %>-<%= message_iteration %>")
    assert_equal "Hello-2", render(message: "Hello", message_counter: 1, message_iteration: 2, implicit_locals: %i[message_counter message_iteration])
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

  def test_encoding_and_arguments_can_be_specified_with_magic_comment_in_erb
    with_external_encoding Encoding::UTF_8 do
      @template = new_template("<%# encoding: ISO-8859-1 %>\n<%# locals: (message: 'Hi!') %>\nhello \xFCmlat\n<%= message %>", virtual_path: nil)
      assert_equal Encoding::UTF_8, render.encoding
      assert_match(/hello \u{fc}mlat\nHi!/, render)
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

  def test_template_translate_location
    highlight = "nomethoderror"
    source = "<%= nomethoderror %>"
    compiled = "'.freeze; @output_buffer.append=  nomethoderror ; @output_buffer.safe_append='\n"

    spot = spot_highlight(compiled, highlight)
    expected = spot_highlight(source, highlight, snippet: compiled)

    assert_equal expected, new_template(source).translate_location(nil, spot)
  end

  def test_template_translate_location_with_multiline_code_source
    highlight = "nomethoderror"
    source = "<%=\ngood(\n nomethoderror\n) %>"
    extracted_line = " nomethoderror\n"
    compiled = "ValidatedOutputBuffer.wrap(@output_buffer, ({}), '\ngood(\n nomethoderror\n) '.freeze, true).safe_none_append=(\ngood(\n nomethoderror\n) );\n@output_buffer"

    spot = spot_highlight(compiled, highlight, first_column: 1, first_lineno: 6, last_lineno: 6, snippet: extracted_line)
    expected = spot_highlight(source, highlight, first_column: 1, first_lineno: 3, last_lineno: 3, snippet: extracted_line)

    assert_equal expected, new_template(source).translate_location(nil, spot)
  end

  def test_template_translate_location_with_multibye_string_before_highlight
    highlight = "nope"
    # ensure the byte offset is enough to make us miss the highlight if wrong
    multibyte = String.new("\u{a5}\u{a5}\u{a5}\u{a5}\u{a5}\u{a5}\u{a5}", encoding: Encoding::UTF_8) # yen symbol
    source = "#{multibyte}<%= nope %>"
    compiled = "#{multibyte}'.freeze; @output_buffer.append=  nope ; @output_buffer.safe_append='\n"

    spot = spot_highlight(compiled, highlight)
    expected = spot_highlight(source, highlight, snippet: compiled)

    assert_equal expected, new_template(source).translate_location(nil, spot)
  end

  def test_template_translate_location_no_match_in_compiled
    highlight = "nomatch"
    source = "<%= nomatch %>"
    compiled = "this source does not contain the highlight, so the original spot is returned"

    spot = spot_highlight(compiled, highlight, first_column: 50)

    assert_equal spot, new_template(source).translate_location(nil, spot)
  end

  def test_template_translate_location_text_includes_highlight
    highlight = "nomethoderror"
    source = " nomethoderror <%= nomethoderror %>"
    compiled = " nomethoderror '.freeze; @output_buffer.append=  nomethoderror ; @output_buffer.safe_append='\n"

    spot = spot_highlight(compiled, highlight)
    expected = spot_highlight(source, highlight, snippet: compiled)

    assert_equal expected, new_template(source).translate_location(nil, spot)
  end

  def test_template_translate_location_space_separated_erb_tags
    highlight = "nomethoderror"
    source = "<%= goodcode %> <%= nomethoderror %>"
    compiled = "'.freeze; @output_buffer.append=  goodcode ; @output_buffer.safe_append=' '.freeze; @output_buffer.append=  nomethoderror ; @output_buffer.safe_append='\n"

    spot = spot_highlight(compiled, highlight)
    expected = spot_highlight(source, highlight, snippet: compiled)

    assert_equal expected, new_template(source).translate_location(nil, spot)
  end

  def test_template_translate_location_consecutive_erb_tags
    highlight = "nomethoderror"
    source = "<%= goodcode %><%= nomethoderror %>"
    compiled = "'.freeze; @output_buffer.append=  goodcode ; @output_buffer.append=  nomethoderror ; @output_buffer.safe_append='\n"

    spot = spot_highlight(compiled, highlight)
    expected = spot_highlight(source, highlight, snippet: compiled)

    assert_equal expected, new_template(source).translate_location(nil, spot)
  end

  def test_template_translate_location_repeated_highlight_in_compiled_template
    highlight = "nomethoderror"
    source = "<%= nomethoderror %>"
    compiled = "ValidatedOutputBuffer.wrap(@output_buffer, ({}), ' nomethoderror '.freeze, true).safe_none_append=  nomethoderror ; @output_buffer.safe_append='\n"

    spot = spot_highlight(compiled, highlight)
    expected = spot_highlight(source, highlight, snippet: compiled)

    assert_equal expected, new_template(source).translate_location(nil, spot)
  end

  def test_template_translate_location_flaky_pathological_template
    highlight = "flakymethod"
    source = "<%= flakymethod %> flakymethod <%= flakymethod " # fails on second call, no tailing %>
    compiled = "ValidatedOutputBuffer.wrap(@output_buffer, ({}), ' flakymethod '.freeze, true).safe_none_append=( flakymethod );@output_buffer.safe_append=' flakymethod '.freeze;ValidatedOutputBuffer.wrap(@output_buffer, ({}), ' flakymethod '.freeze, true).safe_none_append=( flakymethod "

    spot = spot_highlight(compiled, highlight)
    expected = spot_highlight(source, highlight, snippet: compiled)

    assert_equal expected, new_template(source).translate_location(nil, spot)
  end
end
