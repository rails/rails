require 'abstract_unit'
require 'pp'
require 'active_support/dependencies'
require 'dependencies_test_helpers'

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
  def teardown
    ActiveSupport::Dependencies.unload!
  end

  include DependenciesTestHelpers

  def test_depend_on_path
    skip "LoadError#path does not exist" if RUBY_VERSION < '2.0.0'

    expected = assert_raises(LoadError) do
      Kernel.require 'omgwtfbbq'
    end

    e = assert_raises(LoadError) do
      ActiveSupport::Dependencies.depend_on 'omgwtfbbq'
    end
    assert_equal expected.path, e.path
  end

  def test_require_dependency_accepts_an_object_which_implements_to_path
    o = Object.new
    def o.to_path; 'dependencies/service_one'; end
    assert_nothing_raised {
      require_dependency o
    }
    assert defined?(ServiceOne)
  ensure
    remove_constants(:ServiceOne)
  end

  def test_tracking_loaded_files
    require_dependency 'dependencies/service_one'
    require_dependency 'dependencies/service_two'
    assert_equal 2, ActiveSupport::Dependencies.loaded.size
  ensure
    remove_constants(:ServiceOne, :ServiceTwo)
  end

  def test_tracking_identical_loaded_files
    require_dependency 'dependencies/service_one'
    require_dependency 'dependencies/service_one'
    assert_equal 1, ActiveSupport::Dependencies.loaded.size
  ensure
    remove_constants(:ServiceOne)
  end

  def test_missing_dependency_raises_missing_source_file
    assert_raise(MissingSourceFile) { require_dependency("missing_service") }
  end

  def test_dependency_which_raises_exception_isnt_added_to_loaded_set
    with_loading do
      filename = 'dependencies/raises_exception'
      $raises_exception_load_count = 0

      5.times do |count|
        e = assert_raise Exception, 'should have loaded dependencies/raises_exception which raises an exception' do
          require_dependency filename
        end

        assert_equal 'Loading me failed, so do not add to loaded or history.', e.message
        assert_equal count + 1, $raises_exception_load_count

        assert !ActiveSupport::Dependencies.loaded.include?(filename)
        assert !ActiveSupport::Dependencies.history.include?(filename)
      end
    end
  end

  def test_dependency_which_raises_doesnt_blindly_call_blame_file!
    with_loading do
      filename = 'dependencies/raises_exception_without_blame_file'

      assert_raises(Exception) { require_dependency filename }
    end
  end

  def test_warnings_should_be_enabled_on_first_load
    with_loading 'dependencies' do
      old_warnings, ActiveSupport::Dependencies.warnings_on_first_load = ActiveSupport::Dependencies.warnings_on_first_load, true

      filename = "check_warnings"
      expanded = File.expand_path("#{File.dirname(__FILE__)}/dependencies/#{filename}")
      $check_warnings_load_count = 0

      assert !ActiveSupport::Dependencies.loaded.include?(expanded)
      assert !ActiveSupport::Dependencies.history.include?(expanded)

      silence_warnings { require_dependency filename }
      assert_equal 1, $check_warnings_load_count
      assert_equal true, $checked_verbose, 'On first load warnings should be enabled.'

      assert ActiveSupport::Dependencies.loaded.include?(expanded)
      ActiveSupport::Dependencies.unload!
      assert !ActiveSupport::Dependencies.loaded.include?(expanded)
      assert ActiveSupport::Dependencies.history.include?(expanded)

      silence_warnings { require_dependency filename }
      assert_equal 2, $check_warnings_load_count
      assert_equal nil, $checked_verbose, 'After first load warnings should be left alone.'

      assert ActiveSupport::Dependencies.loaded.include?(expanded)
      ActiveSupport::Dependencies.unload!
      assert !ActiveSupport::Dependencies.loaded.include?(expanded)
      assert ActiveSupport::Dependencies.history.include?(expanded)

      enable_warnings { require_dependency filename }
      assert_equal 3, $check_warnings_load_count
      assert_equal true, $checked_verbose, 'After first load warnings should be left alone.'

      assert ActiveSupport::Dependencies.loaded.include?(expanded)
      ActiveSupport::Dependencies.warnings_on_first_load = old_warnings
    end
  end

  def test_mutual_dependencies_dont_infinite_loop
    with_loading 'dependencies' do
      $mutual_dependencies_count = 0
      assert_nothing_raised { require_dependency 'mutual_one' }
      assert_equal 2, $mutual_dependencies_count

      ActiveSupport::Dependencies.unload!

      $mutual_dependencies_count = 0
      assert_nothing_raised { require_dependency 'mutual_two' }
      assert_equal 2, $mutual_dependencies_count
    end
  end

  def test_circular_autoloading_detection
    with_autoloading_fixtures do
      e = assert_raise(RuntimeError) { Circular1 }
      assert_equal "Circular dependency detected while autoloading constant Circular1", e.message
    end
  end

  def test_module_loading
    with_autoloading_fixtures do
      assert_kind_of Module, A
      assert_kind_of Class, A::B
      assert_kind_of Class, A::C::D
      assert_kind_of Class, A::C::E::F
    end
  end

  def test_non_existing_const_raises_name_error
    with_autoloading_fixtures do
      assert_raise(NameError) { DoesNotExist }
      assert_raise(NameError) { NoModule::DoesNotExist }
      assert_raise(NameError) { A::DoesNotExist }
      assert_raise(NameError) { A::B::DoesNotExist }
    end
  end

  def test_directories_manifest_as_modules_unless_const_defined
    const_scope(:ModuleFolder) do
      assert_kind_of Module, ModuleFolder
    end
  end

  def test_module_with_nested_class
    const_scope(:ModuleFolder) do
      assert_kind_of Class, ModuleFolder::NestedClass
    end
  end

  def test_module_with_nested_inline_class
    const_scope(:ModuleFolder) do
      assert_kind_of Class, ModuleFolder::InlineClass
    end
  end

  def test_directories_may_manifest_as_nested_classes
    const_scope(:ClassFolder) do
      assert_kind_of Class, ClassFolder
    end
  end

  def test_class_with_nested_class
    const_scope(:ClassFolder) do
      assert_kind_of Class, ClassFolder::NestedClass
    end
  end

  def test_class_with_nested_inline_class
    const_scope(:ClassFolder) do
      assert_kind_of Class, ClassFolder::InlineClass
    end
  end

  def test_class_with_nested_inline_subclass_of_parent
    const_scope(:ClassFolder) do
      assert_kind_of Class, ClassFolder::ClassFolderSubclass
      assert_kind_of Class, ClassFolder
      assert_equal 'indeed', ClassFolder::ClassFolderSubclass::ConstantInClassFolder
    end
  end

  def test_nested_class_can_access_sibling
    const_scope(:ModuleFolder) do
      sibling = ModuleFolder::NestedClass.class_eval "NestedSibling"
      assert defined?(ModuleFolder::NestedSibling)
      assert_equal ModuleFolder::NestedSibling, sibling
    end
  end

  def test_doesnt_break_normal_require
    path = File.expand_path("../autoloading_fixtures/load_path", __FILE__)
    original_path = $:.dup
    original_features = $".dup
    $:.push(path)

    with_autoloading_fixtures do
      # The _ = assignments are to prevent warnings
      _ = RequiresConstant
      assert defined?(RequiresConstant)
      assert defined?(LoadedConstant)
      ActiveSupport::Dependencies.unload!
      _ = RequiresConstant
      assert defined?(RequiresConstant)
      assert defined?(LoadedConstant)
    end
  ensure
    remove_constants(:RequiresConstant, :LoadedConstant, :LoadsConstant)
    $".replace(original_features)
    $:.replace(original_path)
  end

  def test_doesnt_break_normal_require_nested
    path = File.expand_path("../autoloading_fixtures/load_path", __FILE__)
    original_path = $:.dup
    original_features = $".dup
    $:.push(path)

    with_autoloading_fixtures do
      # The _ = assignments are to prevent warnings
      _ = LoadsConstant
      assert defined?(LoadsConstant)
      assert defined?(LoadedConstant)
      ActiveSupport::Dependencies.unload!
      _ = LoadsConstant
      assert defined?(LoadsConstant)
      assert defined?(LoadedConstant)
    end
  ensure
    remove_constants(:RequiresConstant, :LoadedConstant, :LoadsConstant)
    $".replace(original_features)
    $:.replace(original_path)
  end

  def test_require_returns_true_when_file_not_yet_required
    path = File.expand_path("../autoloading_fixtures/load_path", __FILE__)
    original_path = $:.dup
    original_features = $".dup
    $:.push(path)

    with_loading do
      assert_equal true, require('loaded_constant')
    end
  ensure
    remove_constants(:LoadedConstant)
    $".replace(original_features)
    $:.replace(original_path)
  end

  def test_require_returns_true_when_file_not_yet_required_even_when_no_new_constants_added
    path = File.expand_path("../autoloading_fixtures/load_path", __FILE__)
    original_path = $:.dup
    original_features = $".dup
    $:.push(path)

    with_loading do
      Object.module_eval "module LoadedConstant; end"
      assert_equal true, require('loaded_constant')
    end
  ensure
    remove_constants(:LoadedConstant)
    $".replace(original_features)
    $:.replace(original_path)
  end

  def test_require_returns_false_when_file_already_required
    path = File.expand_path("../autoloading_fixtures/load_path", __FILE__)
    original_path = $:.dup
    original_features = $".dup
    $:.push(path)

    with_loading do
      require 'loaded_constant'
      assert_equal false, require('loaded_constant')
    end
  ensure
    remove_constants(:LoadedConstant)
    $".replace(original_features)
    $:.replace(original_path)
  end

  def test_require_raises_load_error_when_file_not_found
    with_loading do
      assert_raise(LoadError) { require 'this_file_dont_exist_dude' }
    end
  ensure
    remove_constants(:LoadedConstant)
  end

  def test_load_returns_true_when_file_found
    path = File.expand_path("../autoloading_fixtures/load_path", __FILE__)
    original_path = $:.dup
    original_features = $".dup
    $:.push(path)

    with_loading do
      assert_equal true, load('loaded_constant.rb')
      assert_equal true, load('loaded_constant.rb')
    end
  ensure
    remove_constants(:LoadedConstant)
    $".replace(original_features)
    $:.replace(original_path)
  end

  def test_load_raises_load_error_when_file_not_found
    with_loading do
      assert_raise(LoadError) { load 'this_file_dont_exist_dude.rb' }
    end
  ensure
    remove_constants(:LoadedConstant)
  end

  def failing_test_access_thru_and_upwards_fails
    const_scope(:ModuleFolder) do
      assert ! defined?(ModuleFolder)
      assert_raise(NameError) { ModuleFolder::Object }
      assert_raise(NameError) { ModuleFolder::NestedClass::Object }
    end
  end

  def test_non_existing_const_raises_name_error_with_fully_qualified_name
    with_autoloading_fixtures do
      e = assert_raise(NameError) { A::DoesNotExist.nil? }
      assert_equal "uninitialized constant A::DoesNotExist", e.message

      e = assert_raise(NameError) { A::B::DoesNotExist.nil? }
      assert_equal "uninitialized constant A::B::DoesNotExist", e.message
    end
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
    assert ! ActiveSupport::Dependencies.qualified_const_defined?("ModuleWithMissing::A")
    assert_equal 0, ModuleWithMissing.missing_count
    assert ! ActiveSupport::Dependencies.qualified_const_defined?("ModuleWithMissing::A::B")
    assert_equal 0, ModuleWithMissing.missing_count
  end

  def test_qualified_const_defined_explodes_with_invalid_const_name
    assert_raises(NameError) { ActiveSupport::Dependencies.qualified_const_defined?("invalid") }
  end

  def test_autoloaded?
    with_autoloading_fixtures do
      assert ! ActiveSupport::Dependencies.autoloaded?("ModuleFolder")
      assert ! ActiveSupport::Dependencies.autoloaded?("ModuleFolder::NestedClass")

      assert ActiveSupport::Dependencies.autoloaded?(ModuleFolder)

      assert ActiveSupport::Dependencies.autoloaded?("ModuleFolder")
      assert ! ActiveSupport::Dependencies.autoloaded?("ModuleFolder::NestedClass")

      assert ActiveSupport::Dependencies.autoloaded?(ModuleFolder::NestedClass)

      assert ActiveSupport::Dependencies.autoloaded?("ModuleFolder")
      assert ActiveSupport::Dependencies.autoloaded?("ModuleFolder::NestedClass")

      assert ActiveSupport::Dependencies.autoloaded?("::ModuleFolder")
      assert ActiveSupport::Dependencies.autoloaded?(:ModuleFolder)

      # Anonymous modules aren't autoloaded.
      assert !ActiveSupport::Dependencies.autoloaded?(Module.new)

      nil_name = Module.new
      def nil_name.name() nil end
      assert !ActiveSupport::Dependencies.autoloaded?(nil_name)

      Object.class_eval { remove_const :ModuleFolder }
    end
  end

  def test_qualified_name_for
    assert_equal "A", ActiveSupport::Dependencies.qualified_name_for(Object, :A)
    assert_equal "A", ActiveSupport::Dependencies.qualified_name_for(:Object, :A)
    assert_equal "A", ActiveSupport::Dependencies.qualified_name_for("Object", :A)
    assert_equal "A", ActiveSupport::Dependencies.qualified_name_for("::Object", :A)

    assert_equal "ActiveSupport::Dependencies::A", ActiveSupport::Dependencies.qualified_name_for(:'ActiveSupport::Dependencies', :A)
    assert_equal "ActiveSupport::Dependencies::A", ActiveSupport::Dependencies.qualified_name_for(ActiveSupport::Dependencies, :A)
  end

  def test_file_search
    with_loading 'dependencies' do
      root = ActiveSupport::Dependencies.autoload_paths.first
      assert_equal nil, ActiveSupport::Dependencies.search_for_file('service_three')
      assert_equal nil, ActiveSupport::Dependencies.search_for_file('service_three.rb')
      assert_equal root + '/service_one.rb', ActiveSupport::Dependencies.search_for_file('service_one')
      assert_equal root + '/service_one.rb', ActiveSupport::Dependencies.search_for_file('service_one.rb')
    end
  end

  def test_file_search_uses_first_in_load_path
    with_loading 'dependencies', 'autoloading_fixtures' do
      deps, autoload = ActiveSupport::Dependencies.autoload_paths
      assert_match %r/dependencies/, deps
      assert_match %r/autoloading_fixtures/, autoload

      assert_equal deps + '/conflict.rb', ActiveSupport::Dependencies.search_for_file('conflict')
    end
    with_loading 'autoloading_fixtures', 'dependencies' do
      autoload, deps = ActiveSupport::Dependencies.autoload_paths
      assert_match %r/dependencies/, deps
      assert_match %r/autoloading_fixtures/, autoload

      assert_equal autoload + '/conflict.rb', ActiveSupport::Dependencies.search_for_file('conflict')
    end

  end

  def test_custom_const_missing_should_work
    Object.module_eval <<-end_eval, __FILE__, __LINE__ + 1
      module ModuleWithCustomConstMissing
        def self.const_missing(name)
          const_set name, name.to_s.hash
        end

        module A
        end
      end
    end_eval

    with_autoloading_fixtures do
      assert_kind_of Integer, ::ModuleWithCustomConstMissing::B
      assert_kind_of Module, ::ModuleWithCustomConstMissing::A
      assert_kind_of String, ::ModuleWithCustomConstMissing::A::B
    end
  end

  def test_const_missing_in_anonymous_modules_loads_top_level_constants
    with_autoloading_fixtures do
      # class_eval STRING pushes the class to the nesting of the eval'ed code.
      klass = Class.new.class_eval "E"
      assert_equal E, klass
    end
  end

  def test_const_missing_in_anonymous_modules_raises_if_the_constant_belongs_to_Object
    with_autoloading_fixtures do
      require_dependency 'e'

      mod = Module.new
      e = assert_raise(NameError) { mod::E }
      assert_equal 'E cannot be autoloaded from an anonymous class or module', e.message
    end
  end

  def test_removal_from_tree_should_be_detected
    with_loading 'dependencies' do
      c = ServiceOne
      ActiveSupport::Dependencies.unload!
      assert ! defined?(ServiceOne)
      e = assert_raise ArgumentError do
        ActiveSupport::Dependencies.load_missing_constant(c, :FakeMissing)
      end
      assert_match %r{ServiceOne has been removed from the module tree}i, e.message
    end
  end


  def test_nested_load_error_isnt_rescued
    with_loading 'dependencies' do
      assert_raise(MissingSourceFile) do
        RequiresNonexistent1
      end
    end
  end

  def test_autoload_once_paths_do_not_add_to_autoloaded_constants
    with_autoloading_fixtures do
      ActiveSupport::Dependencies.autoload_once_paths = ActiveSupport::Dependencies.autoload_paths.dup

      assert ! ActiveSupport::Dependencies.autoloaded?("ModuleFolder")
      assert ! ActiveSupport::Dependencies.autoloaded?("ModuleFolder::NestedClass")
      assert ! ActiveSupport::Dependencies.autoloaded?(ModuleFolder)

      1 if ModuleFolder::NestedClass # 1 if to avoid warning
      assert ! ActiveSupport::Dependencies.autoloaded?(ModuleFolder::NestedClass)
    end
  ensure
    Object.class_eval { remove_const :ModuleFolder }
    ActiveSupport::Dependencies.autoload_once_paths = []
  end

  def test_autoload_once_pathnames_do_not_add_to_autoloaded_constants
    with_autoloading_fixtures do
      pathnames = ActiveSupport::Dependencies.autoload_paths.collect{|p| Pathname.new(p)}
      ActiveSupport::Dependencies.autoload_paths = pathnames
      ActiveSupport::Dependencies.autoload_once_paths = pathnames

      assert ! ActiveSupport::Dependencies.autoloaded?("ModuleFolder")
      assert ! ActiveSupport::Dependencies.autoloaded?("ModuleFolder::NestedClass")
      assert ! ActiveSupport::Dependencies.autoloaded?(ModuleFolder)

      1 if ModuleFolder::NestedClass # 1 if to avoid warning
      assert ! ActiveSupport::Dependencies.autoloaded?(ModuleFolder::NestedClass)
    end
  ensure
    Object.class_eval { remove_const :ModuleFolder }
    ActiveSupport::Dependencies.autoload_once_paths = []
  end

  def test_preexisting_constants_are_not_marked_as_autoloaded
    with_autoloading_fixtures do
      require_dependency 'e'
      assert ActiveSupport::Dependencies.autoloaded?(:E)
      ActiveSupport::Dependencies.unload!
    end

    Object.const_set :E, Class.new
    with_autoloading_fixtures do
      require_dependency 'e'
      assert ! ActiveSupport::Dependencies.autoloaded?(:E), "E shouldn't be marked autoloaded!"
      ActiveSupport::Dependencies.unload!
    end

  ensure
    Object.class_eval { remove_const :E }
  end

  def test_constants_in_capitalized_nesting_marked_as_autoloaded
    with_autoloading_fixtures do
      ActiveSupport::Dependencies.load_missing_constant(HTML, "SomeClass")

      assert ActiveSupport::Dependencies.autoloaded?("HTML::SomeClass")
    end
  end

  def test_file_with_multiple_constants_and_require_dependency
    with_autoloading_fixtures do
      assert ! defined?(MultipleConstantFile)
      assert ! defined?(SiblingConstant)

      require_dependency 'multiple_constant_file'
      assert defined?(MultipleConstantFile)
      assert defined?(SiblingConstant)
      assert ActiveSupport::Dependencies.autoloaded?(:MultipleConstantFile)
      assert ActiveSupport::Dependencies.autoloaded?(:SiblingConstant)

      ActiveSupport::Dependencies.unload!

      assert ! defined?(MultipleConstantFile)
      assert ! defined?(SiblingConstant)
    end
  end

  def test_file_with_multiple_constants_and_auto_loading
    with_autoloading_fixtures do
      assert ! defined?(MultipleConstantFile)
      assert ! defined?(SiblingConstant)

      assert_equal 10, MultipleConstantFile

      assert defined?(MultipleConstantFile)
      assert defined?(SiblingConstant)
      assert ActiveSupport::Dependencies.autoloaded?(:MultipleConstantFile)
      assert ActiveSupport::Dependencies.autoloaded?(:SiblingConstant)

      ActiveSupport::Dependencies.unload!

      assert ! defined?(MultipleConstantFile)
      assert ! defined?(SiblingConstant)
    end
  end

  def test_nested_file_with_multiple_constants_and_require_dependency
    with_autoloading_fixtures do
      assert ! defined?(ClassFolder::NestedClass)
      assert ! defined?(ClassFolder::SiblingClass)

      require_dependency 'class_folder/nested_class'

      assert defined?(ClassFolder::NestedClass)
      assert defined?(ClassFolder::SiblingClass)
      assert ActiveSupport::Dependencies.autoloaded?("ClassFolder::NestedClass")
      assert ActiveSupport::Dependencies.autoloaded?("ClassFolder::SiblingClass")

      ActiveSupport::Dependencies.unload!

      assert ! defined?(ClassFolder::NestedClass)
      assert ! defined?(ClassFolder::SiblingClass)
    end
  end

  def test_nested_file_with_multiple_constants_and_auto_loading
    with_autoloading_fixtures do
      assert ! defined?(ClassFolder::NestedClass)
      assert ! defined?(ClassFolder::SiblingClass)

      assert_kind_of Class, ClassFolder::NestedClass

      assert defined?(ClassFolder::NestedClass)
      assert defined?(ClassFolder::SiblingClass)
      assert ActiveSupport::Dependencies.autoloaded?("ClassFolder::NestedClass")
      assert ActiveSupport::Dependencies.autoloaded?("ClassFolder::SiblingClass")

      ActiveSupport::Dependencies.unload!

      assert ! defined?(ClassFolder::NestedClass)
      assert ! defined?(ClassFolder::SiblingClass)
    end
  end

  def test_autoload_doesnt_shadow_no_method_error_with_relative_constant
    with_autoloading_fixtures do
      assert !defined?(::RaisesNoMethodError), "::RaisesNoMethodError is defined but it hasn't been referenced yet!"
      2.times do
        assert_raise(NoMethodError) { RaisesNoMethodError }
        assert !defined?(::RaisesNoMethodError), "::RaisesNoMethodError is defined but it should have failed!"
      end
    end

  ensure
    Object.class_eval { remove_const :RaisesNoMethodError if const_defined?(:RaisesNoMethodError) }
  end

  def test_autoload_doesnt_shadow_no_method_error_with_absolute_constant
    with_autoloading_fixtures do
      assert !defined?(::RaisesNoMethodError), "::RaisesNoMethodError is defined but it hasn't been referenced yet!"
      2.times do
        assert_raise(NoMethodError) { ::RaisesNoMethodError }
        assert !defined?(::RaisesNoMethodError), "::RaisesNoMethodError is defined but it should have failed!"
      end
    end

  ensure
    Object.class_eval { remove_const :RaisesNoMethodError if const_defined?(:RaisesNoMethodError) }
  end

  def test_autoload_doesnt_shadow_error_when_mechanism_not_set_to_load
    with_autoloading_fixtures do
      ActiveSupport::Dependencies.mechanism = :require
      2.times do
        assert_raise(NameError) { assert_equal 123, ::RaisesNameError::FooBarBaz }
      end
    end
  end

  def test_autoload_doesnt_shadow_name_error
    with_autoloading_fixtures do
      Object.send(:remove_const, :RaisesNameError) if defined?(::RaisesNameError)
      2.times do
        e = assert_raise NameError do
          ::RaisesNameError::FooBarBaz.object_id
        end
        assert_equal 'uninitialized constant RaisesNameError::FooBarBaz', e.message
        assert !defined?(::RaisesNameError), "::RaisesNameError is defined but it should have failed!"
      end

      assert !defined?(::RaisesNameError)
      2.times do
        assert_raise(NameError) { ::RaisesNameError }
        assert !defined?(::RaisesNameError), "::RaisesNameError is defined but it should have failed!"
      end
    end

  ensure
    Object.class_eval { remove_const :RaisesNoMethodError if const_defined?(:RaisesNoMethodError) }
  end

  def test_remove_constant_handles_double_colon_at_start
    Object.const_set 'DeleteMe', Module.new
    DeleteMe.const_set 'OrMe', Module.new
    ActiveSupport::Dependencies.remove_constant "::DeleteMe::OrMe"
    assert ! defined?(DeleteMe::OrMe)
    assert defined?(DeleteMe)
    ActiveSupport::Dependencies.remove_constant "::DeleteMe"
    assert ! defined?(DeleteMe)
  end

  def test_remove_constant_does_not_trigger_loading_autoloads
    constant = 'ShouldNotBeAutoloaded'
    Object.class_eval do
      autoload constant, File.expand_path('../autoloading_fixtures/should_not_be_required', __FILE__)
    end

    assert_nil ActiveSupport::Dependencies.remove_constant(constant), "Kernel#autoload has been triggered by remove_constant"
    assert !defined?(ShouldNotBeAutoloaded)
  end

  def test_remove_constant_does_not_autoload_already_removed_parents_as_a_side_effect
    with_autoloading_fixtures do
      _ = ::A    # assignment to silence parse-time warning "possibly useless use of :: in void context"
      _ = ::A::B # assignment to silence parse-time warning "possibly useless use of :: in void context"
      ActiveSupport::Dependencies.remove_constant('A')
      ActiveSupport::Dependencies.remove_constant('A::B')
      assert !defined?(A)
    end
  end

  def test_load_once_constants_should_not_be_unloaded
    with_autoloading_fixtures do
      ActiveSupport::Dependencies.autoload_once_paths = ActiveSupport::Dependencies.autoload_paths
      _ = ::A # assignment to silence parse-time warning "possibly useless use of :: in void context"
      assert defined?(A)
      ActiveSupport::Dependencies.unload!
      assert defined?(A)
    end
  ensure
    ActiveSupport::Dependencies.autoload_once_paths = []
    Object.class_eval { remove_const :A if const_defined?(:A) }
  end

  def test_access_unloaded_constants_for_reload
    with_autoloading_fixtures do
      assert_kind_of Module, A
      assert_kind_of Class, A::B # Necessary to load A::B for the test
      ActiveSupport::Dependencies.mark_for_unload(A::B)
      ActiveSupport::Dependencies.remove_unloadable_constants!

      A::B # Make sure no circular dependency error
    end
  end


  def test_autoload_once_paths_should_behave_when_recursively_loading
    with_loading 'dependencies', 'autoloading_fixtures' do
      ActiveSupport::Dependencies.autoload_once_paths = [ActiveSupport::Dependencies.autoload_paths.last]
      assert !defined?(CrossSiteDependency)
      assert_nothing_raised { CrossSiteDepender.nil? }
      assert defined?(CrossSiteDependency)
      assert !ActiveSupport::Dependencies.autoloaded?(CrossSiteDependency),
        "CrossSiteDependency shouldn't be marked as autoloaded!"
      ActiveSupport::Dependencies.unload!
      assert defined?(CrossSiteDependency),
        "CrossSiteDependency shouldn't have been unloaded!"
    end
  ensure
    ActiveSupport::Dependencies.autoload_once_paths = []
  end

private
  def const_scope(const_name)
    with_autoloading_fixtures do
      yield
      Object.__send__ :remove_const, const_name
    end
  end

  def remove_constants(*constants)
    constants.each do |constant|
      Object.send(:remove_const, constant) if Object.const_defined?(constant)
    end
  end
end
