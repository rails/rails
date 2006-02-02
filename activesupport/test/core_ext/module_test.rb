require 'test/unit'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/class'
require File.dirname(__FILE__) + '/../../lib/active_support/core_ext/module'

module One
end

class Ab
  include One
end

module Xy
  class Bc
    include One
  end
end

module Yz
  module Zy
    class Cd
      include One
    end
  end
end

class De
end

class ModuleTest < Test::Unit::TestCase
  def test_included_in_classes
    assert One.included_in_classes.include?(Ab)
    assert One.included_in_classes.include?(Xy::Bc)
    assert One.included_in_classes.include?(Yz::Zy::Cd)
    assert !One.included_in_classes.include?(De)
  end

end