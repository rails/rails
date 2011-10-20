require 'abstract_unit'
require 'active_support/core_ext/securerandom'

class SecureRandomTest < Test::Unit::TestCase
  def test_uuid
    assert_match(/\w{8}-\w{4}-\w{4}-\w{4}-\w{12}/, SecureRandom.uuid)
  end
end
