require File.dirname(__FILE__) + '/abstract_unit'

ActiveSupport::Deprecation.silence do
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
    assert_deprecated_reloadable do
      assert !ReloadableTestSandbox::SubclassesReloadable.reloadable?
      assert ReloadableTestSandbox::ASubclassOfSubclassesReloadable.reloadable?
    end
  end

  def test_inside_hierarchy_only_subclass_reloadable
    assert_deprecated_reloadable do
      assert !ReloadableTestSandbox::AnOnlySubclassReloadableClassSubclassingAReloadableClass.reloadable?
      assert ReloadableTestSandbox::ASubclassofAOnlySubclassReloadableClassWhichWasSubclassingAReloadableClass.reloadable?
    end
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

    results = []
    assert_deprecated_reloadable { results = Reloadable.reloadable_classes }
    reloadables.each do |name|
      assert results.include?(ReloadableTestSandbox.const_get(name)), "Expected #{name} to be reloadable"
    end
    non_reloadables.each do |name|
      assert ! results.include?(ReloadableTestSandbox.const_get(name)), "Expected #{name} NOT to be reloadable"
    end
  end
  
  def test_including_reloadable_should_warn
    c = Class.new
    assert_deprecated_reloadable do
      c.send :include, Reloadable
    end
    
    assert_deprecated_reloadable { c.reloadable? }
  end
  
  def test_include_subclasses_should_warn
    c = Class.new
    result, deps = collect_deprecations do
      c.send :include, Reloadable::Subclasses
    end
    assert_equal 1, deps.size
    assert_match %r{Reloadable::Subclasses}, deps.first

    assert_deprecated_reloadable { c.reloadable? }
  end
  
  def test_include_deprecated_should_not_warn
    c = Class.new
    result, deps = collect_deprecations do
      c.send :include, Reloadable::Deprecated
    end
    assert_equal 0, deps.size
    
    assert c.respond_to?(:reloadable?)
    assert_deprecated_reloadable { c.reloadable? }
  end
  
  protected
    def assert_deprecated_reloadable(&block)
      assert_deprecated(/reloadable/, &block)
    end
end
