require File.dirname(__FILE__) + '/abstract_unit'

module BaseTest
  class API < ActionService::API::Base
    api_method :add, :expects => [:int, :int], :returns => [:int]
    api_method :void
  end

  class PristineAPI < ActionService::API::Base
    inflect_names false

    api_method :add
    api_method :under_score
  end

  class Service < ActionService::Base
    service_api API

    def add(a, b)
    end
  
    def void
    end
  end
  
  class PristineService < ActionService::Base
    service_api PristineAPI

    def add
    end

    def under_score
    end
  end
end

class TC_Base < Test::Unit::TestCase
  def test_options
    assert(BaseTest::PristineService.service_api.inflect_names == false)
    assert(BaseTest::Service.service_api.inflect_names == true)
  end
end
