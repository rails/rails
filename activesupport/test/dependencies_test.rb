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

  def test_smart_name_error_strings
    e = assert_raise NameError do
      Object.module_eval "ImaginaryObject"
    end
    assert_includes "uninitialized constant ImaginaryObject", e.message
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
end

class RequireDependencyTest < ActiveSupport::TestCase
  setup do
    @loaded_features_copy = $LOADED_FEATURES.dup
    ActiveSupport::Dependencies.autoload_paths.clear

    @root_dir = Dir.mktmpdir
    File.write("#{@root_dir}/x.rb", "X = :X")
    ActiveSupport::Dependencies.autoload_paths << @root_dir
  end

  teardown do
    $LOADED_FEATURES.replace(@loaded_features_copy)
    ActiveSupport::Dependencies.autoload_paths.clear

    FileUtils.rm_rf(@root_dir)
    Object.send(:remove_const, :X) if Object.const_defined?(:X)
  end

  test "require_dependency looks autoload paths up" do
    assert require_dependency("x")
    assert_equal :X, X
  end

  test "require_dependency looks autoload paths up (idempotent)" do
    assert require_dependency("x")
    assert_not require_dependency("x")
  end

  test "require_dependency handles absolute paths correctly" do
    assert require_dependency("#{@root_dir}/x.rb")
    assert_equal :X, X
  end

  test "require_dependency handles absolute paths correctly (idempotent)" do
    assert require_dependency("#{@root_dir}/x.rb")
    assert_not require_dependency("#{@root_dir}/x.rb")
  end

  test "require_dependency supports arguments that respond to to_path" do
    x = Object.new
    def x.to_path; "x"; end

    assert require_dependency(x)
    assert_equal :X, X
  end

  test "require_dependency supports arguments that respond to to_path (idempotent)" do
    x = Object.new
    def x.to_path; "x"; end

    assert require_dependency(x)
    assert_not require_dependency(x)
  end

  test "require_dependency fallback to Kernel#require" do
    dir = Dir.mktmpdir
    $LOAD_PATH << dir
    File.write("#{dir}/y.rb", "Y = :Y")

    assert require_dependency("y")
    assert_equal :Y, Y
  ensure
    $LOAD_PATH.pop
    Object.send(:remove_const, :Y) if Object.const_defined?(:Y)
  end

  test "require_dependency fallback to Kernel#require (idempotent)" do
    dir = Dir.mktmpdir
    $LOAD_PATH << dir
    File.write("#{dir}/y.rb", "Y = :Y")

    assert require_dependency("y")
    assert_not require_dependency("y")
  ensure
    $LOAD_PATH.pop
    Object.send(:remove_const, :Y) if Object.const_defined?(:Y)
  end

  test "require_dependency raises ArgumentError if the argument is not a String and does not respond to #to_path" do
    assert_raises(ArgumentError) { require_dependency(Object.new) }
  end

  test "require_dependency raises LoadError if the given argument is not found" do
    assert_raise(LoadError) { require_dependency("nonexistent_filename") }
  end
end
