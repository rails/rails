require 'test/unit'
$LOAD_PATH.unshift File.dirname(__FILE__) + '/../lib/active_support/'
require 'dependencies'

class DependenciesTest < Test::Unit::TestCase
  def teardown
    Dependencies.clear
  end

  def test_require_dependency
    require_dependency(File.dirname(__FILE__) + "/dependencies/service_one")
    require_dependency(File.dirname(__FILE__) + "/dependencies/service_two")
    assert_equal 2, Dependencies.loaded.size
  end
  
  def test_require_dependency_two_times
    require_dependency(File.dirname(__FILE__) + "/dependencies/service_one")
    require_dependency(File.dirname(__FILE__) + "/dependencies/service_one")
    assert_equal 1, Dependencies.loaded.size
  end

  def test_require_missing_dependency
    assert_raises(MissingSourceFile) { require_dependency("missing_service") }
  end
  
  def test_require_missing_association
    assert_nothing_raised { require_association("missing_model") }
  end
end