# frozen_string_literal: true

require "abstract_unit"

class OutputSafetyHelperTest < ActionView::TestCase
  tests ActionView::Helpers::OutputSafetyHelper

  def setup
    @string = "hello"
  end

  test "raw returns the safe string" do
    result = raw(@string)
    assert_equal @string, result
    assert_predicate result, :html_safe?
  end

  test "raw handles nil values correctly" do
    assert_equal "", raw(nil)
  end

  test "safe_join should html_escape any items, including the separator, if they are not html_safe" do
    joined = safe_join([raw("<p>foo</p>"), "<p>bar</p>"], "<br />")
    assert_equal "<p>foo</p>&lt;br /&gt;&lt;p&gt;bar&lt;/p&gt;", joined

    joined = safe_join([raw("<p>foo</p>"), raw("<p>bar</p>")], raw("<br />"))
    assert_equal "<p>foo</p><br /><p>bar</p>", joined
  end

  test "safe_join should work recursively similarly to Array.join" do
    joined = safe_join(["a", ["b", "c"]], ":")
    assert_equal "a:b:c", joined

    joined = safe_join(['"a"', ["<b>", "<c>"]], " <br/> ")
    assert_equal "&quot;a&quot; &lt;br/&gt; &lt;b&gt; &lt;br/&gt; &lt;c&gt;", joined
  end

  test "safe_join should return the safe string separated by $, when second argument is not passed" do
    default_delimiter = $,

    begin
      $, = nil
      joined = safe_join(["a", "b"])
      assert_equal "ab", joined

      silence_warnings do
        $, = "|"
      end
      joined = safe_join(["a", "b"])
      assert_equal "a|b", joined
    ensure
      $, = default_delimiter
    end
  end

  test "to_sentence should escape non-html_safe values" do
    actual = to_sentence(%w(< > & ' "))
    assert_predicate actual, :html_safe?
    assert_equal("&lt;, &gt;, &amp;, &#39;, and &quot;", actual)

    actual = to_sentence(%w(<script>))
    assert_predicate actual, :html_safe?
    assert_equal("&lt;script&gt;", actual)
  end

  test "to_sentence does not double escape if single value is html_safe" do
    assert_equal("&lt;script&gt;", to_sentence([ERB::Util.html_escape("<script>")]))
    assert_equal("&lt;script&gt;", to_sentence(["&lt;script&gt;".html_safe]))
    assert_equal("&amp;lt;script&amp;gt;", to_sentence(["&lt;script&gt;"]))
  end

  test "to_sentence connector words are checked for HTML safety" do
    assert_equal "one & two, and three", to_sentence(["one", "two", "three"], words_connector: " & ".html_safe)
    assert_equal "one & two", to_sentence(["one", "two"], two_words_connector: " & ".html_safe)
    assert_equal "one, two &lt;script&gt;alert(1)&lt;/script&gt; three", to_sentence(["one", "two", "three"], last_word_connector: " <script>alert(1)</script> ")
  end

  test "to_sentence should not escape html_safe values" do
    ptag = content_tag("p") do
      safe_join(["<marquee>shady stuff</marquee>", tag("br")])
    end
    url = "https://example.com"
    expected = %(<a href="#{url}">#{url}</a> and <p>&lt;marquee&gt;shady stuff&lt;/marquee&gt;<br /></p>)
    actual = to_sentence([link_to(url, url), ptag])
    assert_predicate actual, :html_safe?
    assert_equal(expected, actual)
  end

  test "to_sentence handles blank strings" do
    actual = to_sentence(["", "two", "three"])
    assert_predicate actual, :html_safe?
    assert_equal ", two, and three", actual
  end

  test "to_sentence handles nil values" do
    actual = to_sentence([nil, "two", "three"])
    assert_predicate actual, :html_safe?
    assert_equal ", two, and three", actual
  end

  test "to_sentence still supports ActiveSupports Array#to_sentence arguments" do
    assert_equal "one two, and three", to_sentence(["one", "two", "three"], words_connector: " ")
    assert_equal "one & two, and three", to_sentence(["one", "two", "three"], words_connector: " & ".html_safe)
    assert_equal "onetwo, and three", to_sentence(["one", "two", "three"], words_connector: nil)
    assert_equal "one, two, and also three", to_sentence(["one", "two", "three"], last_word_connector: ", and also ")
    assert_equal "one, twothree", to_sentence(["one", "two", "three"], last_word_connector: nil)
    assert_equal "one, two three", to_sentence(["one", "two", "three"], last_word_connector: " ")
    assert_equal "one, two and three", to_sentence(["one", "two", "three"], last_word_connector: " and ")
  end

  test "to_sentence is not affected by $," do
    separator_was = $,
    silence_warnings do
      $, = "|"
    end
    begin
      assert_equal "one and two", to_sentence(["one", "two"])
      assert_equal "one, two, and three", to_sentence(["one", "two", "three"])
    ensure
      $, = separator_was
    end
  end
end
