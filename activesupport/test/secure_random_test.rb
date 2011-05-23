require 'abstract_unit'
require 'active_support/testing/deprecation'

class SecureRandomTest < Test::Unit::TestCase
  include ActiveSupport::Testing::Deprecation

  def test_deprecated
    assert_deprecated do
      ActiveSupport::SecureRandom.hex
    end
  end
end
