require 'abstract_unit'

class URITest < Test::Unit::TestCase
  def test_uri_decode_handle_multibyte
    str = "\xE6\x97\xA5\xE6\x9C\xAC\xE8\xAA\x9E" # Ni-ho-nn-go in UTF-8,  means Japanese.
    str.force_encoding(Encoding::UTF_8) if(defined? Encoding::UTF_8)

    assert_equal str, ::URI.unescape( ::URI.escape(str) )
    assert_equal str, ::URI.decode( ::URI.escape(str) )
  end
end
