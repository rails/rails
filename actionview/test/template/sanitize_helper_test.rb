# frozen_string_literal: true

require "abstract_unit"

# The exhaustive tests are in the rails-html-sanitizer gem.
# This tests that the helpers hook up correctly to the sanitizer classes.
class SanitizeHelperTest < ActionView::TestCase
  tests ActionView::Helpers::SanitizeHelper

  def test_strip_links
    assert_equal "Don't touch me", strip_links("Don't touch me")
    assert_equal "on my mind\nall day long", strip_links("<a href='almost'>on my mind</a>\n<A href='almost'>all day long</A>")
    assert_equal "Magic", strip_links("<a href='http://www.rubyonrails.com/'>Mag<a href='http://www.ruby-lang.org/'>ic")
    assert_equal "My mind\nall <b>day</b> long", strip_links("<a href='almost'>My mind</a>\n<A href='almost'>all <b>day</b> long</A>")
    assert_equal "&lt;malformed &amp; link", strip_links('<<a href="https://example.org">malformed & link</a>')
  end

  def test_sanitize_form
    assert_equal "", sanitize("<form action=\"/foo/bar\" method=\"post\"><input></form>")
  end

  def test_should_sanitize_illegal_style_properties
    raw      = %(display:block; position:absolute; left:0; top:0; width:100%; height:100%; z-index:1; background-color:black; background-image:url(http://www.ragingplatypus.com/i/cam-full.jpg); background-x:center; background-y:center; background-repeat:repeat;)
    expected = %r(\Adisplay:\s?block;\s?width:\s?100%;\s?height:\s?100%;\s?background-color:\s?black;\s?background-x:\s?center;\s?background-y:\s?center;\z)
    assert_match expected, sanitize_css(raw)
  end

  def test_strip_tags
    assert_equal("Don't touch me", strip_tags("Don't touch me"))
    assert_equal("This is a test.", strip_tags("<p>This <u>is<u> a <a href='test.html'><strong>test</strong></a>.</p>"))
    assert_equal "This has a  here.", strip_tags("This has a <!-- comment --> here.")
    assert_equal("Jekyll &amp; Hyde", strip_tags("Jekyll & Hyde"))
    assert_equal "", strip_tags("<script>")
  end

  def test_strip_tags_will_not_encode_special_characters
    assert_equal "test\r\n\r\ntest", strip_tags("test\r\n\r\ntest")
  end

  def test_sanitize_is_marked_safe
    assert_predicate sanitize("<html><script></script></html>"), :html_safe?
  end

  def test_sanitized_allowed_tags_class_method
    expected = Set.new(["strong", "em", "b", "i", "p", "code", "pre", "tt", "samp", "kbd", "var",
      "sub", "sup", "dfn", "cite", "big", "small", "address", "hr", "br", "div", "span", "h1", "h2",
      "h3", "h4", "h5", "h6", "ul", "ol", "li", "dl", "dt", "dd", "abbr", "acronym", "a", "img",
      "blockquote", "del", "ins"])
    assert_equal(expected, self.class.sanitized_allowed_tags)
  end

  def test_sanitized_allowed_attributes_class_method
    expected = Set.new(["href", "src", "width", "height", "alt", "cite", "datetime", "title", "class", "name", "xml:lang", "abbr"])
    assert_equal(expected, self.class.sanitized_allowed_attributes)
  end
end
