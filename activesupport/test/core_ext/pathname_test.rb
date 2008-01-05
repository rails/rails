require 'abstract_unit'

class TestPathname < Test::Unit::TestCase
  def test_clean_within
    assert_equal "Hi", Pathname.clean_within("Hi")
    assert_equal "Hi", Pathname.clean_within("Hi/a/b/../..")
    assert_equal "Hello\nWorld", Pathname.clean_within("Hello/a/b/../..\na/b/../../World/c/..")
  end
end
