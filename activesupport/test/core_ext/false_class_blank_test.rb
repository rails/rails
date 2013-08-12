# encoding: utf-8

require 'abstract_unit'
require 'active_support/core_ext/false_class/blank'

class FalsClassBlankTest < ActiveSupport::TestCase

  def test_blank_on_true_value
    v = true
    assert !v.blank?, "#{v.inspect} should not be blank"
  end

  def test_blank_on_false_value
    v = false
    assert !v.blank?, "#{v.inspect} should not be blank"
  end
end
