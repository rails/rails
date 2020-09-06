# frozen_string_literal: true

require_relative 'abstract_unit'
require 'active_support/security_utils'

class SecurityUtilsTest < ActiveSupport::TestCase
  def test_secure_compare_should_perform_string_comparison
    assert ActiveSupport::SecurityUtils.secure_compare('a', 'a')
    assert_not ActiveSupport::SecurityUtils.secure_compare('a', 'b')
  end

  def test_fixed_length_secure_compare_should_perform_string_comparison
    assert ActiveSupport::SecurityUtils.fixed_length_secure_compare('a', 'a')
    assert_not ActiveSupport::SecurityUtils.fixed_length_secure_compare('a', 'b')
  end

  def test_fixed_length_secure_compare_raise_on_length_mismatch
    assert_raises(ArgumentError, 'string length mismatch.') do
      ActiveSupport::SecurityUtils.fixed_length_secure_compare('a', 'ab')
    end
  end
end
