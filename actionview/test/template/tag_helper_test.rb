# frozen_string_literal: true

require "abstract_unit"

class TagHelperTest < ActionView::TestCase
  include RenderERBUtils

  tests ActionView::Helpers::TagHelper

  COMMON_DANGEROUS_CHARS = "&<>\"' %*+,/;=^|"
  INVALID_TAG_CHARS = "> /"

  def test_tag
    assert_equal "<br />", tag("br")
    assert_equal "<br clear=\"left\" />", tag(:br, clear: "left")
    assert_equal "<br>", tag("br", nil, true)
  end

  def test_tag_builder
    assert_equal "<span></span>", tag.span
    assert_equal "<span class=\"bookmark\"></span>", tag.span(class: "bookmark")
  end

  def test_tag_builder_void_tag
    assert_equal "<br>", tag.br
    assert_equal "<br class=\"some_class\">", tag.br(class: "some_class")
  end

  def test_tag_builder_void_tag_with_forced_content
    assert_raises(ArgumentError) do
      tag.br("some content")
    end
  end

  def test_tag_builder_void_tag_with_empty_content
    assert_raises(ArgumentError) do
      tag.br("")
    end
  end

  def test_tag_builder_self_closing_tag
    assert_equal "<svg><use href=\"#cool-icon\" /></svg>", tag.svg { tag.use("href" => "#cool-icon") }
    assert_equal "<svg><circle cx=\"5\" cy=\"5\" r=\"5\" /></svg>", tag.svg { tag.circle(cx: "5", cy: "5", r: "5") }
    assert_equal "<animateMotion dur=\"10s\" repeatCount=\"indefinite\" />", tag.animate_motion(dur: "10s", repeatCount: "indefinite")
  end

  def test_tag_builder_self_closing_tag_with_content
    assert_equal "<svg><circle r=\"5\"><desc>A circle</desc></circle></svg>", tag.svg { tag.circle(r: "5") { tag.desc "A circle" } }
  end

  def test_tag_builder_defines_methods_to_build_html_elements
    assert_respond_to tag, :div
    assert_includes tag.public_methods, :div
  end

  def test_tag_builder_renders_unknown_html_elements
    assert_respond_to tag, :turbo_frame

    assert_equal "<turbo-frame id=\"rendered\">Rendered</turbo-frame>", tag.turbo_frame("Rendered", id: "rendered")
  end

  def test_tag_builder_is_singleton
    assert_equal tag, tag
  end

  def test_tag_options
    str = tag("p", "class" => "show", :class => "elsewhere")
    assert_match(/class="show"/, str)
    assert_match(/class="elsewhere"/, str)
  end

  def test_tag_options_with_array_of_numeric
    str = tag(:input, value: [123, 456])

    assert_equal("<input value=\"123 456\" />", str)
  end

  def test_tag_options_with_array_of_random_objects
    klass = Class.new do
      def to_s
        "hello"
      end
    end

    str = tag(:input, value: [klass.new])

    assert_equal("<input value=\"hello\" />", str)
  end

  def test_tag_options_rejects_nil_option
    assert_equal "<p />", tag("p", ignored: nil)
  end

  def test_tag_builder_options_rejects_nil_option
    assert_equal "<p></p>", tag.p(ignored: nil)
  end

  def test_tag_options_accepts_false_option
    assert_equal "<p value=\"false\" />", tag("p", value: false)
  end

  def test_tag_builder_options_accepts_false_option
    assert_equal "<p value=\"false\"></p>", tag.p(value: false)
  end

  def test_tag_options_accepts_blank_option
    assert_equal "<p included=\"\" />", tag("p", included: "")
  end

  def test_tag_builder_options_accepts_blank_option
    assert_equal "<p included=\"\"></p>", tag.p(included: "")
  end

  def test_tag_options_accepts_symbol_option_when_not_escaping
    assert_equal "<p value=\"symbol\" />", tag("p", { value: :symbol }, false, false)
  end

  def test_tag_options_accepts_integer_option_when_not_escaping
    assert_equal "<p value=\"42\" />", tag("p", { value: 42 }, false, false)
  end

  def test_tag_options_converts_boolean_option
    assert_dom_equal '<p disabled="disabled" itemscope="itemscope" multiple="multiple" readonly="readonly" allowfullscreen="allowfullscreen" seamless="seamless" typemustmatch="typemustmatch" sortable="sortable" default="default" inert="inert" truespeed="truespeed" allowpaymentrequest="allowpaymentrequest" nomodule="nomodule" playsinline="playsinline" />',
      tag("p", disabled: true, itemscope: true, multiple: true, readonly: true, allowfullscreen: true, seamless: true, typemustmatch: true, sortable: true, default: true, inert: true, truespeed: true, allowpaymentrequest: true, nomodule: true, playsinline: true)
  end

  def test_tag_builder_options_converts_boolean_option
    assert_dom_equal '<p disabled="disabled" itemscope="itemscope" multiple="multiple" readonly="readonly" allowfullscreen="allowfullscreen" seamless="seamless" typemustmatch="typemustmatch" sortable="sortable" default="default" inert="inert" truespeed="truespeed" allowpaymentrequest="allowpaymentrequest" nomodule="nomodule" playsinline="playsinline" />',
      tag.p(disabled: true, itemscope: true, multiple: true, readonly: true, allowfullscreen: true, seamless: true, typemustmatch: true, sortable: true, default: true, inert: true, truespeed: true, allowpaymentrequest: true, nomodule: true, playsinline: true)
  end

  def test_tag_builder_with_options_builds_p_elements
    html = tag.with_options(id: "with-options") { |t| t.p("content") }

    assert_dom_equal '<p id="with-options">content</p>', html
  end

  def test_tag_builder_do_not_modify_html_safe_options
    html_safe_str = '"'.html_safe
    assert_equal "<p value=\"&quot;\" />", tag("p", value: html_safe_str)
    assert_equal '"', html_safe_str
    assert_predicate html_safe_str, :html_safe?
  end

  def test_tag_with_dangerous_name
    INVALID_TAG_CHARS.each_char do |char|
      tag_name = "asdf-#{char}"
      assert_raise(ArgumentError, "expected #{tag_name.inspect} to be invalid") do
        tag(tag_name)
      end
    end
  end

  def test_tag_builder_with_dangerous_name
    INVALID_TAG_CHARS.each_char do |char|
      tag_name = "asdf-#{char}".to_sym
      assert_raise(ArgumentError, "expected #{tag_name.inspect} to be invalid") do
        tag.public_send(tag_name)
      end
    end
  end

  def test_tag_with_dangerous_aria_attribute_name
    escaped_dangerous_chars = "_" * COMMON_DANGEROUS_CHARS.size
    assert_equal "<the-name aria-#{escaped_dangerous_chars}=\"the value\" />",
                 tag("the-name", aria: { COMMON_DANGEROUS_CHARS => "the value" })

    assert_equal "<the-name aria-#{COMMON_DANGEROUS_CHARS}=\"the value\" />",
                 tag("the-name", { aria: { COMMON_DANGEROUS_CHARS => "the value" } }, false, false)
  end

  def test_tag_builder_with_dangerous_aria_attribute_name
    escaped_dangerous_chars = "_" * COMMON_DANGEROUS_CHARS.size
    assert_equal "<the-name aria-#{escaped_dangerous_chars}=\"the value\"></the-name>",
                 tag.public_send(:"the-name", aria: { COMMON_DANGEROUS_CHARS => "the value" })

    assert_equal "<the-name aria-#{COMMON_DANGEROUS_CHARS}=\"the value\"></the-name>",
                 tag.public_send(:"the-name", aria: { COMMON_DANGEROUS_CHARS => "the value" }, escape: false)
  end

  def test_tag_with_dangerous_data_attribute_name
    escaped_dangerous_chars = "_" * COMMON_DANGEROUS_CHARS.size
    assert_equal "<the-name data-#{escaped_dangerous_chars}=\"the value\" />",
                 tag("the-name", data: { COMMON_DANGEROUS_CHARS => "the value" })

    assert_equal "<the-name data-#{COMMON_DANGEROUS_CHARS}=\"the value\" />",
                 tag("the-name", { data: { COMMON_DANGEROUS_CHARS => "the value" } }, false, false)
  end

  def test_tag_builder_with_dangerous_data_attribute_name
    escaped_dangerous_chars = "_" * COMMON_DANGEROUS_CHARS.size
    assert_equal "<the-name data-#{escaped_dangerous_chars}=\"the value\"></the-name>",
                 tag.public_send(:"the-name", data: { COMMON_DANGEROUS_CHARS => "the value" })

    assert_equal "<the-name data-#{COMMON_DANGEROUS_CHARS}=\"the value\"></the-name>",
                 tag.public_send(:"the-name", data: { COMMON_DANGEROUS_CHARS => "the value" }, escape: false)
  end

  def test_tag_with_dangerous_unknown_attribute_name
    escaped_dangerous_chars = "_" * COMMON_DANGEROUS_CHARS.size
    assert_equal "<the-name #{escaped_dangerous_chars}=\"the value\" />",
                 tag("the-name", COMMON_DANGEROUS_CHARS => "the value")

    assert_equal "<the-name #{COMMON_DANGEROUS_CHARS}=\"the value\" />",
                 tag("the-name", { COMMON_DANGEROUS_CHARS => "the value" }, false, false)
  end

  def test_tag_builder_with_dangerous_unknown_attribute_name
    escaped_dangerous_chars = "_" * COMMON_DANGEROUS_CHARS.size
    assert_equal "<the-name #{escaped_dangerous_chars}=\"the value\"></the-name>",
                 tag.public_send(:"the-name", COMMON_DANGEROUS_CHARS => "the value")

    assert_equal "<the-name #{COMMON_DANGEROUS_CHARS}=\"the value\"></the-name>",
                 tag.public_send(:"the-name", COMMON_DANGEROUS_CHARS => "the value", escape: false)
  end

  def test_content_tag
    assert_equal "<a href=\"create\">Create</a>", content_tag("a", "Create", "href" => "create")
    assert_predicate content_tag("a", "Create", "href" => "create"), :html_safe?
    assert_equal content_tag("a", "Create", "href" => "create"),
                 content_tag("a", "Create", href: "create")
    assert_equal "<p>&lt;script&gt;evil_js&lt;/script&gt;</p>",
                 content_tag(:p, "<script>evil_js</script>")
    assert_equal "<p><script>evil_js</script></p>",
                 content_tag(:p, "<script>evil_js</script>", nil, false)
    assert_equal "<div @click=\"triggerNav()\">test</div>",
                 content_tag(:div, "test", "@click": "triggerNav()")
  end

  def test_tag_builder_with_content
    assert_equal "<div id=\"post_1\">Content</div>", tag.div("Content", id: "post_1")
    assert_predicate tag.div("Content", id: "post_1"), :html_safe?
    assert_equal tag.div("Content", id: "post_1"),
                 tag.div("Content", "id": "post_1")
    assert_equal "<p>&lt;script&gt;evil_js&lt;/script&gt;</p>",
                 tag.p("<script>evil_js</script>")
    assert_equal "<p><script>evil_js</script></p>",
                 tag.p("<script>evil_js</script>", escape: false)
    assert_equal '<input pattern="\w+">', tag.input(pattern: /\w+/)
  end

  def test_tag_builder_nested
    assert_equal "<div>content</div>",
                 tag.div { "content" }
    assert_equal "<div id=\"header\"><span>hello</span></div>",
                 tag.div(id: "header") { |tag| tag.span "hello" }
    assert_equal "<div id=\"header\"><div class=\"world\"><span>hello</span></div></div>",
                 tag.div(id: "header") { |tag| tag.div(class: "world") { tag.span "hello" } }
  end

  def test_content_tag_with_block_in_erb
    buffer = render_erb("<%= content_tag(:div) do %>Hello world!<% end %>")
    assert_dom_equal "<div>Hello world!</div>", buffer
  end

  def test_tag_builder_with_block_in_erb
    buffer = render_erb("<%= tag.div do %>Hello world!<% end %>")
    assert_dom_equal "<div>Hello world!</div>", buffer
  end

  def test_content_tag_with_block_in_erb_containing_non_displayed_erb
    buffer = render_erb("<%= content_tag(:p) do %><% 1 %><% end %>")
    assert_dom_equal "<p></p>", buffer
  end

  def test_tag_builder_with_block_in_erb_containing_non_displayed_erb
    buffer = render_erb("<%= tag.p do %><% 1 %><% end %>")
    assert_dom_equal "<p></p>", buffer
  end

  def test_content_tag_with_block_and_options_in_erb
    buffer = render_erb("<%= content_tag(:div, :class => 'green') do %>Hello world!<% end %>")
    assert_dom_equal %(<div class="green">Hello world!</div>), buffer
  end

  def test_tag_builder_with_block_and_options_in_erb
    buffer = render_erb("<%= tag.div(class: 'green') do %>Hello world!<% end %>")
    assert_dom_equal %(<div class="green">Hello world!</div>), buffer
  end

  def test_content_tag_with_block_and_options_out_of_erb
    assert_dom_equal %(<div class="green">Hello world!</div>), content_tag(:div, class: "green") { "Hello world!" }
  end

  def test_tag_builder_with_block_and_options_out_of_erb
    assert_dom_equal %(<div class="green">Hello world!</div>), tag.div(class: "green") { "Hello world!" }
  end

  def test_content_tag_with_block_and_options_outside_out_of_erb
    assert_equal content_tag("a", "Create", href: "create"),
                 content_tag("a", "href" => "create") { "Create" }
  end

  def test_tag_builder_with_block_and_options_outside_out_of_erb
    assert_equal tag.a("Create", href: "create"),
                 tag.a("href": "create") { "Create" }
  end

  def test_content_tag_with_block_and_non_string_outside_out_of_erb
    assert_equal content_tag("p"),
                 content_tag("p") { 3.times { "do_something" } }
  end

  def test_tag_builder_with_block_and_non_string_outside_out_of_erb
    assert_equal tag.p,
                 tag.p { 3.times { "do_something" } }
  end

  def test_content_tag_nested_in_content_tag_out_of_erb
    assert_equal content_tag("p", content_tag("b", "Hello")),
                 content_tag("p") { content_tag("b", "Hello") },
                 output_buffer
    assert_equal tag.p(tag.b("Hello")),
                 tag.p { tag.b("Hello") },
                 output_buffer
  end

  def test_content_tag_nested_in_content_tag_in_erb
    assert_equal "<p>\n  <b>Hello</b>\n</p>", view.render("test/content_tag_nested_in_content_tag")
    assert_equal "<p>\n  <b>Hello</b>\n</p>", view.render("test/builder_tag_nested_in_content_tag")
  end

  def test_content_tag_nested_in_content_tag_with_data_attributes_out_of_erb
    assert_equal "<div data-controller=\"read-more\" data-read-more-more-text-value=\"Read more\" data-read-more-less-text-value=\"Read less\"\>\n  <p class=\"content-class\" data-test-name=\"content\">Content text</p>\n  <button class=\"expand-button\" data-action=\"read-more#toggle\">Read more</button>\n</div>",
                  view.render("test/content_tag_nested_in_content_tag_with_data_attributes_out_of_erb")
  end

  def test_content_tag_with_escaped_array_class
    str = content_tag("p", "limelight", class: ["song", "play>"])
    assert_equal "<p class=\"song play&gt;\">limelight</p>", str

    str = content_tag("p", "limelight", class: ["song", "play"])
    assert_equal "<p class=\"song play\">limelight</p>", str

    str = content_tag("p", "limelight", class: ["song", ["play"]])
    assert_equal "<p class=\"song play\">limelight</p>", str
  end

  def test_tag_builder_with_escaped_array_class
    str = tag.p "limelight", class: ["song", "play>"]
    assert_equal "<p class=\"song play&gt;\">limelight</p>", str

    str = tag.p "limelight", class: ["song", "play"]
    assert_equal "<p class=\"song play\">limelight</p>", str

    str = tag.p "limelight", class: ["song", ["play"]]
    assert_equal "<p class=\"song play\">limelight</p>", str
  end

  def test_content_tag_with_unescaped_array_class
    str = content_tag("p", "limelight", { class: ["song", "play>"] }, false)
    assert_equal "<p class=\"song play>\">limelight</p>", str

    str = content_tag("p", "limelight", { class: ["song", ["play>"]] }, false)
    assert_equal "<p class=\"song play>\">limelight</p>", str
  end

  def test_tag_builder_with_unescaped_array_class
    str = tag.p "limelight", class: ["song", "play>"], escape: false
    assert_equal "<p class=\"song play>\">limelight</p>", str

    str = tag.p "limelight", class: ["song", ["play>"]], escape: false
    assert_equal "<p class=\"song play>\">limelight</p>", str
  end

  def test_content_tag_with_empty_array_class
    str = content_tag("p", "limelight", class: [])
    assert_equal '<p class="">limelight</p>', str
  end

  def test_tag_builder_with_empty_array_class
    assert_equal '<p class="">limelight</p>', tag.p("limelight", class: [])
  end

  def test_content_tag_with_unescaped_empty_array_class
    str = content_tag("p", "limelight", { class: [] }, false)
    assert_equal '<p class="">limelight</p>', str
  end

  def test_tag_builder_with_unescaped_empty_array_class
    str = tag.p "limelight", class: [], escape: false
    assert_equal '<p class="">limelight</p>', str
  end

  def test_content_tag_with_conditional_hash_classes
    str = content_tag("p", "limelight", class: { "song": true, "play": false })
    assert_equal "<p class=\"song\">limelight</p>", str

    str = content_tag("p", "limelight", class: [{ "song": true }, { "play": false }])
    assert_equal "<p class=\"song\">limelight</p>", str

    str = content_tag("p", "limelight", class: { song: true, play: false })
    assert_equal "<p class=\"song\">limelight</p>", str

    str = content_tag("p", "limelight", class: [{ song: true }, nil, false])
    assert_equal "<p class=\"song\">limelight</p>", str

    str = content_tag("p", "limelight", class: ["song", { foo: false }])
    assert_equal "<p class=\"song\">limelight</p>", str

    str = content_tag("p", "limelight", class: [1, 2, 3])
    assert_equal "<p class=\"1 2 3\">limelight</p>", str

    klass = Class.new do
      def to_s
        "1"
      end
    end

    str = content_tag("p", "limelight", class: [klass.new])
    assert_equal "<p class=\"1\">limelight</p>", str

    str = content_tag("p", "limelight", class: { "song": true, "play": true })
    assert_equal "<p class=\"song play\">limelight</p>", str

    str = content_tag("p", "limelight", class: { "song": false, "play": false })
    assert_equal '<p class="">limelight</p>', str
  end

  def test_tag_builder_with_conditional_hash_classes
    str = tag.p "limelight", class: { "song": true, "play": false }
    assert_equal "<p class=\"song\">limelight</p>", str

    str = tag.p "limelight", class: [{ "song": true }, { "play": false }]
    assert_equal "<p class=\"song\">limelight</p>", str

    str = tag.p "limelight", class: { song: true, play: false }
    assert_equal "<p class=\"song\">limelight</p>", str

    str = tag.p "limelight", class: [{ song: true }, nil, false]
    assert_equal "<p class=\"song\">limelight</p>", str

    str = tag.p "limelight", class: ["song", { foo: false }]
    assert_equal "<p class=\"song\">limelight</p>", str

    str = tag.p "limelight", class: { "song": true, "play": true }
    assert_equal "<p class=\"song play\">limelight</p>", str

    str = tag.p "limelight", class: { "song": false, "play": false }
    assert_equal '<p class="">limelight</p>', str
  end

  def test_content_tag_with_unescaped_conditional_hash_classes
    str = content_tag("p", "limelight", { class: { "song": true, "play>": true } }, false)
    assert_equal "<p class=\"song play>\">limelight</p>", str

    str = content_tag("p", "limelight", { class: ["song", { "play>": true }] }, false)
    assert_equal "<p class=\"song play>\">limelight</p>", str
  end

  def test_content_tag_with_invalid_html_tag
    invalid_tags = ["12p", "", "image file", "div/", "my>element", "_header"]
    invalid_tags.each do |tag_name|
      assert_raise(ArgumentError, "expected #{tag_name.inspect} to be invalid") do
        content_tag(tag_name)
      end
    end
  end

  def test_tag_with_invalid_html_tag
    invalid_tags = ["12p", "", "image file", "div/", "my>element", "_header"]
    invalid_tags.each do |tag_name|
      assert_raise(ArgumentError, "expected #{tag_name.inspect} to be invalid") do
        tag(tag_name)
      end
    end
  end

  def test_tag_builder_with_unescaped_conditional_hash_classes
    str = tag.p "limelight", class: { "song": true, "play>": true }, escape: false
    assert_equal "<p class=\"song play>\">limelight</p>", str

    str = tag.p "limelight", class: ["song", { "play>": true }], escape: false
    assert_equal "<p class=\"song play>\">limelight</p>", str
  end

  def test_token_list_and_class_names
    [:token_list, :class_names].each do |helper_method|
      helper = ->(*arguments) { public_send(helper_method, *arguments) }

      assert_equal "song play", helper.(["song", { "play": true }])
      assert_equal "song", helper.({ "song": true, "play": false })
      assert_equal "song", helper.([{ "song": true }, { "play": false }])
      assert_equal "song", helper.({ song: true, play: false })
      assert_equal "song", helper.([{ song: true }, nil, false])
      assert_equal "song", helper.(["song", { foo: false }])
      assert_equal "song play", helper.({ "song": true, "play": true })
      assert_equal "", helper.({ "song": false, "play": false })
      assert_equal "123", helper.(nil, "", false, 123, { "song": false, "play": false })
      assert_equal "song", helper.("song", "song")
      assert_equal "song", helper.("song song")
      assert_equal "song", helper.("song\nsong")
    end
  end

  def test_token_list_and_class_names_returns_an_html_safe_string
    assert_predicate token_list("a value"), :html_safe?
    assert_predicate class_names("a value"), :html_safe?
  end

  def test_token_list_and_class_names_only_html_escape_once
    [:token_list, :class_names].each do |helper_method|
      helper = ->(*arguments) { public_send(helper_method, *arguments) }

      tokens = %w[
        click->controller#action1
        click->controller#action2
        click->controller#action3
        click->controller#action4
      ]

      token_list = tokens.reduce(&helper)

      assert_predicate token_list, :html_safe?
      assert_equal tokens, (CGI.unescape_html(token_list)).split
    end
  end

  def test_content_tag_with_data_attributes
    assert_dom_equal '<p data-number="1" data-string="hello" data-string-with-quotes="double&quot;quote&quot;party&quot;">limelight</p>',
      content_tag("p", "limelight", data: { number: 1, string: "hello", string_with_quotes: 'double"quote"party"' })
  end

  def test_tag_builder_with_data_attributes
    assert_dom_equal '<p data-number="1" data-string="hello" data-string-with-quotes="double&quot;quote&quot;party&quot;">limelight</p>',
      tag.p("limelight", data: { number: 1, string: "hello", string_with_quotes: 'double"quote"party"' })
  end

  def test_cdata_section
    assert_equal "<![CDATA[<hello world>]]>", cdata_section("<hello world>")
  end

  def test_cdata_section_with_string_conversion
    assert_equal "<![CDATA[]]>", cdata_section(nil)
  end

  def test_cdata_section_splitted
    assert_equal "<![CDATA[hello]]]]><![CDATA[>world]]>", cdata_section("hello]]>world")
    assert_equal "<![CDATA[hello]]]]><![CDATA[>world]]]]><![CDATA[>again]]>", cdata_section("hello]]>world]]>again")
  end

  def test_escape_once
    assert_equal "1 &lt; 2 &amp; 3", escape_once("1 < 2 &amp; 3")
    assert_equal " &#X27; &#x27; &#x03BB; &#X03bb; &quot; &#39; &lt; &gt; ", escape_once(" &#X27; &#x27; &#x03BB; &#X03bb; \" ' < > ")
  end

  def test_tag_attributes_inlines_html_attributes
    expected_output = <<~HTML.strip
      <input type="text" name="name" aria-hidden="false" aria-label="label" data-input-value="data" required="required">
    HTML

    assert_equal expected_output, render_erb(<<~HTML.strip)
      <input type="text" <%= tag.attributes value: nil, name: "name", "aria-hidden": false, aria: { label: "label" }, data: { input_value: "data" }, required: true %>>
    HTML
  end

  def test_tag_attributes_escapes_values
    expected_output = <<~HTML.strip
      <input type="text" xss="&quot;&gt;&lt;script&gt;alert()&lt;/script&gt;">
    HTML

    assert_equal expected_output, render_erb(<<~HTML.strip)
      <input type="text" <%= tag.attributes xss: '"><script>alert()</script>' %>>
    HTML
  end

  def test_tag_attributes_nil
    assert_equal %(<input type="text" >), render_erb(%(<input type="text" <%= tag.attributes nil %>>))
  end

  def test_tag_attributes_empty
    assert_equal %(<input type="text" >), render_erb(%(<input type="text" <%= tag.attributes({}) %>>))
  end

  def test_tag_honors_html_safe_for_param_values
    ["1&amp;2", "1 &lt; 2", "&#8220;test&#8220;"].each do |escaped|
      assert_equal %(<a href="#{escaped}" />), tag("a", href: escaped.html_safe)
      assert_equal %(<a href="#{escaped}"></a>), tag.a(href: escaped.html_safe)
    end
  end

  def test_tag_honors_html_safe_with_escaped_array_class
    assert_equal '<p class="song&gt; play>" />', tag("p", class: ["song>", raw("play>")])
    assert_equal '<p class="song> play&gt;" />', tag("p", class: [raw("song>"), "play>"])
  end

  def test_tag_builder_honors_html_safe_with_escaped_array_class
    assert_equal '<p class="song&gt; play>"></p>', tag.p(class: ["song>", raw("play>")])
    assert_equal '<p class="song> play&gt;"></p>', tag.p(class: [raw("song>"), "play>"])
  end

  def test_tag_does_not_honor_html_safe_double_quotes_as_attributes
    assert_dom_equal '<p title="&quot;">content</p>',
      content_tag("p", "content", title: '"'.html_safe)
  end

  def test_data_tag_does_not_honor_html_safe_double_quotes_as_attributes
    assert_dom_equal '<p data-title="&quot;">content</p>',
      content_tag("p", "content", data: { title: '"'.html_safe })
  end

  def test_skip_invalid_escaped_attributes
    ["&1;", "&#1dfa3;", "& #123;"].each do |escaped|
      assert_equal %(<a href="#{escaped.gsub(/&/, '&amp;')}" />), tag("a", href: escaped)
      assert_equal %(<a href="#{escaped.gsub(/&/, '&amp;')}"></a>), tag.a(href: escaped)
    end
  end

  def test_disable_escaping
    assert_equal '<a href="&amp;" />', tag("a", { href: "&amp;" }, false, false)
  end

  def test_tag_builder_disable_escaping
    assert_equal '<a href="&amp;"></a>', tag.a(href: "&amp;", escape: false)
    assert_equal '<a href="&amp;">cnt</a>', tag.a(href: "&amp;", escape: false) { "cnt" }
    assert_equal '<br data-hidden="&amp;">', tag.br("data-hidden": "&amp;", escape: false)
    assert_equal '<a href="&amp;">content</a>', tag.a("content", href: "&amp;", escape: false)
    assert_equal '<a href="&amp;">content</a>', tag.a(href: "&amp;", escape: false) { "content" }
  end

  def test_data_attributes
    ["data", :data].each { |data|
      assert_dom_equal '<a data-a-float="3.14" data-a-big-decimal="-123.456" data-a-number="1" data-array="[1,2,3]" data-hash="{&quot;key&quot;:&quot;value&quot;}" data-string-with-quotes="double&quot;quote&quot;party&quot;" data-string="hello" data-symbol="foo" />',
        tag("a", data => { a_float: 3.14, a_big_decimal: BigDecimal("-123.456"), a_number: 1, string: "hello", symbol: :foo, array: [1, 2, 3], hash: { key: "value" }, string_with_quotes: 'double"quote"party"' })
      assert_dom_equal '<a data-a-float="3.14" data-a-big-decimal="-123.456" data-a-number="1" data-array="[1,2,3]" data-hash="{&quot;key&quot;:&quot;value&quot;}" data-string-with-quotes="double&quot;quote&quot;party&quot;" data-string="hello" data-symbol="foo" />',
        tag.a(data: { a_float: 3.14, a_big_decimal: BigDecimal("-123.456"), a_number: 1, string: "hello", symbol: :foo, array: [1, 2, 3], hash: { key: "value" }, string_with_quotes: 'double"quote"party"' })
    }
  end

  def test_aria_attributes
    ["aria", :aria].each { |aria|
      assert_dom_equal '<a aria-a-float="3.14" aria-a-big-decimal="-123.456" aria-a-number="1" aria-truthy="true" aria-falsey="false" aria-array="1 2 3" aria-hash="a b" aria-tokens="a b" aria-string-with-quotes="double&quot;quote&quot;party&quot;" aria-string="hello" aria-symbol="foo" />',
        tag("a", aria => { nil: nil, a_float: 3.14, a_big_decimal: BigDecimal("-123.456"), a_number: 1, truthy: true, falsey: false, string: "hello", symbol: :foo, array: [1, 2, 3], empty_array: [], hash: { a: true, b: "truthy", falsey: false, nil: nil }, empty_hash: {}, tokens: ["a", { b: true, c: false }], empty_tokens: [{ a: false }], string_with_quotes: 'double"quote"party"' })
    }

    assert_dom_equal '<a aria-a-float="3.14" aria-a-big-decimal="-123.456" aria-a-number="1" aria-truthy="true" aria-falsey="false" aria-array="1 2 3" aria-hash="a b" aria-tokens="a b" aria-string-with-quotes="double&quot;quote&quot;party&quot;" aria-string="hello" aria-symbol="foo" />',
    tag.a(aria: { nil: nil, a_float: 3.14, a_big_decimal: BigDecimal("-123.456"), a_number: 1, truthy: true, falsey: false, string: "hello", symbol: :foo, array: [1, 2, 3], empty_array: [], hash: { a: true, b: "truthy", falsey: false, nil: nil }, empty_hash: {}, tokens: ["a", { b: true, c: false }], empty_tokens: [{ a: false }], string_with_quotes: 'double"quote"party"' })
  end

  def test_link_to_data_nil_equal
    div_type1 = content_tag(:div, "test", "data-tooltip" => nil)
    div_type2 = content_tag(:div, "test", data: { tooltip: nil })
    assert_dom_equal div_type1, div_type2
  end

  def test_tag_builder_link_to_data_nil_equal
    div_type1 = tag.div "test", 'data-tooltip': nil
    div_type2 = tag.div "test", data: { tooltip: nil }
    assert_dom_equal div_type1, div_type2
  end

  def test_tag_builder_allow_call_via_method_object
    assert_equal "<foo></foo>", tag.method(:foo).call
  end

  def test_tag_builder_dasherize_names
    assert_equal "<img-slider></img-slider>", tag.img_slider
  end

  def test_respond_to
    assert_respond_to tag, :any_tag
  end
end
