require 'test/unit'
require File.dirname(__FILE__) + '/../lib/active_support/core_ext/class'
require File.dirname(__FILE__) + '/../lib/active_support/core_ext/module'
require File.dirname(__FILE__) + '/../lib/active_support/reloadable'

module ReloadableTestSandbox
  
  class AReloadableClass
    include Reloadable
  end
  class AReloadableClassWithSubclasses
    include Reloadable
  end
  class AReloadableSubclass < AReloadableClassWithSubclasses
  end
  class ANonReloadableSubclass < AReloadableClassWithSubclasses
    def self.reloadable?
      false
    end
  end
  class AClassWhichDefinesItsOwnReloadable
    def self.reloadable?
      10
    end
    include Reloadable
  end
  
  class SubclassesReloadable
    include Reloadable::Subclasses
  end
  class ASubclassOfSubclassesReloadable < SubclassesReloadable
  end
  
  class AnOnlySubclassReloadableClassSubclassingAReloadableClass
    include Reloadable::Subclasses
  end
  
  class ASubclassofAOnlySubclassReloadableClassWhichWasSubclassingAReloadableClass < AnOnlySubclassReloadableClassSubclassingAReloadableClass
  end
end

class ReloadableTest < Test::Unit::TestCase
  def test_classes_receive_reloadable
    assert ReloadableTestSandbox::AReloadableClass.respond_to?(:reloadable?)
  end
  def test_classes_inherit_reloadable
    assert ReloadableTestSandbox::AReloadableSubclass.respond_to?(:reloadable?)
  end
  def test_reloadable_is_not_overwritten_if_present
    assert_equal 10, ReloadableTestSandbox::AClassWhichDefinesItsOwnReloadable.reloadable?
  end
  
  def test_only_subclass_reloadable
    assert ! ReloadableTestSandbox::SubclassesReloadable.reloadable?
    assert ReloadableTestSandbox::ASubclassOfSubclassesReloadable.reloadable?
  end
  
  def test_inside_hierarchy_only_subclass_reloadable
    assert ! ReloadableTestSandbox::AnOnlySubclassReloadableClassSubclassingAReloadableClass.reloadable?
    assert ReloadableTestSandbox::ASubclassofAOnlySubclassReloadableClassWhichWasSubclassingAReloadableClass.reloadable?
  end
  
  def test_removable_classes
    reloadables = %w(
      AReloadableClass
      AReloadableClassWithSubclasses
      AReloadableSubclass
      AClassWhichDefinesItsOwnReloadable
      ASubclassOfSubclassesReloadable
    )
    non_reloadables = %w(
      ANonReloadableSubclass
      SubclassesReloadable
    )
    
    results = Reloadable.reloadable_classes
    reloadables.each do |name|
      assert results.include?(ReloadableTestSandbox.const_get(name)), "Expected #{name} to be reloadable"
    end
    non_reloadables.each do |name|
      assert ! results.include?(ReloadableTestSandbox.const_get(name)), "Expected #{name} NOT to be reloadable"
    end
  end
end