require File.dirname(__FILE__) + '/abstract_unit'

module ContainerTest
 
  $immediate_service = Object.new
  $deferred_service = Object.new
  
  class DelegateContainer < ActionController::Base
    service_dispatching_mode :delegated
  
    attr :flag
    attr :previous_flag
  
    def initialize
      @previous_flag = nil
      @flag = true
    end
  
    service :immediate_service, $immediate_service
    service(:deferred_service) { @previous_flag = @flag; @flag = false; $deferred_service }
  end
  
  class DirectContainer < ActionController::Base
    service_dispatching_mode :direct
   end
end

class TC_Container < Test::Unit::TestCase
  def setup
    @delegate_container = ContainerTest::DelegateContainer.new
    @direct_container = ContainerTest::DirectContainer.new
  end

  def test_registration
    assert(ContainerTest::DelegateContainer.has_service?(:immediate_service))
    assert(ContainerTest::DelegateContainer.has_service?(:deferred_service))
    assert(!ContainerTest::DelegateContainer.has_service?(:fake_service))
  end

  def test_service_object
    assert(@delegate_container.flag == true)
    assert(@delegate_container.service_object(:immediate_service) == $immediate_service)
    assert(@delegate_container.previous_flag.nil?)
    assert(@delegate_container.flag == true)
    assert(@delegate_container.service_object(:deferred_service) == $deferred_service)
    assert(@delegate_container.previous_flag == true)
    assert(@delegate_container.flag == false)
  end

  def test_direct_container
    assert(ContainerTest::DirectContainer.service_dispatching_mode == :direct)
  end
end
