require "abstract_unit"
require "active_support/core_ext/marshal"
require "dependencies_test_helpers"

class MarshalTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation
  include DependenciesTestHelpers

  def teardown
    ActiveSupport::Dependencies.clear
    remove_constants(:EM, :ClassFolder)
  end

  test "that Marshal#load still works" do
    sanity_data = ["test", [1, 2, 3], { a: [1, 2, 3] }, ActiveSupport::TestCase]
    sanity_data.each do |obj|
      dumped = Marshal.dump(obj)
      assert_equal Marshal.method(:load).super_method.call(dumped), Marshal.load(dumped)
    end
  end

  test "that Marshal#load still works when passed a proc" do
    example_string = "test"

    example_proc = Proc.new do |o|
      if o.is_a?(String)
        o.capitalize!
      end
    end

    dumped = Marshal.dump(example_string)
    assert_equal Marshal.load(dumped, example_proc), "Test"
  end

  test "that a missing class is autoloaded from string" do
    dumped = nil
    with_autoloading_fixtures do
      dumped = Marshal.dump(EM.new)
    end

    remove_constants(:EM)
    ActiveSupport::Dependencies.clear

    with_autoloading_fixtures do
      object = nil
      assert_nothing_raised do
        object = Marshal.load(dumped)
      end

      assert_kind_of EM, object
    end
  end

  test "that classes in sub modules work" do
    dumped = nil
    with_autoloading_fixtures do
      dumped = Marshal.dump(ClassFolder::ClassFolderSubclass.new)
    end

    remove_constants(:ClassFolder)
    ActiveSupport::Dependencies.clear

    with_autoloading_fixtures do
      object = nil
      assert_nothing_raised do
        object = Marshal.load(dumped)
      end

      assert_kind_of ClassFolder::ClassFolderSubclass, object
    end
  end

  test "that more than one missing class is autoloaded" do
    dumped = nil
    with_autoloading_fixtures do
      dumped = Marshal.dump([EM.new, ClassFolder.new])
    end

    remove_constants(:EM, :ClassFolder)
    ActiveSupport::Dependencies.clear

    with_autoloading_fixtures do
      loaded = Marshal.load(dumped)
      assert_equal 2, loaded.size
      assert_kind_of EM, loaded[0]
      assert_kind_of ClassFolder, loaded[1]
    end
  end

  test "when one constant resolves to another" do
    class Parent; C = Class.new; end
    class Child < Parent; C = Class.new; end

    dump = Marshal.dump(Child::C.new)

    Child.send(:remove_const, :C)

    assert_raise(ArgumentError) { Marshal.load(dump) }
  end

  test "that a real missing class is causing an exception" do
    dumped = nil
    with_autoloading_fixtures do
      dumped = Marshal.dump(EM.new)
    end

    remove_constants(:EM)
    ActiveSupport::Dependencies.clear

    assert_raise(NameError) do
      Marshal.load(dumped)
    end
  end

  test "when first class is autoloaded and second not" do
    dumped = nil
    class SomeClass
    end

    with_autoloading_fixtures do
      dumped = Marshal.dump([EM.new, SomeClass.new])
    end

    remove_constants(:EM)
    self.class.send(:remove_const, :SomeClass)
    ActiveSupport::Dependencies.clear

    with_autoloading_fixtures do
      assert_raise(NameError) do
        Marshal.load(dumped)
      end

      assert_nothing_raised do
        EM.new
      end

      assert_raise(NameError, "We expected SomeClass to not be loaded but it is!") do
        SomeClass.new
      end
    end
  end

  test "loading classes from files trigger autoloading" do
    Tempfile.open("object_serializer_test") do |f|
      with_autoloading_fixtures do
        Marshal.dump(EM.new, f)
      end

      f.rewind
      remove_constants(:EM)
      ActiveSupport::Dependencies.clear

      with_autoloading_fixtures do
        object = nil
        assert_nothing_raised do
          object = Marshal.load(f)
        end

        assert_kind_of EM, object
      end
    end
  end
end
