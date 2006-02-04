require 'test/unit'
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib/active_support/'
require 'core_ext/string'
require 'dependencies'

class DependenciesTest < Test::Unit::TestCase
  def teardown
    Dependencies.clear
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
    old_mechanism, Dependencies.mechanism = Dependencies.mechanism, :load

    filename = "#{File.dirname(__FILE__)}/dependencies/raises_exception"
    $raises_exception_load_count = 0

    5.times do |count|
      assert_raises(RuntimeError) { require_dependency filename }
      assert_equal count + 1, $raises_exception_load_count

      assert !Dependencies.loaded.include?(filename)
      assert !Dependencies.history.include?(filename)
    end
  ensure
    Dependencies.mechanism = old_mechanism
  end

  def test_warnings_should_be_enabled_on_first_load
    old_mechanism, Dependencies.mechanism = Dependencies.mechanism, :load
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
  ensure
    Dependencies.mechanism = old_mechanism
    Dependencies.warnings_on_first_load = old_warnings
  end

  def test_mutual_dependencies_dont_infinite_loop
    $LOAD_PATH.unshift "#{File.dirname(__FILE__)}/dependencies"
    old_mechanism, Dependencies.mechanism = Dependencies.mechanism, :load

    $mutual_dependencies_count = 0
    assert_nothing_raised { require_dependency 'mutual_one' }
    assert_equal 2, $mutual_dependencies_count

    Dependencies.clear

    $mutual_dependencies_count = 0
    assert_nothing_raised { require_dependency 'mutual_two' }
    assert_equal 2, $mutual_dependencies_count
  ensure
    $LOAD_PATH.shift
    Dependencies.mechanism = old_mechanism
  end
  
  def test_as_load_path
    assert_equal '', DependenciesTest.as_load_path
  end
  
  def test_module_loading
    begin
      $LOAD_PATH.unshift "#{File.dirname(__FILE__)}/autoloading_fixtures"
      old_mechanism, Dependencies.mechanism = Dependencies.mechanism, :load
    
      assert_kind_of Module, A
      assert_kind_of Class, A::B
      assert_kind_of Class, A::C::D
      assert_kind_of Class, A::C::E::F
    ensure
      $LOAD_PATH.shift
      Dependencies.mechanism = old_mechanism
    end
  end
  
  def test_non_existing_cost_raises_nameerrror
    begin
      $LOAD_PATH.unshift "#{File.dirname(__FILE__)}/autoloading_fixtures"
      old_mechanism, Dependencies.mechanism = Dependencies.mechanism, :load
      assert_raises(NameError) do
        DoesNotExist
      end
    
      assert_raises(NameError) do
        NoModule::DoesNotExist
      end
    
      assert_raises(NameError) do
        A::DoesNotExist
      end

      assert_raises(NameError) do
        A::B::DoesNotExist
      end
    ensure
      $LOAD_PATH.shift
      Dependencies.mechanism = old_mechanism
    end
    
  end
end
