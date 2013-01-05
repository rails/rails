require 'abstract_unit'
require 'pp'
require 'active_support/dependencies'
require 'dependecies_test_helpers'

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
    ActiveSupport::Dependencies.clear
  end

  include DependeciesTestHelpers

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

  def test_tracking_loaded_files
    require_dependency 'dependencies/service_one'
    require_dependency 'dependencies/service_two'
    assert_equal 2, ActiveSupport::Dependencies.loaded.size
  ensure
    Object.send(:remove_const, :ServiceOne) if Object.const_defined?(:ServiceOne)
    Object.send(:remove_const, :ServiceTwo) if Object.const_defined?(:ServiceTwo)
  end

  def test_tracking_identical_loaded_files
    require_dependency 'dependencies/service_one'
    require_dependency 'dependencies/service_one'
    assert_equal 1, ActiveSupport::Dependencies.loaded.size
  ensure
    Object.send(:remove_const, :ServiceOne) if Object.const_defined?(:ServiceOne)
  end

  def test_missing_dependency_raises_missing_source_file
    assert_raise(MissingSourceFile) { require_dependency("missing_service") }
  end

  def test_dependency_which_raises_exception_isnt_added_to_loaded_set
    with_loading do
      filename = 'dependencies/raises_exception'
      $raises_exception_load_count = 0

      5.times do |count|
        begin
          require_dependency filename
          flunk 'should have loaded dependencies/raises_exception which raises an exception'
        rescue Exception => e
          assert_equal 'Loading me failed, so do not add to loaded or history.', e.message
        end
        assert_equal count + 1, $raises_exception_load_count

        assert !ActiveSupport::Dependencies.loaded.include?(filename)
        assert !ActiveSupport::Dependencies.history.include?(filename)
      end
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
      ActiveSupport::Dependencies.clear
      assert !ActiveSupport::Dependencies.loaded.include?(expanded)
      assert ActiveSupport::Dependencies.history.include?(expanded)

      silence_warnings { require_dependency filename }
      assert_equal 2, $check_warnings_load_count
      assert_equal nil, $checked_verbose, 'After first load warnings should be left alone.'

      assert ActiveSupport::Dependencies.loaded.include?(expanded)
      ActiveSupport::Dependencies.clear
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

      ActiveSupport::Dependencies.clear

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
    with_autoloading_fixtures do
      assert_kind_of Module, ModuleFolder
      Object.__send__ :remove_const, :ModuleFolder
    end
  end

  def test_module_with_nested_class
    with_autoloading_fixtures do
      assert_kind_of Class, ModuleFolder::NestedClass
      Object.__send__ :remove_const, :ModuleFolder
    end
  end

  def test_module_with_nested_inline_class
    with_autoloading_fixtures do
      assert_kind_of Class, ModuleFolder::InlineClass
      Object.__send__ :remove_const, :ModuleFolder
    end
  end

  def test_directories_may_manifest_as_nested_classes
    with_autoloading_fixtures do
      assert_kind_of Class, ClassFolder
      Object.__send__ :remove_const, :ClassFolder
    end
  end

  def test_class_with_nested_class
    with_autoloading_fixtures do
      assert_kind_of Class, ClassFolder::NestedClass
      Object.__send__ :remove_const, :ClassFolder
    end
  end

  def test_class_with_nested_inline_class
    with_autoloading_fixtures do
      assert_kind_of Class, ClassFolder::InlineClass
      Object.__send__ :remove_const, :ClassFolder
    end
  end

  def test_class_with_nested_inline_subclass_of_parent
    with_autoloading_fixtures do
      assert_kind_of Class, ClassFolder::ClassFolderSubclass
      assert_kind_of Class, ClassFolder
      assert_equal 'indeed', ClassFolder::ClassFolderSubclass::ConstantInClassFolder
      Object.__send__ :remove_const, :ClassFolder
    end
  end

  def test_nested_class_can_access_sibling
    with_autoloading_fixtures do
      sibling = ModuleFolder::NestedClass.class_eval "NestedSibling"
      assert defined?(ModuleFolder::NestedSibling)
      assert_equal ModuleFolder::NestedSibling, sibling
      Object.__send__ :remove_const, :ModuleFolder
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
      ActiveSupport::Dependencies.clear
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
      ActiveSupport::Dependencies.clear
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
    with_autoloading_fixtures do
      assert ! defined?(ModuleFolder)
      assert_raise(NameError) { ModuleFolder::Object }
      assert_raise(NameError) { ModuleFolder::NestedClass::Object }
      Object.__send__ :remove_const, :ModuleFolder
    end
  end

  def test_non_existing_const_raises_name_error_with_fully_qualified_name
    with_autoloading_fixtures do
      begin
        A::DoesNotExist.nil?
        flunk "No raise!!"
      rescue NameError => e
        assert_equal "uninitialized constant A::DoesNotExist", e.message
      end
      begin
        A::B::DoesNotExist.nil?
        flunk "No raise!!"
      rescue NameError => e
        assert_equal "uninitialized constant A::B::DoesNotExist", e.message
      end
    end
  end

  def test_smart_name_error_strings
    Object.module_eval "ImaginaryObject"
    flunk "No raise!!"
  rescue NameError => e
    assert e.message.include?("uninitialized constant ImaginaryObject")
  end

  def test_loadable_constants_for_path_should_handle_empty_autoloads
    assert_equal [], ActiveSupport::Dependencies.loadable_constants_for_path('hello')
  end

  def test_loadable_constants_for_path_should_handle_relative_paths
    fake_root = 'dependencies'
    relative_root = File.dirname(__FILE__) + '/dependencies'
    ['', '/'].each do |suffix|
      with_loading fake_root + suffix do
        assert_equal ["A::B"], ActiveSupport::Dependencies.loadable_constants_for_path(relative_root + '/a/b')
      end
    end
  end

  def test_loadable_constants_for_path_should_provide_all_results
    fake_root = '/usr/apps/backpack'
    with_loading fake_root, fake_root + '/lib' do
      root = ActiveSupport::Dependencies.autoload_paths.first
      assert_equal ["Lib::A::B", "A::B"], ActiveSupport::Dependencies.loadable_constants_for_path(root + '/lib/a/b')
    end
  end

  def test_loadable_constants_for_path_should_uniq_results
    fake_root = '/usr/apps/backpack/lib'
    with_loading fake_root, fake_root + '/' do
      root = ActiveSupport::Dependencies.autoload_paths.first
      assert_equal ["A::B"], ActiveSupport::Dependencies.loadable_constants_for_path(root + '/a/b')
    end
  end

  def test_loadable_constants_with_load_path_without_trailing_slash
    path = File.dirname(__FILE__) + '/autoloading_fixtures/class_folder/inline_class.rb'
    with_loading 'autoloading_fixtures/class/' do
      assert_equal [], ActiveSupport::Dependencies.loadable_constants_for_path(path)
    end
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

  def test_const_missing_should_not_double_load
    $counting_loaded_times = 0
    with_autoloading_fixtures do
      require_dependency '././counting_loader'
      assert_equal 1, $counting_loaded_times
      assert_raise(NameError) { ActiveSupport::Dependencies.load_missing_constant Object, :CountingLoader }
      assert_equal 1, $counting_loaded_times
    end
  end

  def test_const_missing_within_anonymous_module
    $counting_loaded_times = 0
    m = Module.new
    m.module_eval "def a() CountingLoader; end"
    extend m
    kls = nil
    with_autoloading_fixtures do
      kls = nil
      assert_nothing_raised { kls = a }
      assert_equal "CountingLoader", kls.name
      assert_equal 1, $counting_loaded_times

      assert_nothing_raised { kls = a }
      assert_equal 1, $counting_loaded_times
    end
  end

  def test_removal_from_tree_should_be_detected
    with_loading 'dependencies' do
      c = ServiceOne
      ActiveSupport::Dependencies.clear
      assert ! defined?(ServiceOne)
      begin
        ActiveSupport::Dependencies.load_missing_constant(c, :FakeMissing)
        flunk "Expected exception"
      rescue ArgumentError => e
        assert_match %r{ServiceOne has been removed from the module tree}i, e.message
      end
    end
  end

  def test_references_should_work
    with_loading 'dependencies' do
      c = ActiveSupport::Dependencies.reference("ServiceOne")
      service_one_first = ServiceOne
      assert_equal service_one_first, c.get("ServiceOne")
      ActiveSupport::Dependencies.clear
      assert ! defined?(ServiceOne)

      service_one_second = ServiceOne
      assert_not_equal service_one_first, c.get("ServiceOne")
      assert_equal service_one_second, c.get("ServiceOne")
    end
  end

  def test_constantize_shortcut_for_cached_constant_lookups
    with_loading 'dependencies' do
      assert_equal ServiceOne, ActiveSupport::Dependencies.constantize("ServiceOne")
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

  def test_application_should_special_case_application_controller
    with_autoloading_fixtures do
      require_dependency 'application'
      assert_equal 10, ApplicationController
      assert ActiveSupport::Dependencies.autoloaded?(:ApplicationController)
    end
  end

  def test_preexisting_constants_are_not_marked_as_autoloaded
    with_autoloading_fixtures do
      require_dependency 'e'
      assert ActiveSupport::Dependencies.autoloaded?(:E)
      ActiveSupport::Dependencies.clear
    end

    Object.const_set :E, Class.new
    with_autoloading_fixtures do
      require_dependency 'e'
      assert ! ActiveSupport::Dependencies.autoloaded?(:E), "E shouldn't be marked autoloaded!"
      ActiveSupport::Dependencies.clear
    end

  ensure
    Object.class_eval { remove_const :E }
  end

  def test_unloadable
    with_autoloading_fixtures do
      Object.const_set :M, Module.new
      M.unloadable

      ActiveSupport::Dependencies.clear
      assert ! defined?(M)

      Object.const_set :M, Module.new
      ActiveSupport::Dependencies.clear
      assert ! defined?(M), "Dependencies should unload unloadable constants each time"
    end
  end

  def test_unloadable_should_fail_with_anonymous_modules
    with_autoloading_fixtures do
      m = Module.new
      assert_raise(ArgumentError) { m.unloadable }
    end
  end

  def test_unloadable_should_return_change_flag
    with_autoloading_fixtures do
      Object.const_set :M, Module.new
      assert_equal true, M.unloadable
      assert_equal false, M.unloadable
    end
  ensure
    Object.class_eval { remove_const :M }
  end

  def test_unloadable_constants_should_receive_callback
    Object.const_set :C, Class.new
    C.unloadable
    C.expects(:before_remove_const).once
    assert C.respond_to?(:before_remove_const)
    ActiveSupport::Dependencies.clear
    assert !defined?(C)
  ensure
    Object.class_eval { remove_const :C } if defined?(C)
  end

  def test_new_contants_in_without_constants
    assert_equal [], (ActiveSupport::Dependencies.new_constants_in(Object) { })
    assert ActiveSupport::Dependencies.constant_watch_stack.all? {|k,v| v.empty? }
  end

  def test_new_constants_in_with_a_single_constant
    assert_equal ["Hello"], ActiveSupport::Dependencies.new_constants_in(Object) {
                              Object.const_set :Hello, 10
                            }.map(&:to_s)
    assert ActiveSupport::Dependencies.constant_watch_stack.all? {|k,v| v.empty? }
  ensure
    Object.class_eval { remove_const :Hello }
  end

  def test_new_constants_in_with_nesting
    outer = ActiveSupport::Dependencies.new_constants_in(Object) do
      Object.const_set :OuterBefore, 10

      assert_equal ["Inner"], ActiveSupport::Dependencies.new_constants_in(Object) {
                                Object.const_set :Inner, 20
                              }.map(&:to_s)

      Object.const_set :OuterAfter, 30
    end

    assert_equal ["OuterAfter", "OuterBefore"], outer.sort.map(&:to_s)
    assert ActiveSupport::Dependencies.constant_watch_stack.all? {|k,v| v.empty? }
  ensure
    %w(OuterBefore Inner OuterAfter).each do |name|
      Object.class_eval { remove_const name if const_defined?(name) }
    end
  end

  def test_new_constants_in_module
    Object.const_set :M, Module.new

    outer = ActiveSupport::Dependencies.new_constants_in(M) do
      M.const_set :OuterBefore, 10

      inner = ActiveSupport::Dependencies.new_constants_in(M) do
        M.const_set :Inner, 20
      end
      assert_equal ["M::Inner"], inner

      M.const_set :OuterAfter, 30
    end
    assert_equal ["M::OuterAfter", "M::OuterBefore"], outer.sort
    assert ActiveSupport::Dependencies.constant_watch_stack.all? {|k,v| v.empty? }
  ensure
    Object.class_eval { remove_const :M }
  end

  def test_new_constants_in_module_using_name
    outer = ActiveSupport::Dependencies.new_constants_in(:M) do
      Object.const_set :M, Module.new
      M.const_set :OuterBefore, 10

      inner = ActiveSupport::Dependencies.new_constants_in(:M) do
        M.const_set :Inner, 20
      end
      assert_equal ["M::Inner"], inner

      M.const_set :OuterAfter, 30
    end
    assert_equal ["M::OuterAfter", "M::OuterBefore"], outer.sort
    assert ActiveSupport::Dependencies.constant_watch_stack.all? {|k,v| v.empty? }
  ensure
    Object.class_eval { remove_const :M }
  end

  def test_new_constants_in_with_inherited_constants
    m = ActiveSupport::Dependencies.new_constants_in(:Object) do
      Object.class_eval { include ModuleWithConstant }
    end
    assert_equal [], m
  end

  def test_new_constants_in_with_illegal_module_name_raises_correct_error
    assert_raise(NameError) do
      ActiveSupport::Dependencies.new_constants_in("Illegal-Name") {}
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

      ActiveSupport::Dependencies.clear

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

      ActiveSupport::Dependencies.clear

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

      ActiveSupport::Dependencies.clear

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

      ActiveSupport::Dependencies.clear

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
      2.times do |i|
        begin
          ::RaisesNameError::FooBarBaz.object_id
          flunk 'should have raised NameError when autoloaded file referenced FooBarBaz'
        rescue NameError => e
          assert_equal 'uninitialized constant RaisesNameError::FooBarBaz', e.message
        end
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
      ActiveSupport::Dependencies.clear
      assert defined?(A)
    end
  ensure
    ActiveSupport::Dependencies.autoload_once_paths = []
    Object.class_eval { remove_const :A if const_defined?(:A) }
  end

  def test_autoload_once_paths_should_behave_when_recursively_loading
    with_loading 'dependencies', 'autoloading_fixtures' do
      ActiveSupport::Dependencies.autoload_once_paths = [ActiveSupport::Dependencies.autoload_paths.last]
      assert !defined?(CrossSiteDependency)
      assert_nothing_raised { CrossSiteDepender.nil? }
      assert defined?(CrossSiteDependency)
      assert !ActiveSupport::Dependencies.autoloaded?(CrossSiteDependency),
        "CrossSiteDependency shouldn't be marked as autoloaded!"
      ActiveSupport::Dependencies.clear
      assert defined?(CrossSiteDependency),
        "CrossSiteDependency shouldn't have been unloaded!"
    end
  ensure
    ActiveSupport::Dependencies.autoload_once_paths = []
  end

  def test_hook_called_multiple_times
    assert_nothing_raised { ActiveSupport::Dependencies.hook! }
  end

  def test_unhook
    ActiveSupport::Dependencies.unhook!
    assert !Module.new.respond_to?(:const_missing_without_dependencies)
    assert !Module.new.respond_to?(:load_without_new_constant_marking)
  ensure
    ActiveSupport::Dependencies.hook!
  end

private
  def remove_constants(*constants)
    constants.each do |constant|
      Object.send(:remove_const, constant) if Object.const_defined?(constant)
    end
  end
end
