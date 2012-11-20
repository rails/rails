require 'abstract_unit'
require 'active_support/core_ext/object/boolean'

class BooleanTest < ActiveSupport::TestCase
  BOOLEAN = [ true, false ]
  OTHER   = [ {}, '', [], Object.new, 0, 1, nil ]

  def test_boolean
    BOOLEAN.each { |v| assert v.boolean?,  "#{v.inspect} should be boolean" }
    OTHER.each   { |v| assert !v.boolean?, "#{v.inspect} should not be boolean" }
  end
end
