# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/dependencies"

class RequireDependencyTest < ActiveSupport::TestCase
  def silenced_require_dependency(path)
    ActiveSupport.deprecator.silence { require_dependency(path) }
  end

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
    assert silenced_require_dependency("x")
    assert_equal :X, X
  end

  test "require_dependency looks autoload paths up (idempotent)" do
    assert silenced_require_dependency("x")
    assert_not silenced_require_dependency("x")
  end

  test "require_dependency handles absolute paths correctly" do
    assert silenced_require_dependency("#{@root_dir}/x.rb")
    assert_equal :X, X
  end

  test "require_dependency handles absolute paths correctly (idempotent)" do
    assert silenced_require_dependency("#{@root_dir}/x.rb")
    assert_not silenced_require_dependency("#{@root_dir}/x.rb")
  end

  test "require_dependency supports arguments that respond to to_path" do
    x = Object.new
    def x.to_path; "x"; end

    assert silenced_require_dependency(x)
    assert_equal :X, X
  end

  test "require_dependency supports arguments that respond to to_path (idempotent)" do
    x = Object.new
    def x.to_path; "x"; end

    assert silenced_require_dependency(x)
    assert_not silenced_require_dependency(x)
  end

  test "require_dependency fallback to Kernel#require" do
    dir = Dir.mktmpdir
    $LOAD_PATH << dir
    File.write("#{dir}/y.rb", "Y = :Y")

    assert silenced_require_dependency("y")
    assert_equal :Y, Y
  ensure
    $LOAD_PATH.pop
    Object.send(:remove_const, :Y) if Object.const_defined?(:Y)
  end

  test "require_dependency fallback to Kernel#require (idempotent)" do
    dir = Dir.mktmpdir
    $LOAD_PATH << dir
    File.write("#{dir}/y.rb", "Y = :Y")

    assert silenced_require_dependency("y")
    assert_not silenced_require_dependency("y")
  ensure
    $LOAD_PATH.pop
    Object.send(:remove_const, :Y) if Object.const_defined?(:Y)
  end

  test "require_dependency raises ArgumentError if the argument is not a String and does not respond to #to_path" do
    assert_raises(ArgumentError) { silenced_require_dependency(Object.new) }
  end

  test "require_dependency raises LoadError if the given argument is not found" do
    assert_raise(LoadError) { silenced_require_dependency("nonexistent_filename") }
  end

  test "require_dependency is deprecated" do
    assert_deprecated(/require_dependency is deprecated/, ActiveSupport.deprecator) do
      require_dependency("x")
    end
  end
end
