# frozen_string_literal: true

require_relative '../abstract_unit'
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

  def test_base36
    s1 = SecureRandom.base36
    s2 = SecureRandom.base36

    assert_not_equal s1, s2
    assert_equal 16, s1.length
    assert_match(/^[a-z0-9]+$/, s1)
    assert_match(/^[a-z0-9]+$/, s2)
  end

  def test_base36_with_length
    s1 = SecureRandom.base36(24)
    s2 = SecureRandom.base36(24)

    assert_not_equal s1, s2
    assert_equal 24, s1.length
    assert_match(/^[a-z0-9]+$/, s1)
    assert_match(/^[a-z0-9]+$/, s2)
  end
end
