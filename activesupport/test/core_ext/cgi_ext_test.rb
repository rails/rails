require 'abstract_unit'
require 'active_support/core_ext/cgi'

class EscapeSkippingSlashesTest < Test::Unit::TestCase
  def test_array
    assert_equal 'hello/world', CGI.escape_skipping_slashes(%w(hello world))
    assert_equal 'hello+world/how/are/you', CGI.escape_skipping_slashes(['hello world', 'how', 'are', 'you'])
  end

  def test_typical
    assert_equal 'hi', CGI.escape_skipping_slashes('hi')
    assert_equal 'hi/world', CGI.escape_skipping_slashes('hi/world')
    assert_equal 'hi/world+you+funky+thing', CGI.escape_skipping_slashes('hi/world you funky thing')
  end
end
