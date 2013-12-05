require 'abstract_unit'

class JsonTest < ActiveSupport::TestCase
  # See activesupport/test/json/encoding_test.rb for JSON encoding tests

  def test_deprecated_require_to_json_rb
    assert_deprecated { require 'active_support/core_ext/object/to_json' }
  end
end
