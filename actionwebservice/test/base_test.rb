require File.dirname(__FILE__) + '/abstract_unit'

module BaseTest
  class API < ActionWebService::API::Base
    api_method :add, :expects => [:int, :int], :returns => [:int]
    api_method :void
  end

  class PristineAPI < ActionWebService::API::Base
    inflect_names false

    api_method :add
    api_method :under_score
  end

  class Service < ActionWebService::Base
    web_service_api API

    def add(a, b)
    end
  
    def void
    end
  end
  
  class PristineService < ActionWebService::Base
    web_service_api PristineAPI

    def add
    end

    def under_score
    end
  end
end

class TC_Base < Test::Unit::TestCase
  def test_options
    assert(BaseTest::PristineService.web_service_api.inflect_names == false)
    assert(BaseTest::Service.web_service_api.inflect_names == true)
  end
end
