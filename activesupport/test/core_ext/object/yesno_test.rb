require 'abstract_unit'
require 'active_support/core_ext/object/yesno'

class YesnoTest < ActiveSupport::TestCase
  YES_AND_NO = [Object.new, {}, [], { a: true }, { b: false }, [true], [false], 0.0].freeze
  YES = [true, 1, 'y', 'Y', 'yes', 'Yes', 'YES', 'true', 'True', 'TRUE', 'on', 'On', 'ON', '1'].freeze
  NO  = [nil, false, 0, 'n', 'N', 'no', 'No', 'NO', 'false', 'False', 'FALSE', 'off', 'Off', 'OFF', '0'].freeze

  def test_yes
    YES_AND_NO.each { |v| assert_equal false, v.yes?, "#{v.inspect} should not be yes" }
    YES.each { |v| assert_equal true, v.yes?, "#{v.inspect} should be yes" }
    NO.each { |v| assert_equal false, v.yes?, "#{v.inspect} should not be yes" }
  end

  def test_no
    YES_AND_NO.each { |v| assert_equal false, v.no?, "#{v.inspect} should not be no" }
    YES.each { |v| assert_equal false, v.no?, "#{v.inspect} should not be no" }
    NO.each { |v| assert_equal true, v.no?, "#{v.inspect} should be no" }
  end
end
