require 'abstract_unit'
require 'active_support/core_ext/securerandom'

class SecureRandomTest < ActiveSupport::TestCase
  def test_base58
    s1 = SecureRandom.base58
    s2 = SecureRandom.base58

    assert_not_equal s1, s2
    assert_equal 16, s1.length
  end

  def test_base58_with_length
    s1 = SecureRandom.base58(24)
    s2 = SecureRandom.base58(24)

    assert_not_equal s1, s2
    assert_equal 24, s1.length
  end

  def test_base58_minimum_length
    assert_equal '', SecureRandom.base58(0)
    assert_raise(ArgumentError) { SecureRandom.base58(-1) }
  end

  def test_base58_charset
    base58_alphabet = ('0'..'9').to_a + ('A'..'Z').to_a + ('a'..'z').to_a - ['0', 'O', 'I', 'l']
    assert_equal 58, base58_alphabet.uniq.size

    s = SecureRandom.base58(1000)

    s.each_char do |c|
      assert_includes base58_alphabet, c
    end
  end
end
