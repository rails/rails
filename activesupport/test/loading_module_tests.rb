require 'test/unit'
require File.dirname(__FILE__) + '/../lib/active_support/core_ext.rb'
require File.dirname(__FILE__) + '/../lib/active_support/dependencies.rb'

STAGING_DIRECTORY = File.join(File.dirname(__FILE__), 'loading_module')
COMPONENTS_DIRECTORY = File.join(File.dirname(__FILE__), 'loading_module_components')

class LoadingModuleTests < Test::Unit::TestCase
  def setup
    @loading_module = Dependencies::LoadingModule.root(STAGING_DIRECTORY)
    Object.const_set(:Controllers, @loading_module)
  end
  def teardown
    @loading_module.clear
    Object.send :remove_const, :Controllers
  end
  
  def test_setup
    assert_kind_of Dependencies::LoadingModule, @loading_module
  end
  
  def test_const_available
    assert @loading_module.const_available?(:Admin)
    assert @loading_module.const_available?(:ResourceController)
    assert @loading_module.const_available?(:ContentController)
    assert @loading_module.const_available?("ContentController")
    
    assert_equal false, @loading_module.const_available?(:AdminController)
    assert_equal false, @loading_module.const_available?(:RandomName)
  end
  
  def test_const_load_module
    assert @loading_module.const_load!(:Admin)
    assert_kind_of Module, @loading_module::Admin
    assert_kind_of Dependencies::LoadingModule, @loading_module::Admin
  end

  def test_const_load_controller
    assert @loading_module.const_load!(:ContentController)
    assert_kind_of Class, @loading_module::ContentController
  end
  
  def test_const_load_nested_controller
    assert @loading_module.const_load!(:Admin)
    assert @loading_module::Admin.const_available?(:UserController)
    assert @loading_module::Admin.const_load!(:UserController)
    assert_kind_of Class, @loading_module::Admin::UserController
  end
  
  def test_pretty_access
    assert_kind_of Module, @loading_module::Admin
    assert_kind_of Dependencies::LoadingModule, @loading_module::Admin
    
    assert_kind_of Class, @loading_module::Admin::UserController
    assert_kind_of Class, @loading_module::Admin::AccessController
    assert_kind_of Class, @loading_module::ResourceController
    assert_kind_of Class, @loading_module::ContentController
  end
  
  def test_missing_name
    assert_raises(NameError) {@loading_module::PersonController}
    assert_raises(NameError) {@loading_module::Admin::FishController}
  end
end

class LoadingModuleMultiPathTests < Test::Unit::TestCase
  def setup
    @loading_module = Dependencies::LoadingModule.root(STAGING_DIRECTORY, COMPONENTS_DIRECTORY)
    Object.const_set(:Controllers, @loading_module)
  end
  def teardown
    @loading_module.clear
    Object.send :remove_const, :Controllers
  end
  
  def test_access_from_first
    assert_kind_of Module, @loading_module::Admin
    assert_kind_of Dependencies::LoadingModule, @loading_module::Admin
    assert_kind_of Class, @loading_module::Admin::UserController
  end
  def test_access_from_second
    assert_kind_of Module, @loading_module::List
    assert_kind_of Dependencies::LoadingModule, @loading_module::List
    assert @loading_module::List.const_load! :ListController
    assert_kind_of Class, @loading_module::List::ListController
  end
end