require 'abstract_unit'
require 'active_support/core_ext/class'

class A
end

module X
  class B
  end
end

module Y
  module Z
    class C
    end
  end
end

class ClassTest < Test::Unit::TestCase
end
