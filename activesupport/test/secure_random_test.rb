require 'abstract_unit'

class SecureRandomTest < Test::Unit::TestCase
  def test_random_bytes
    b1 = ActiveSupport::SecureRandom.random_bytes(64)
    b2 = ActiveSupport::SecureRandom.random_bytes(64)
    assert_not_equal b1, b2
  end

  def test_hex
    b1 = ActiveSupport::SecureRandom.hex(64)
    b2 = ActiveSupport::SecureRandom.hex(64)
    assert_not_equal b1, b2
  end

  def test_random_number
    assert ActiveSupport::SecureRandom.random_number(5000) < 5000
  end
end
