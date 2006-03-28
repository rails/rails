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

Somewhere = Struct.new(:street, :city)

Someone   = Struct.new(:name, :place) do
  delegate :street, :city, :to => :place
  delegate :state, :to => :@place
  delegate :upcase, :to => "place.city"
end

class Name
  delegate :upcase, :to => :@full_name

  def initialize(first, last)
    @full_name = "#{first} #{last}"
  end
end

$nowhere = <<-EOF
class Name
  delegate :nowhere
end
EOF

$noplace = <<-EOF
class Name
  delegate :noplace, :tos => :hollywood
end
EOF

class ModuleTest < Test::Unit::TestCase
  def test_included_in_classes
    assert One.included_in_classes.include?(Ab)
    assert One.included_in_classes.include?(Xy::Bc)
    assert One.included_in_classes.include?(Yz::Zy::Cd)
    assert !One.included_in_classes.include?(De)
  end

  def test_delegation_to_methods
    david = Someone.new("David", Somewhere.new("Paulina", "Chicago"))
    assert_equal "Paulina", david.street
    assert_equal "Chicago", david.city
  end
  
  def test_delegation_down_hierarchy
    david = Someone.new("David", Somewhere.new("Paulina", "Chicago"))
    assert_equal "CHICAGO", david.upcase
  end
  
  def test_delegation_to_instance_variable
    david = Name.new("David", "Hansson")
    assert_equal "DAVID HANSSON", david.upcase
  end
  
  def test_missing_delegation_target
    assert_raises(ArgumentError) { eval($nowhere) }
    assert_raises(ArgumentError) { eval($noplace) }
  end
  
  def test_parent
    assert_equal Yz::Zy, Yz::Zy::Cd.parent
    assert_equal Yz, Yz::Zy.parent
    assert_equal Object, Yz.parent
  end
  
  def test_parents
    assert_equal [Yz::Zy, Yz, Object], Yz::Zy::Cd.parents
    assert_equal [Yz, Object], Yz::Zy.parents
  end
  
  def test_as_load_path
    assert_equal 'yz/zy', Yz::Zy.as_load_path
    assert_equal 'yz', Yz.as_load_path
  end
end