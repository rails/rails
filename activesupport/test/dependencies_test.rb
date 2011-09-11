require 'abstract_unit'
require 'pp'
require 'active_support/dependencies'

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

class DependenciesTest < Test::Unit::TestCase
  Dependencies = ActiveSupport::Dependencies

  def teardown
    Dependencies.clear
  end

  def with_loading(*from)
    old_mechanism, Dependencies.mechanism = Dependencies.mechanism, :load
    this_dir = File.dirname(__FILE__)
    parent_dir = File.dirname(this_dir)
    path_copy = $LOAD_PATH.dup
    $LOAD_PATH.unshift(parent_dir) unless $LOAD_PATH.include?(parent_dir)
    prior_autoload_paths = Dependencies.autoload_paths
    Dependencies.autoload_paths = from.collect { |f| "#{this_dir}/#{f}" }
    yield
  ensure
    $LOAD_PATH.replace(path_copy)
    Dependencies.autoload_paths = prior_autoload_paths
    Dependencies.mechanism = old_mechanism
    Dependencies.explicitly_unloadable_constants = []
  end

  def with_autoloading_fixtures(&block)
    with_loading 'autoloading_fixtures', &block
  end

  def test_tracking_loaded_files
    require_dependency 'dependencies/service_one'
    require_dependency 'dependencies/service_two'
    assert_equal 2, Dependencies.loaded.size
  ensure
    Object.send(:remove_const, :ServiceOne) if Object.const_defined?(:ServiceOne)
    Object.send(:remove_const, :ServiceTwo) if Object.const_defined?(:ServiceTwo)
  end

  def test_tracking_identical_loaded_files
    require_dependency 'dependencies/service_one'
    require_dependency 'dependencies/service_one'
    assert_equal 1, Dependencies.loaded.size
  ensure
    Object.send(:remove_const, :ServiceOne) if Object.const_defined?(:ServiceOne)
  end

  def test_missing_dependency_raises_missing_source_file
    assert_raise(MissingSourceFile) { require_dependency("missing_service") }
  end

  def test_missing_association_raises_nothing
    assert_nothing_raised { require_association("missing_model") }
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

        assert !Dependencies.loaded.include?(filename)
        assert !Dependencies.history.include?(filename)
      end
    end
  end

  def test_warnings_should_be_enabled_on_first_load
    with_loading 'dependencies' do
      old_warnings, Dependencies.warnings_on_first_load = Dependencies.warnings_on_first_load, true

      filename = "check_warnings"
      expanded = File.expand_path("#{File.dirname(__FILE__)}/dependencies/#{filename}")
      $check_warnings_load_count = 0

      assert !Dependencies.loaded.include?(expanded)
      assert !Dependencies.history.include?(expanded)

      silence_warnings { require_dependency filename }
      assert_equal 1, $check_warnings_load_count
      assert_equal true, $checked_verbose, 'On first load warnings should be enabled.'

      assert Dependencies.loaded.include?(expanded)
      Dependencies.clear
      assert !Dependencies.loaded.include?(expanded)
      assert Dependencies.history.include?(expanded)

      silence_warnings { require_dependency filename }
      assert_equal 2, $check_warnings_load_count
      assert_equal nil, $checked_verbose, 'After first load warnings should be left alone.'

      assert Dependencies.loaded.include?(expanded)
      Dependencies.clear
      assert !Dependencies.loaded.include?(expanded)
      assert Dependencies.history.include?(expanded)

      enable_warnings { require_dependency filename }
      assert_equal 3, $check_warnings_load_count
      assert_equal true, $checked_verbose, 'After first load warnings should be left alone.'

      assert Dependencies.loaded.include?(expanded)
      Dependencies.warnings_on_first_load = old_warnings
    end
  end

  def test_mutual_dependencies_dont_infinite_loop
    with_loading 'dependencies' do
      $mutual_dependencies_count = 0
      assert_nothing_raised { require_dependency 'mutual_one' }
      assert_equal 2, $mutual_dependencies_count

      Dependencies.clear

      $mutual_dependencies_count = 0
      assert_nothing_raised { require_dependency 'mutual_two' }
      assert_equal 2, $mutual_dependencies_count
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
      Dependencies.clear
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
      Dependencies.clear
      _ = LoadsConstant
      assert defined?(LoadsConstant)
      assert defined?(LoadedConstant)
    end
  ensure
    remove_constants(:RequiresConstant, :LoadedConstant, :LoadsConstant)
    $".replace(original_features)
    $:.replace(original_path)
  end

  def failing_test_access_thru_and_upwards_fails
    with_autoloading_fixtures do
      assert !defined?(ModuleFolder)
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
    begin
      Object.module_eval "ImaginaryObject"
      flunk "No raise!!"
    rescue NameError => e
      assert e.message.include?("uninitialized constant ImaginaryObject")
    end
  end

  def test_loadable_constants_for_path_should_handle_empty_autoloads
    assert_equal [], Dependencies.loadable_constants_for_path('hello')
  end

  def test_loadable_constants_for_path_should_handle_relative_paths
    fake_root = 'dependencies'
    relative_root = File.dirname(__FILE__) + '/dependencies'
    ['', '/'].each do |suffix|
      with_loading fake_root + suffix do
        assert_equal ["A::B"], Dependencies.loadable_constants_for_path(relative_root + '/a/b')
      end
    end
  end

  def test_loadable_constants_for_path_should_provide_all_results
    fake_root = '/usr/apps/backpack'
    with_loading fake_root, fake_root + '/lib' do
      root = Dependencies.autoload_paths.first
      assert_equal ["Lib::A::B", "A::B"], Dependencies.loadable_constants_for_path(root + '/lib/a/b')
    end
  end

  def test_loadable_constants_for_path_should_uniq_results
    fake_root = '/usr/apps/backpack/lib'
    with_loading fake_root, fake_root + '/' do
      root = Dependencies.autoload_paths.first
      assert_equal ["A::B"], Dependencies.loadable_constants_for_path(root + '/a/b')
    end
  end

  def test_loadable_constants_with_load_path_without_trailing_slash
    path = File.dirname(__FILE__) + '/autoloading_fixtures/class_folder/inline_class.rb'
    with_loading 'autoloading_fixtures/class/' do
      assert_equal [], Dependencies.loadable_constants_for_path(path)
    end
  end

  def test_qualified_const_defined
    assert Dependencies.qualified_const_defined?("Object")
    assert Dependencies.qualified_const_defined?("::Object")
    assert Dependencies.qualified_const_defined?("::Object::Kernel")
    assert Dependencies.qualified_const_defined?("::Test::Unit::TestCase")
  end

  def test_qualified_const_defined_should_not_call_const_missing
    ModuleWithMissing.missing_count = 0
    assert !Dependencies.qualified_const_defined?("ModuleWithMissing::A")
    assert_equal 0, ModuleWithMissing.missing_count
    assert !Dependencies.qualified_const_defined?("ModuleWithMissing::A::B")
    assert_equal 0, ModuleWithMissing.missing_count
  end

  def test_qualified_const_defined_explodes_with_invalid_const_name
    assert_raises(NameError) { Dependencies.qualified_const_defined?("invalid") }
  end

  def test_autoloaded?
    with_autoloading_fixtures do
      assert !Dependencies.autoloaded?("ModuleFolder")
      assert !Dependencies.autoloaded?("ModuleFolder::NestedClass")

      assert Dependencies.autoloaded?(ModuleFolder)

      assert Dependencies.autoloaded?("ModuleFolder")
      assert !Dependencies.autoloaded?("ModuleFolder::NestedClass")

      assert Dependencies.autoloaded?(ModuleFolder::NestedClass)

      assert Dependencies.autoloaded?("ModuleFolder")
      assert Dependencies.autoloaded?("ModuleFolder::NestedClass")

      assert Dependencies.autoloaded?("::ModuleFolder")
      assert Dependencies.autoloaded?(:ModuleFolder)

      # Anonymous modules aren't autoloaded.
      assert !Dependencies.autoloaded?(Module.new)

      nil_name = Module.new
      def nil_name.name() nil end
      assert !Dependencies.autoloaded?(nil_name)

      Object.class_eval { remove_const :ModuleFolder }
    end
  end

  def test_qualified_name_for
    assert_equal "A", Dependencies.qualified_name_for(Object, :A)
    assert_equal "A", Dependencies.qualified_name_for(:Object, :A)
    assert_equal "A", Dependencies.qualified_name_for("Object", :A)
    assert_equal "A", Dependencies.qualified_name_for("::Object", :A)

    assert_equal "ActiveSupport::Dependencies::A",
      Dependencies.qualified_name_for(:'ActiveSupport::Dependencies', :A)

    assert_equal "ActiveSupport::Dependencies::A",
      Dependencies.qualified_name_for(ActiveSupport::Dependencies, :A)
  end

  def test_file_search
    with_loading 'dependencies' do
      root = Dependencies.autoload_paths.first
      assert_equal nil, Dependencies.search_for_file('service_three')
      assert_equal nil, Dependencies.search_for_file('service_three.rb')
      assert_equal root + '/service_one.rb', Dependencies.search_for_file('service_one')
      assert_equal root + '/service_one.rb', Dependencies.search_for_file('service_one.rb')
    end
  end

  def test_file_search_uses_first_in_load_path
    with_loading 'dependencies', 'autoloading_fixtures' do
      deps, autoload = Dependencies.autoload_paths
      assert_match %r/dependencies/, deps
      assert_match %r/autoloading_fixtures/, autoload

      assert_equal deps + '/conflict.rb', Dependencies.search_for_file('conflict')
    end
    with_loading 'autoloading_fixtures', 'dependencies' do
      autoload, deps = Dependencies.autoload_paths
      assert_match %r/dependencies/, deps
      assert_match %r/autoloading_fixtures/, autoload

      assert_equal autoload + '/conflict.rb', Dependencies.search_for_file('conflict')
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
      assert_raise(NameError) { Dependencies.load_missing_constant Object, :CountingLoader }
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
      Dependencies.clear
      assert !defined?(ServiceOne)
      begin
        Dependencies.load_missing_constant(c, :FakeMissing)
        flunk "Expected exception"
      rescue ArgumentError => e
        assert_match %r{ServiceOne has been removed from the module tree}i, e.message
      end
    end
  end

  def test_references_should_work
    with_loading 'dependencies' do
      c = Dependencies.reference("ServiceOne")
      service_one_first = ServiceOne
      assert_equal service_one_first, c.get("ServiceOne")
      Dependencies.clear
      assert !defined?(ServiceOne)

      service_one_second = ServiceOne
      assert_not_equal service_one_first, c.get("ServiceOne")
      assert_equal service_one_second, c.get("ServiceOne")
    end
  end

  def test_constantize_shortcut_for_cached_constant_lookups
    with_loading 'dependencies' do
      assert_equal ServiceOne, Dependencies.constantize("ServiceOne")
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
      Dependencies.autoload_once_paths = Dependencies.autoload_paths.dup

      assert !Dependencies.autoloaded?("ModuleFolder")
      assert !Dependencies.autoloaded?("ModuleFolder::NestedClass")
      assert !Dependencies.autoloaded?(ModuleFolder)

      1 if ModuleFolder::NestedClass # 1 if to avoid warning
      assert !Dependencies.autoloaded?(ModuleFolder::NestedClass)
    end
  ensure
    Object.class_eval { remove_const :ModuleFolder }
    Dependencies.autoload_once_paths = []
  end

  def test_autoload_once_pathnames_do_not_add_to_autoloaded_constants
    with_autoloading_fixtures do
      pathnames = Dependencies.autoload_paths.collect { |p| Pathname.new(p) }
      Dependencies.autoload_paths = pathnames
      Dependencies.autoload_once_paths = pathnames

      assert !Dependencies.autoloaded?("ModuleFolder")
      assert !Dependencies.autoloaded?("ModuleFolder::NestedClass")
      assert !Dependencies.autoloaded?(ModuleFolder)

      1 if ModuleFolder::NestedClass # 1 if to avoid warning
      assert !Dependencies.autoloaded?(ModuleFolder::NestedClass)
    end
  ensure
    Object.class_eval { remove_const :ModuleFolder }
    Dependencies.autoload_once_paths = []
  end

  def test_application_should_special_case_application_controller
    with_autoloading_fixtures do
      require_dependency 'application'
      assert_equal 10, ApplicationController
      assert Dependencies.autoloaded?(:ApplicationController)
    end
  end

  def test_preexisting_constants_are_not_marked_as_autoloaded
    with_autoloading_fixtures do
      require_dependency 'e'
      assert Dependencies.autoloaded?(:E)
      Dependencies.clear
    end

    Object.const_set :E, Class.new
    with_autoloading_fixtures do
      require_dependency 'e'
      assert !Dependencies.autoloaded?(:E), "E shouldn't be marked autoloaded!"
      Dependencies.clear
    end

  ensure
    Object.class_eval { remove_const :E }
  end

  def test_unloadable
    with_autoloading_fixtures do
      Object.const_set :M, Module.new
      M.unloadable

      Dependencies.clear
      assert !defined?(M)

      Object.const_set :M, Module.new
      Dependencies.clear
      assert !defined?(M), "Dependencies should unload unloadable constants each time"
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
  end

  def test_unloadable_constants_should_receive_callback
    Object.const_set :C, Class.new
    C.unloadable
    C.expects(:before_remove_const).once
    assert C.respond_to?(:before_remove_const)
    Dependencies.clear
    assert !defined?(C)
  ensure
    Object.class_eval { remove_const :C } if defined?(C)
  end

  def test_new_contants_in_without_constants
    assert_equal [], (Dependencies.new_constants_in(Object) { })
    assert Dependencies.constant_watch_stack.all? {|k,v| v.empty? }
  end

  def test_new_constants_in_with_a_single_constant
    assert_equal ["Hello"], Dependencies.new_constants_in(Object) {
                              Object.const_set :Hello, 10
                            }.map(&:to_s)
    assert Dependencies.constant_watch_stack.all? {|k,v| v.empty? }
  ensure
    Object.class_eval { remove_const :Hello }
  end

  def test_new_constants_in_with_nesting
    outer = Dependencies.new_constants_in(Object) do
      Object.const_set :OuterBefore, 10

      assert_equal ["Inner"], Dependencies.new_constants_in(Object) {
                                Object.const_set :Inner, 20
                              }.map(&:to_s)

      Object.const_set :OuterAfter, 30
    end

    assert_equal ["OuterAfter", "OuterBefore"], outer.sort.map(&:to_s)
    assert Dependencies.constant_watch_stack.all? {|k,v| v.empty? }
  ensure
    %w(OuterBefore Inner OuterAfter).each do |name|
      Object.class_eval { remove_const name if const_defined?(name) }
    end
  end

  def test_new_constants_in_module
    Object.const_set :M, Module.new

    outer = Dependencies.new_constants_in(M) do
      M.const_set :OuterBefore, 10

      inner = Dependencies.new_constants_in(M) do
        M.const_set :Inner, 20
      end
      assert_equal ["M::Inner"], inner

      M.const_set :OuterAfter, 30
    end
    assert_equal ["M::OuterAfter", "M::OuterBefore"], outer.sort
    assert Dependencies.constant_watch_stack.all? {|k,v| v.empty? }
  ensure
    Object.class_eval { remove_const :M }
  end

  def test_new_constants_in_module_using_name
    outer = Dependencies.new_constants_in(:M) do
      Object.const_set :M, Module.new
      M.const_set :OuterBefore, 10

      inner = Dependencies.new_constants_in(:M) do
        M.const_set :Inner, 20
      end
      assert_equal ["M::Inner"], inner

      M.const_set :OuterAfter, 30
    end
    assert_equal ["M::OuterAfter", "M::OuterBefore"], outer.sort
    assert Dependencies.constant_watch_stack.all? {|k,v| v.empty? }
  ensure
    Object.class_eval { remove_const :M }
  end

  def test_new_constants_in_with_inherited_constants
    m = Dependencies.new_constants_in(:Object) do
      Object.class_eval { include ModuleWithConstant }
    end
    assert_equal [], m
  end

  def test_new_constants_in_with_illegal_module_name_raises_correct_error
    assert_raise(NameError) do
      Dependencies.new_constants_in("Illegal-Name") {}
    end
  end

  def test_file_with_multiple_constants_and_require_dependency
    with_autoloading_fixtures do
      assert !defined?(MultipleConstantFile)
      assert !defined?(SiblingConstant)

      require_dependency 'multiple_constant_file'
      assert defined?(MultipleConstantFile)
      assert defined?(SiblingConstant)
      assert Dependencies.autoloaded?(:MultipleConstantFile)
      assert Dependencies.autoloaded?(:SiblingConstant)

      Dependencies.clear

      assert !defined?(MultipleConstantFile)
      assert !defined?(SiblingConstant)
    end
  end

  def test_file_with_multiple_constants_and_auto_loading
    with_autoloading_fixtures do
      assert !defined?(MultipleConstantFile)
      assert !defined?(SiblingConstant)

      assert_equal 10, MultipleConstantFile

      assert defined?(MultipleConstantFile)
      assert defined?(SiblingConstant)
      assert Dependencies.autoloaded?(:MultipleConstantFile)
      assert Dependencies.autoloaded?(:SiblingConstant)

      Dependencies.clear

      assert !defined?(MultipleConstantFile)
      assert !defined?(SiblingConstant)
    end
  end

  def test_nested_file_with_multiple_constants_and_require_dependency
    with_autoloading_fixtures do
      assert !defined?(ClassFolder::NestedClass)
      assert !defined?(ClassFolder::SiblingClass)

      require_dependency 'class_folder/nested_class'

      assert defined?(ClassFolder::NestedClass)
      assert defined?(ClassFolder::SiblingClass)
      assert Dependencies.autoloaded?("ClassFolder::NestedClass")
      assert Dependencies.autoloaded?("ClassFolder::SiblingClass")

      Dependencies.clear

      assert !defined?(ClassFolder::NestedClass)
      assert !defined?(ClassFolder::SiblingClass)
    end
  end

  def test_nested_file_with_multiple_constants_and_auto_loading
    with_autoloading_fixtures do
      assert !defined?(ClassFolder::NestedClass)
      assert !defined?(ClassFolder::SiblingClass)

      assert_kind_of Class, ClassFolder::NestedClass

      assert defined?(ClassFolder::NestedClass)
      assert defined?(ClassFolder::SiblingClass)
      assert Dependencies.autoloaded?("ClassFolder::NestedClass")
      assert Dependencies.autoloaded?("ClassFolder::SiblingClass")

      Dependencies.clear

      assert !defined?(ClassFolder::NestedClass)
      assert !defined?(ClassFolder::SiblingClass)
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
      Dependencies.mechanism = :require
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
    Dependencies.remove_constant "::DeleteMe::OrMe"
    assert !defined?(DeleteMe::OrMe)
    assert defined?(DeleteMe)
    Dependencies.remove_constant "::DeleteMe"
    assert !defined?(DeleteMe)
  end

  def test_load_once_constants_should_not_be_unloaded
    with_autoloading_fixtures do
      Dependencies.autoload_once_paths = Dependencies.autoload_paths
      ::A.to_s
      assert defined?(A)
      Dependencies.clear
      assert defined?(A)
    end
  ensure
    Dependencies.autoload_once_paths = []
    Object.class_eval { remove_const :A if const_defined?(:A) }
  end

  def test_autoload_once_paths_should_behave_when_recursively_loading
    with_loading 'dependencies', 'autoloading_fixtures' do
      Dependencies.autoload_once_paths = [Dependencies.autoload_paths.last]
      assert !defined?(CrossSiteDependency)
      assert_nothing_raised { CrossSiteDepender.nil? }
      assert defined?(CrossSiteDependency)
      assert !Dependencies.autoloaded?(CrossSiteDependency),
        "CrossSiteDependency shouldn't be marked as autoloaded!"
      Dependencies.clear
      assert defined?(CrossSiteDependency),
        "CrossSiteDependency shouldn't have been unloaded!"
    end
  ensure
    Dependencies.autoload_once_paths = []
  end

  def test_hook_called_multiple_times
    assert_nothing_raised { Dependencies.hook! }
  end

  def test_unhook
    Dependencies.unhook!
    assert !Module.new.respond_to?(:const_missing_without_dependencies)
    assert !Module.new.respond_to?(:load_without_new_constant_marking)
  ensure
    Dependencies.hook!
  end

private
  def remove_constants(*constants)
    constants.each do |constant|
      Object.send(:remove_const, constant) if Object.const_defined?(constant)
    end
  end
end
