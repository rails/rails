require File.dirname(__FILE__) + '/abstract_unit'

module ContainerTest
  $immediate_service = Object.new
  $deferred_service = Object.new
  
  class DelegateContainer < ActionController::Base
    web_service_dispatching_mode :delegated
  
    attr :flag
    attr :previous_flag
  
    def initialize
      @previous_flag = nil
      @flag = true
    end
  
    web_service :immediate_service, $immediate_service
    web_service(:deferred_service) { @previous_flag = @flag; @flag = false; $deferred_service }
  end
  
  class DirectContainer < ActionController::Base
    web_service_dispatching_mode :direct
  end

  class InvalidContainer
    include ActionWebService::Container::Direct
  end
end

class TC_Container < Test::Unit::TestCase
  include ContainerTest

  def setup
    @delegate_container = DelegateContainer.new
    @direct_container = DirectContainer.new
  end

  def test_registration
    assert(DelegateContainer.has_web_service?(:immediate_service))
    assert(DelegateContainer.has_web_service?(:deferred_service))
    assert(!DelegateContainer.has_web_service?(:fake_service))
    assert_raises(ActionWebService::Container::Delegated::ContainerError) do
      DelegateContainer.web_service('invalid')
    end
  end

  def test_service_object
    assert_raises(ActionWebService::Container::Delegated::ContainerError) do
      @delegate_container.web_service_object(:nonexistent)
    end
    assert(@delegate_container.flag == true)
    assert(@delegate_container.web_service_object(:immediate_service) == $immediate_service)
    assert(@delegate_container.previous_flag.nil?)
    assert(@delegate_container.flag == true)
    assert(@delegate_container.web_service_object(:deferred_service) == $deferred_service)
    assert(@delegate_container.previous_flag == true)
    assert(@delegate_container.flag == false)
  end

  def test_direct_container
    assert(DirectContainer.web_service_dispatching_mode == :direct)
  end

  def test_validity
    assert_raises(ActionWebService::Container::Direct::ContainerError) do 
      InvalidContainer.web_service_api :test
    end
    assert_raises(ActionWebService::Container::Direct::ContainerError) do 
      InvalidContainer.web_service_api 50.0
    end
  end
end
