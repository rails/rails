require 'abstract_unit'
require 'testing_sandbox'

# The exhaustive tests are in test/controller/html/sanitizer_test.rb.
# This tests the that the helpers hook up correctly to the sanitizer classes.
class SanitizeHelperTest < ActionView::TestCase
  tests ActionView::Helpers::SanitizeHelper
  include TestingSandbox

  def test_strip_links
    assert_equal "Dont touch me", strip_links("Dont touch me")
    assert_equal "<a<a", strip_links("<a<a")
    assert_equal "on my mind\nall day long", strip_links("<a href='almost'>on my mind</a>\n<A href='almost'>all day long</A>")
    assert_equal "0wn3d", strip_links("<a href='http://www.rubyonrails.com/'><a href='http://www.rubyonrails.com/' onlclick='steal()'>0wn3d</a></a>") 
    assert_equal "Magic", strip_links("<a href='http://www.rubyonrails.com/'>Mag<a href='http://www.ruby-lang.org/'>ic") 
    assert_equal "FrrFox", strip_links("<href onlclick='steal()'>FrrFox</a></href>") 
    assert_equal "My mind\nall <b>day</b> long", strip_links("<a href='almost'>My mind</a>\n<A href='almost'>all <b>day</b> long</A>")
    assert_equal "all <b>day</b> long", strip_links("<<a>a href='hello'>all <b>day</b> long<</A>/a>")
  end

  def test_sanitize_form
    assert_sanitized "<form action=\"/foo/bar\" method=\"post\"><input></form>", ''
  end

  def test_should_sanitize_illegal_style_properties
    raw      = %(display:block; position:absolute; left:0; top:0; width:100%; height:100%; z-index:1; background-color:black; background-image:url(http://www.ragingplatypus.com/i/cam-full.jpg); background-x:center; background-y:center; background-repeat:repeat;)
    expected = %(display: block; width: 100%; height: 100%; background-color: black; background-image: ; background-x: center; background-y: center;)
    assert_equal expected, sanitize_css(raw)
  end

  def test_strip_tags
    assert_equal("<<<bad html", strip_tags("<<<bad html"))
    assert_equal("<<", strip_tags("<<<bad html>"))
    assert_equal("Dont touch me", strip_tags("Dont touch me"))
    assert_equal("This is a test.", strip_tags("<p>This <u>is<u> a <a href='test.html'><strong>test</strong></a>.</p>"))
    assert_equal("Weirdos", strip_tags("Wei<<a>a onclick='alert(document.cookie);'</a>/>rdos"))
    assert_equal("This is a test.", strip_tags("This is a test."))
    assert_equal(
    %{This is a test.\n\n\nIt no longer contains any HTML.\n}, strip_tags(
    %{<title>This is <b>a <a href="" target="_blank">test</a></b>.</title>\n\n<!-- it has a comment -->\n\n<p>It no <b>longer <strong>contains <em>any <strike>HTML</strike></em>.</strong></b></p>\n}))
    assert_equal "This has a  here.", strip_tags("This has a <!-- comment --> here.")
    [nil, '', '   '].each { |blank| assert_equal blank, strip_tags(blank) }
  end

  def assert_sanitized(text, expected = nil)
    assert_equal((expected || text), sanitize(text))
  end
end
