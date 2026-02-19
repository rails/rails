# frozen_string_literal: true

require "test_helper"

class ActionText::MarkdownConversionTest < ActiveSupport::TestCase
  test "<p> tags are separated by two new lines" do
    assert_converted_to(
      "Hello world!\n\nHow are you?",
      "<p>Hello world!</p><p>How are you?</p>"
    )
  end

  test "<h1> tags produce # prefix" do
    assert_converted_to(
      "# Hello world!\n\nHow are you?",
      "<h1>Hello world!</h1><div>How are you?</div>"
    )
  end

  test "<h2> tags produce ## prefix" do
    assert_converted_to(
      "## Hello world!",
      "<h2>Hello world!</h2>"
    )
  end

  test "<h3> tags produce ### prefix" do
    assert_converted_to(
      "### Hello world!",
      "<h3>Hello world!</h3>"
    )
  end

  test "<h4> tags produce #### prefix" do
    assert_converted_to(
      "#### Hello world!",
      "<h4>Hello world!</h4>"
    )
  end

  test "<h5> tags produce ##### prefix" do
    assert_converted_to(
      "##### Hello world!",
      "<h5>Hello world!</h5>"
    )
  end

  test "<h6> tags produce ###### prefix" do
    assert_converted_to(
      "###### Hello world!",
      "<h6>Hello world!</h6>"
    )
  end

  test "<blockquote> tags produce > prefix" do
    assert_converted_to(
      "> Hello world!",
      "<blockquote>Hello world!</blockquote>"
    )
  end

  test "<blockquote> tags are separated by two new lines" do
    assert_converted_to(
      "> Hello world!\n\n> How are you?",
      "<blockquote>Hello world!</blockquote><blockquote>How are you?</blockquote>"
    )
  end

  test "<blockquote> with multiline content" do
    assert_converted_to(
      "> line one\n> line two",
      "<blockquote>line one<br>line two</blockquote>"
    )
  end

  test "<blockquote> tag with only whitespace" do
    assert_converted_to(
      "",
      "<blockquote> </blockquote>"
    )
  end

  test "<ul> tags use - bullets" do
    assert_converted_to(
      "- one\n- two\n- three",
      "<ul><li>one</li><li>two</li><li>three</li></ul>"
    )
  end

  test "<ol> tags use numbered bullets" do
    assert_converted_to(
      "1. one\n2. two\n3. three",
      "<ol><li>one</li><li>two</li><li>three</li></ol>"
    )
  end

  test "<ol> tags are separated by two new lines" do
    assert_converted_to(
      "Hello world!\n\n1. list1\n\n1. list2\n\nHow are you?",
      "<p>Hello world!</p><ol><li>list1</li></ol><ol><li>list2</li></ol><p>How are you?</p>"
    )
  end

  test "<ul> tags are separated by two new lines" do
    assert_converted_to(
      "Hello world!\n\n- list1\n\n- list2\n\nHow are you?",
      "<p>Hello world!</p><ul><li>list1</li></ul><ul><li>list2</li></ul><p>How are you?</p>"
    )
  end

  test "basic nested <ul> tags are indented" do
    assert_converted_to(
      "- Item 1\n  - Item 2",
      "<ul><li>Item 1<ul><li>Item 2</li></ul></li></ul>"
    )
  end

  test "basic nested <ol> tags are indented" do
    assert_converted_to(
      "1. Item 1\n  1. Item 2",
      "<ol><li>Item 1<ol><li>Item 2</li></ol></li></ol>"
    )
  end

  test "complex nested / mixed list tags are indented" do
    assert_converted_to(
      "- Item 0\n- Item 1\n  - Item A\n    1. Item i\n    2. Item ii\n  - Item B\n    - Item i\n- Item 2",
      "<ul><li>Item 0</li><li>Item 1<ul><li>Item A<ol><li>Item i</li><li>Item ii</li></ol></li><li>Item B<ul><li>Item i</li></ul></li></ul></li><li>Item 2</li></ul>"
    )
  end

  test "<li> tags without a parent list" do
    assert_converted_to(
      "- one\n- two\n- three",
      "<li>one</li><li>two</li><li>three</li>"
    )
  end

  test "<strong> tags produce **bold**" do
    assert_converted_to(
      "**Hello** world!",
      "<div><strong>Hello</strong> world!</div>"
    )
  end

  test "<b> tags produce **bold**" do
    assert_converted_to(
      "**Hello** world!",
      "<div><b>Hello</b> world!</div>"
    )
  end

  test "<em> tags produce *italic*" do
    assert_converted_to(
      "*Hello* world!",
      "<div><em>Hello</em> world!</div>"
    )
  end

  test "<i> tags produce *italic*" do
    assert_converted_to(
      "*Hello* world!",
      "<div><i>Hello</i> world!</div>"
    )
  end

  test "<del> tags produce ~~strikethrough~~" do
    assert_converted_to(
      "~~Hello~~ world!",
      "<div><del>Hello</del> world!</div>"
    )
  end

  test "<s> tags produce ~~strikethrough~~" do
    assert_converted_to(
      "~~Hello~~ world!",
      "<div><s>Hello</s> world!</div>"
    )
  end

  test "<a> tags produce [text](url)" do
    assert_converted_to(
      "[Example](http://example.com/)",
      '<a href="http://example.com/">Example</a>'
    )
  end

  test "<a> tags without href produce plain text" do
    assert_converted_to(
      "Example",
      "<a>Example</a>"
    )
  end

  test "<pre> tags produce fenced code blocks" do
    assert_converted_to(
      "```\nvar x = 1;\n```",
      "<pre>var x = 1;</pre>"
    )
  end

  test "<pre><code> tags produce fenced code blocks" do
    assert_converted_to(
      "```\nvar x = 1;\n```",
      "<pre><code>var x = 1;</code></pre>"
    )
  end

  test "inline <code> tags produce backtick-wrapped text" do
    assert_converted_to(
      "Use `foo` here",
      "<div>Use <code>foo</code> here</div>"
    )
  end

  test "<hr> tags produce horizontal rules" do
    assert_converted_to(
      "Above\n\n---\n\nBelow",
      "<p>Above</p><hr><p>Below</p>"
    )
  end

  test "<br> tags are separated by one new line" do
    assert_converted_to(
      "Hello world!\none\ntwo\nthree",
      "<p>Hello world!<br>one<br>two<br>three</p>"
    )
  end

  test "<div> tags are separated by one new line" do
    assert_converted_to(
      "Hello world!\nHow are you?",
      "<div>Hello world!</div><div>How are you?</div>"
    )
  end

  test "<figcaption> tags are converted to bracketed text" do
    assert_converted_to(
      "Hello world! [A condor in the mountain]",
      "Hello world! <figcaption>A condor in the mountain</figcaption>"
    )
  end

  test "<action-text-attachment> tags are converted to their markdown representation" do
    assert_converted_to(
      "Hello world! ![Cat](http://example.com/cat.jpg)",
      'Hello world! <action-text-attachment url="http://example.com/cat.jpg" content-type="image" caption="Cat"></action-text-attachment>'
    )
  end

  test "nested formatting bold inside italic" do
    assert_converted_to(
      "*Hello **world**!*",
      "<em>Hello <strong>world</strong>!</em>"
    )
  end

  test "deeply nested tags are converted" do
    assert_converted_to(
      "Hello world!\nHow are you?",
      ActionText::Fragment.wrap("<div>Hello world!</div><div></div>").tap do |fragment|
        node = fragment.source.children.last
        10_000.times do
          child = node.clone
          child.parent = node
          node = child
        end
        node.inner_html = "How are you?"
      end
    )
  end

  test "trailing whitespace inside inline formatting is moved outside markers" do
    assert_converted_to(
      "**Hello** world!",
      "<div><strong>Hello </strong>world!</div>"
    )
  end

  test "trailing linebreaks inside inline formatting are moved outside markers" do
    assert_converted_to(
      "**Hello**\nHow are you?",
      "<strong>Hello<br></strong>How are you?"
    )
  end

  test "script tags are ignored" do
    assert_converted_to(
      "**Hello** world!",
      <<~HTML
        <script type="javascript">
          console.log("message");
        </script>
        <div><strong>Hello </strong>world!</div>
      HTML
    )
  end

  test "style tags are ignored" do
    assert_converted_to(
      "**Hello** world!",
      <<~HTML
        <style type="text/css">
          body { color: red; }
        </style>
        <div><strong>Hello </strong>world!</div>
      HTML
    )
  end

  test "special markdown characters in text are escaped" do
    assert_converted_to(
      "Use \\*asterisks\\* and \\_underscores\\_",
      "<p>Use *asterisks* and _underscores_</p>"
    )
  end

  test "backslashes in text are escaped" do
    assert_converted_to(
      "path\\\\to\\\\file",
      "<p>path\\to\\file</p>"
    )
  end

  test "brackets in text are preserved" do
    assert_converted_to(
      "not a [link]",
      "<p>not a [link]</p>"
    )
  end

  private
    def assert_converted_to(markdown, html)
      assert_equal markdown, ActionText::Content.new(html).to_markdown
    end
end
