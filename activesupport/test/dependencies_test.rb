require File.dirname(__FILE__) + '/../abstract_unit'
require 'action_controller/support/dependencies'

$LOAD_PATH << File.dirname(__FILE__) + '/../fixtures/dependencies'

class DependenciesTest < Test::Unit::TestCase
  def teardown
    Dependencies.clear
  end

  def test_require_dependency
    require_dependency("service_one")
    require_dependency("service_two")
    assert_equal 2, Dependencies.loaded.size
  end
  
  def test_require_dependency_two_times
    require_dependency("service_one")
    require_dependency("service_one")
    assert_equal 1, Dependencies.loaded.size
  end

  def test_reloading_dependency
    require_dependency("service_one")
    require_dependency("service_one")
    assert_equal 1, $loaded_service_one

    Dependencies.reload
    assert_equal 2, $loaded_service_one
  end

  def test_require_missing_dependency
    assert_raises(LoadError) { require_dependency("missing_service") }
  end
  
  def test_require_missing_association
    assert_nothing_raised { require_association("missing_model") }
  end
end