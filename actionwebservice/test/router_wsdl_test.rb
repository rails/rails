require File.dirname(__FILE__) + '/abstract_unit'
require 'wsdl/parser'

module RouterWsdlTest
  class Person < ActionService::Struct
    member :id, Integer
    member :names, [String]
    member :lastname, String
    member :deleted, TrueClass
  end

  class API < ActionService::API::Base
    api_method :add, :expects => [{:a=>:int}, {:b=>:int}], :returns => [:int]
    api_method :find_people, :returns => [[Person]]
    api_method :nil_returner
  end
  
  class Service < ActionService::Base
    web_service_api API

    def add(a, b)
      a + b
    end
  
    def find_people
      []
    end
  
    def nil_returner
    end
  end

  class AbstractController < ActionController::Base
    def generate_wsdl(container, uri, soap_action_base)
      to_wsdl(container, uri, soap_action_base)
    end
  end

  class DirectController < AbstractController
    web_service_api API

    def add
    end

    def find_people
    end

    def nil_returner
    end
  end
  
  class DelegatedController < AbstractController
    web_service_dispatching_mode :delegated
    web_service(:test_service) { Service.new }
  end
end

class TC_RouterWsdl < Test::Unit::TestCase
  include RouterWsdlTest

  def test_wsdl_generation
    ensure_valid_generation DelegatedController.new
    ensure_valid_generation DirectController.new
  end

  def 

  def test_wsdl_action
    ensure_valid_wsdl_action DelegatedController.new
    ensure_valid_wsdl_action DirectController.new
  end

  protected
    def ensure_valid_generation(controller)
      wsdl = controller.generate_wsdl(controller, 'http://localhost:3000/test/', '/test')
      ensure_valid_wsdl(wsdl)
    end

    def ensure_valid_wsdl(wsdl)
      definitions = WSDL::Parser.new.parse(wsdl)
      assert(definitions.is_a?(WSDL::Definitions))
      definitions.bindings.each do |binding|
        assert(binding.name.name.index(':').nil?)
      end
      definitions.services.each do |service|
        service.ports.each do |port|
          assert(port.name.name.index(':').nil?)
        end
      end
    end

    def ensure_valid_wsdl_action(controller)
      test_request = ActionController::TestRequest.new({ 'action' => 'wsdl' })
      test_request.env['REQUEST_METHOD'] = 'GET'
      test_request.env['HTTP_HOST'] = 'localhost:3000'
      test_response = ActionController::TestResponse.new
      wsdl = controller.process(test_request, test_response).body
      ensure_valid_wsdl(wsdl)
    end
end
