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
  
  def test_from_set
    (0...100).each do | i |
      assert_equal i, SecureRandom.random_from_set(i,'0123456789').length
    end
  end

  def test_unambiguous_code
    (0...100).each do | i |
      assert_equal i, SecureRandom.random_unambiguous_code(i).length
    end
    nums = %w{0 1 2 3 4 5 6 7 8 9}
    (1...5).each do | pass |
      assert SecureRandom.random_unambiguous_code( pass,nums ) !~ /\D/ # it should only contains digits
    end
  end
end
