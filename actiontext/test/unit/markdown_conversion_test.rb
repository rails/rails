# frozen_string_literal: true

require "test_helper"

class ActionText::MarkdownConversionTest < ActiveSupport::TestCase
  test "plain text passes through unchanged" do
    assert_converted_to(
      "hello world",
      "hello world"
    )
  end

  test "<strong> tags are converted to bold" do
    assert_converted_to("**hello**", "<strong>hello</strong>")
  end

  test "<b> tags are converted to bold" do
    assert_converted_to("**hello**", "<b>hello</b>")
  end

  test "<em> tags are converted to italic" do
    assert_converted_to("*hello*", "<em>hello</em>")
  end

  test "<i> tags are converted to italic" do
    assert_converted_to("*hello*", "<i>hello</i>")
  end

  test "<s> tags are converted to strikethrough" do
    assert_converted_to("~~hello~~", "<s>hello</s>")
  end

  test "<code> tags are converted to inline code" do
    assert_converted_to("`hello`", "<code>hello</code>")
  end

  test "nested <strong> and <em> tags produce bold italic" do
    assert_converted_to("***hello***", "<strong><em>hello</em></strong>")
  end

  test "redundant nested <b> and <strong> tags do not double-bold" do
    assert_converted_to("**hello**", "<b><strong>hello</strong></b>")
  end

  test "<strong> with inner whitespace moves spaces outside markers" do
    assert_converted_to("a **hello** b", "<p>a<strong> hello </strong>b</p>")
  end

  test "<em> with inner whitespace moves spaces outside markers" do
    assert_converted_to("a *hello* b", "<p>a<em> hello </em>b</p>")
  end

  test "<b> wrapping <code> wrapping <strong> collapses to bold code" do
    assert_converted_to("**`asdf`**", "<b><code><strong>asdf</strong></code></b>")
  end

  test "adjacent <b> spans are merged" do
    assert_converted_to(
      "aaa **`bb` or `cc`** ddd",
      "<p>aaa <b><code><strong>bb</strong></code></b><b><strong> or </strong></b><b><code><strong>cc</strong></code></b> ddd</p>"
    )
  end

  test "adjacent <i> spans are merged" do
    assert_converted_to(
      "*`foo` and `bar`*",
      "<p><i><code><em>foo</em></code></i><i><em> and </em></i><i><code><em>bar</em></code></i></p>"
    )
  end

  test "adjacent bold+italic spans are merged" do
    assert_converted_to(
      "***`foo`** **and** **`bar`***",
      "<p><i><b><code><strong>foo</strong></code></b></i><i><b><strong> and </strong></b></i><i><b><code><strong>bar</strong></code></b></i></p>"
    )
  end

  test "<p> tags are separated by two new lines" do
    assert_converted_to(
      "hello\n\nworld",
      "<p>hello</p><p>world</p>"
    )
  end

  test "<h1> through <h6> tags are converted to heading markers" do
    assert_converted_to("# hello", "<h1>hello</h1>")
    assert_converted_to("## hello", "<h2>hello</h2>")
    assert_converted_to("### hello", "<h3>hello</h3>")
    assert_converted_to("#### hello", "<h4>hello</h4>")
    assert_converted_to("##### hello", "<h5>hello</h5>")
    assert_converted_to("###### hello", "<h6>hello</h6>")
  end

  test "<blockquote> tags are converted to quoted lines" do
    assert_converted_to("> hello", "<blockquote>hello</blockquote>")
  end

  test "<blockquote> with multiple lines prefixes each line" do
    assert_converted_to(
      "> line1\n> line2",
      "<blockquote>line1\nline2</blockquote>"
    )
  end

  test "nested <blockquote> tags produce nested quotes" do
    assert_converted_to(
      "> this is a quote\n> > of a quote",
      "<blockquote>this is a quote<blockquote>of a quote</blockquote></blockquote>"
    )
  end

  test "<br> tags are converted to newlines" do
    assert_converted_to("hello\nworld", "hello<br>world")
  end

  test "<hr> tags are converted to thematic breaks" do
    assert_converted_to("---", "<hr>")
  end

  test "<pre> tags are converted to fenced code blocks" do
    assert_converted_to("```\nhello\n```", "<pre>hello</pre>")
  end

  test "<pre> with nested <code> tag is converted to fenced code block" do
    assert_converted_to("```\nhello\n```", "<pre><code>hello</code></pre>")
  end

  test "<pre> followed by <p> has blank line separator" do
    assert_converted_to(
      "```\nhello\n```\n\nworld",
      "<pre>hello</pre><p>world</p>"
    )
  end

  test "<ul> tags are converted to unordered lists" do
    assert_converted_to(
      "before\n\n- one\n- two\n- three\n\nafter",
      "<p>before</p><ul><li>one</li><li>two</li><li>three</li></ul><p>after</p>"
    )
  end

  test "<ol> tags are converted to ordered lists" do
    assert_converted_to(
      "before\n\n1. one\n2. two\n3. three\n\nafter",
      "<p>before</p><ol><li>one</li><li>two</li><li>three</li></ol><p>after</p>"
    )
  end

  test "empty <li> tags are skipped" do
    assert_converted_to(
      "before\n\n- real\n\nafter",
      "<p>before</p><ul><li></li><li>real</li></ul><p>after</p>"
    )
  end

  test "nested <ul> tags are indented" do
    assert_converted_to(
      "- one\n  - nested\n- two",
      "<ul><li>one<ul><li>nested</li></ul></li><li>two</li></ul>"
    )
  end

  test "nested <ul> where sublist is in its own <li>" do
    assert_converted_to(
      "- top 1\n- top 2\n  - nested 1\n  - nested 2",
      <<~HTML
        <ul>
          <li>top 1</li>
          <li>top 2</li>
          <li>
            <ul>
              <li>nested 1</li>
              <li>nested 2</li>
            </ul>
          </li>
        </ul>
      HTML
    )
  end

  test "<ul> followed by <p> has blank line separator" do
    assert_converted_to(
      "- Item 1\n  - Subitem\n- Item 2\n\nParagraph",
      <<~HTML
        <ul>
          <li>Item 1</li>
          <li>
            <ul>
              <li>Subitem</li>
            </ul>
          </li>
          <li>Item 2</li>
        </ul>
        <p>Paragraph</p>
      HTML
    )
  end

  test "<a> tags are converted to links" do
    assert_converted_to(
      "[click here](https://example.com)",
      '<a href="https://example.com">click here</a>'
    )
  end

  test "<a> tags with formatting inside" do
    assert_converted_to(
      "[**bold link**](https://example.com)",
      '<a href="https://example.com"><strong>bold link</strong></a>'
    )
  end

  test "<a> tags without href pass through content" do
    assert_converted_to("**click here**", "<a><strong>click here</strong></a>")
  end

  test "<a> tags with mailto: href are converted to links" do
    assert_converted_to("[email](mailto:test@example.com)", '<a href="mailto:test@example.com">email</a>')
  end

  test "<a> tags with tel: href are converted to links" do
    assert_converted_to("[call](tel:+1234567890)", '<a href="tel:+1234567890">call</a>')
  end

  test "<a> tags with relative href are converted to links" do
    assert_converted_to("[page](/about)", '<a href="/about">page</a>')
  end

  test "<a> tags with relative href containing colons are converted to links" do
    assert_converted_to("[notes](/docs/v1:notes)", '<a href="/docs/v1:notes">notes</a>')
  end

  test "<a> tags with javascript: href pass through content without link" do
    assert_converted_to("click here", '<a href="javascript:alert(1)">click here</a>')
  end

  test "<table> with <thead> is converted to markdown table" do
    assert_converted_to(
      "| Name | Age |\n| --- | --- |\n| Alice | 30 |",
      <<~HTML
        <table>
          <thead><tr><th>Name</th><th>Age</th></tr></thead>
          <tbody><tr><td>Alice</td><td>30</td></tr></tbody>
        </table>
      HTML
    )
  end

  test "<table> cells with formatting" do
    assert_converted_to(
      "| **bold** | *italic* |",
      "<table><tr><td><strong>bold</strong></td><td><em>italic</em></td></tr></table>"
    )
  end

  test "<table> without <thead>" do
    assert_converted_to(
      "| a | b |\n| c | d |",
      "<table><tr><td>a</td><td>b</td></tr><tr><td>c</td><td>d</td></tr></table>"
    )
  end

  test "<table> with <th> headers in <tbody>" do
    assert_converted_to(
      "| a | b | c |\n| --- | --- | --- |\n| 1 | asdf | asdf |\n| 2 | asdf | asdf |",
      "<table><tbody><tr><th><p>a</p></th><th><p>b</p></th><th><p>c</p></th></tr><tr><th><p>1</p></th><td><p>asdf</p></td><td><p>asdf</p></td></tr><tr><th><p>2</p></th><td><p>asdf</p></td><td><p>asdf</p></td></tr></tbody></table>"
    )
  end

  test "<details> and <summary> are converted" do
    assert_converted_to(
      "**Click to expand**\n\nHidden content",
      "<details><summary>Click to expand</summary>Hidden content</details>"
    )
  end

  test "empty content" do
    assert_converted_to("", "")
  end

  test "leading and trailing whitespace is stripped" do
    assert_converted_to("hello", "<p>  hello  </p>")
  end

  test "HTML entities are decoded" do
    assert_converted_to(
      "asdf < asdf & asdf > asdf",
      "<p>asdf &lt; asdf &amp; asdf &gt; asdf</p>"
    )
  end

  test "unknown elements pass through their content" do
    assert_converted_to("hello", "<asdf>hello</asdf>")
  end

  test "<div> passes through content" do
    assert_converted_to("hello", "<div>  hello  </div>")
  end

  test "<span> passes through content" do
    assert_converted_to("hello", "<span>  hello  </span>")
  end

  test "<script> tags are ignored" do
    assert_converted_to(
      "hello",
      <<~HTML
        <script type="javascript">
          console.log("message");
        </script>
        <div>hello</div>
      HTML
    )
  end

  test "<style> tags are ignored" do
    assert_converted_to(
      "hello",
      <<~HTML
        <style type="text/css">
          body { color: red; }
        </style>
        <div>hello</div>
      HTML
    )
  end

  test "image attachment with caption is converted to markdown image" do
    assert_converted_to(
      "![A photo](https://example.com/photo.png)",
      '<action-text-attachment content-type="image/png" url="https://example.com/photo.png" caption="A photo"></action-text-attachment>'
    )
  end

  test "image attachment without caption falls back to Image alt text" do
    assert_converted_to(
      "![Image](https://example.com/photo.jpg)",
      '<action-text-attachment content-type="image/jpeg" url="https://example.com/photo.jpg" filename="photo.jpg"></action-text-attachment>'
    )
  end

  test "content attachment HTML is converted to markdown" do
    assert_converted_to(
      "**hello**",
      '<action-text-attachment content-type="text/html" content="<strong>hello</strong>"></action-text-attachment>'
    )

    assert_converted_to(
      "**hello**",
      '<action-text-attachment content-type="text/html" content="&lt;strong&gt;hello&lt;/strong&gt;"></action-text-attachment>'
    )
  end

  test "attachment with surrounding text" do
    assert_converted_to(
      "Hello world! ![Cat](http://example.com/cat.jpg)",
      'Hello world! <action-text-attachment url="http://example.com/cat.jpg" content-type="image/jpeg" caption="Cat"></action-text-attachment>'
    )
  end

  test "ActiveStorage blob attachment is converted to markdown with caption" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    html = %Q(<action-text-attachment sgid="#{blob.attachable_sgid}" caption="Captioned"></action-text-attachment>)
    assert_equal "[Captioned]", ActionText::Content.new(html).to_markdown
  end

  test "ActiveStorage blob attachment without caption uses filename" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    html = %Q(<action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
    assert_equal "[racecar.jpg]", ActionText::Content.new(html).to_markdown
  end

  test "missing attachable is converted to ☒" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    html = %Q(<action-text-attachment sgid="#{blob.attachable_sgid}"></action-text-attachment>)
    blob.destroy!
    assert_equal "☒", ActionText::Content.new(html).to_markdown
  end

  test "RichText#to_markdown" do
    assert_equal "**hello**", ActionText::RichText.new(body: "<p><strong>hello</strong></p>").to_markdown
  end

  test "RichText#to_markdown handles blank body" do
    assert_equal "", ActionText::RichText.new(body: "").to_markdown
  end

  test "RichText#to_markdown handles nil body" do
    assert_equal "", ActionText::RichText.new(body: nil).to_markdown
  end

  test "multiple attachments separated by whitespace preserve the whitespace" do
    assert_converted_to(
      "![A](https://example.com/a.jpg) ![B](https://example.com/b.jpg)",
      '<action-text-attachment content-type="image/jpeg" url="https://example.com/a.jpg" caption="A"></action-text-attachment> <action-text-attachment content-type="image/jpeg" url="https://example.com/b.jpg" caption="B"></action-text-attachment>'
    )
  end


  test "Fragment#to_markdown memoizes the result" do
    fragment = ActionText::Fragment.from_html("<p><strong>hello</strong></p>")
    assert_same fragment.to_markdown, fragment.to_markdown
  end

  private
    def assert_converted_to(expected_markdown, html)
      assert_equal expected_markdown, ActionText::Content.new(html).to_markdown
    end
end
