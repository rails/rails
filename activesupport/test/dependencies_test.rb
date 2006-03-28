require 'test/unit'
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib/active_support/'
require 'core_ext/string'
require 'dependencies'

class DependenciesTest < Test::Unit::TestCase
  def teardown
    Dependencies.clear
  end
  
  def with_loading(from_dir = nil)
    prior_path = $LOAD_PATH.clone
    $LOAD_PATH.unshift "#{File.dirname(__FILE__)}/#{from_dir}" if from_dir
    old_mechanism, Dependencies.mechanism = Dependencies.mechanism, :load
    yield
  ensure
    $LOAD_PATH.clear
    $LOAD_PATH.concat prior_path
    Dependencies.mechanism = old_mechanism
  end

  def test_tracking_loaded_files
    require_dependency(File.dirname(__FILE__) + "/dependencies/service_one")
    require_dependency(File.dirname(__FILE__) + "/dependencies/service_two")
    assert_equal 2, Dependencies.loaded.size
  end

  def test_tracking_identical_loaded_files
    require_dependency(File.dirname(__FILE__) + "/dependencies/service_one")
    require_dependency(File.dirname(__FILE__) + "/dependencies/service_one")
    assert_equal 1, Dependencies.loaded.size
  end

  def test_missing_dependency_raises_missing_source_file
    assert_raises(MissingSourceFile) { require_dependency("missing_service") }
  end

  def test_missing_association_raises_nothing
    assert_nothing_raised { require_association("missing_model") }
  end

  def test_dependency_which_raises_exception_isnt_added_to_loaded_set
    with_loading do
      filename = "#{File.dirname(__FILE__)}/dependencies/raises_exception"
      $raises_exception_load_count = 0

      5.times do |count|
        assert_raises(RuntimeError) { require_dependency filename }
        assert_equal count + 1, $raises_exception_load_count

        assert !Dependencies.loaded.include?(filename)
        assert !Dependencies.history.include?(filename)
      end
    end
  end

  def test_warnings_should_be_enabled_on_first_load
    with_loading do
      old_warnings, Dependencies.warnings_on_first_load = Dependencies.warnings_on_first_load, true

      filename = "#{File.dirname(__FILE__)}/dependencies/check_warnings"
      $check_warnings_load_count = 0

      assert !Dependencies.loaded.include?(filename)
      assert !Dependencies.history.include?(filename)

      silence_warnings { require_dependency filename }
      assert_equal 1, $check_warnings_load_count
      assert_equal true, $checked_verbose, 'On first load warnings should be enabled.'

      assert Dependencies.loaded.include?(filename)
      Dependencies.clear
      assert !Dependencies.loaded.include?(filename)
      assert Dependencies.history.include?(filename)

      silence_warnings { require_dependency filename }
      assert_equal 2, $check_warnings_load_count
      assert_equal nil, $checked_verbose, 'After first load warnings should be left alone.'

      assert Dependencies.loaded.include?(filename)
      Dependencies.clear
      assert !Dependencies.loaded.include?(filename)
      assert Dependencies.history.include?(filename)

      enable_warnings { require_dependency filename }
      assert_equal 3, $check_warnings_load_count
      assert_equal true, $checked_verbose, 'After first load warnings should be left alone.'

      assert Dependencies.loaded.include?(filename)
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
  
  def test_as_load_path
    assert_equal '', DependenciesTest.as_load_path
  end
  
  def test_module_loading
    with_loading 'autoloading_fixtures' do
      assert_kind_of Module, A
      assert_kind_of Class, A::B
      assert_kind_of Class, A::C::D
      assert_kind_of Class, A::C::E::F
    end
  end
  
  def test_non_existing_const_raises_name_error
    with_loading 'autoloading_fixtures' do
      assert_raises(NameError) { DoesNotExist }
      assert_raises(NameError) { NoModule::DoesNotExist }
      assert_raises(NameError) { A::DoesNotExist }
      assert_raises(NameError) { A::B::DoesNotExist }
    end
  end
  
  def test_directories_should_manifest_as_modules
    with_loading 'autoloading_fixtures' do
      assert_kind_of Module, ModuleFolder
      Object.send :remove_const, :ModuleFolder
    end
  end
  
  def test_nested_class_access
    with_loading 'autoloading_fixtures' do
      assert_kind_of Class, ModuleFolder::NestedClass
      Object.send :remove_const, :ModuleFolder
    end
  end
  
  def test_nested_class_can_access_sibling
    with_loading 'autoloading_fixtures' do
      sibling = ModuleFolder::NestedClass.class_eval "NestedSibling"
      assert defined?(ModuleFolder::NestedSibling)
      assert_equal ModuleFolder::NestedSibling, sibling
      Object.send :remove_const, :ModuleFolder
    end
  end
  
  def failing_test_access_thru_and_upwards_fails
    with_loading 'autoloading_fixtures' do
      assert ! defined?(ModuleFolder)
      assert_raises(NameError) { ModuleFolder::Object }
      assert_raises(NameError) { ModuleFolder::NestedClass::Object }
      Object.send :remove_const, :ModuleFolder
    end
  end
  
end
