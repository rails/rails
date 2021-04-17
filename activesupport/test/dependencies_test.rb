# frozen_string_literal: true

require_relative "abstract_unit"
require "pp"
require "active_support/dependencies"

module ModuleWithMissing
  mattr_accessor :missing_count
  def self.const_missing(name)
    self.missing_count += 1
    name
  end
end

module ModuleWithConstant
  InheritedConstant = "Hello"
end

class DependenciesTest < ActiveSupport::TestCase
  setup do
    @loaded_features_copy = $LOADED_FEATURES.dup
    $LOAD_PATH << "test"
  end

  teardown do
    ActiveSupport::Dependencies.clear
    $LOADED_FEATURES.replace(@loaded_features_copy)
    $LOAD_PATH.pop
  end

  def test_depend_on_path
    expected = assert_raises(LoadError) do
      Kernel.require "omgwtfbbq"
    end

    e = assert_raises(LoadError) do
      ActiveSupport::Dependencies.depend_on "omgwtfbbq"
    end
    assert_equal expected.path, e.path
  end

  def test_depend_on_message
    e = assert_raises(LoadError) do
      ActiveSupport::Dependencies.depend_on "omgwtfbbq"
    end
    assert_equal "No such file to load -- omgwtfbbq.rb", e.message
  end

  def test_missing_dependency_raises_missing_source_file
    assert_raise(LoadError) { require_dependency("missing_service") }
  end

  def test_smart_name_error_strings
    e = assert_raise NameError do
      Object.module_eval "ImaginaryObject"
    end
    assert_includes "uninitialized constant ImaginaryObject", e.message
  end

  def test_loadable_constants_for_path_should_handle_empty_autoloads
    assert_equal [], ActiveSupport::Dependencies.loadable_constants_for_path("hello")
  end

  def test_qualified_const_defined
    assert ActiveSupport::Dependencies.qualified_const_defined?("Object")
    assert ActiveSupport::Dependencies.qualified_const_defined?("::Object")
    assert ActiveSupport::Dependencies.qualified_const_defined?("::Object::Kernel")
    assert ActiveSupport::Dependencies.qualified_const_defined?("::ActiveSupport::TestCase")
  end

  def test_qualified_const_defined_should_not_call_const_missing
    ModuleWithMissing.missing_count = 0
    assert_not ActiveSupport::Dependencies.qualified_const_defined?("ModuleWithMissing::A")
    assert_equal 0, ModuleWithMissing.missing_count
    assert_not ActiveSupport::Dependencies.qualified_const_defined?("ModuleWithMissing::A::B")
    assert_equal 0, ModuleWithMissing.missing_count
  end

  def test_qualified_const_defined_explodes_with_invalid_const_name
    assert_raises(NameError) { ActiveSupport::Dependencies.qualified_const_defined?("invalid") }
  end

  def test_qualified_name_for
    assert_equal "A", ActiveSupport::Dependencies.qualified_name_for(Object, :A)
    assert_equal "A", ActiveSupport::Dependencies.qualified_name_for(:Object, :A)
    assert_equal "A", ActiveSupport::Dependencies.qualified_name_for("Object", :A)
    assert_equal "A", ActiveSupport::Dependencies.qualified_name_for("::Object", :A)

    assert_equal "ActiveSupport::Dependencies::A", ActiveSupport::Dependencies.qualified_name_for(:'ActiveSupport::Dependencies', :A)
    assert_equal "ActiveSupport::Dependencies::A", ActiveSupport::Dependencies.qualified_name_for(ActiveSupport::Dependencies, :A)
  end

  def test_new_constants_in_with_inherited_constants
    m = ActiveSupport::Dependencies.new_constants_in(:Object) do
      Object.class_eval { include ModuleWithConstant }
    end
    assert_equal [], m
  end

  def test_new_constants_in_with_illegal_module_name_raises_correct_error
    assert_raise(NameError) do
      ActiveSupport::Dependencies.new_constants_in("Illegal-Name") { }
    end
  end

  def test_hook_called_multiple_times
    assert_nothing_raised { ActiveSupport::Dependencies.hook! }
  end

  def test_load_and_require_stay_private
    assert_includes Object.private_methods, :load
    assert_includes Object.private_methods, :require

    ActiveSupport::Dependencies.unhook!

    assert_includes Object.private_methods, :load
    assert_includes Object.private_methods, :require
  ensure
    ActiveSupport::Dependencies.hook!
  end
end
