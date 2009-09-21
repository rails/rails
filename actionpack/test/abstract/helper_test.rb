require 'abstract_unit'

module AbstractController
  module Testing
  
    class ControllerWithHelpers < AbstractController::Base
      include AbstractController::RenderingController
      include Helpers
      
      def render(string)
        super(:_template_name => string)
      end
      
      append_view_path File.expand_path(File.join(File.dirname(__FILE__), "views"))
    end
   
    module HelperyTest
      def included_method
        "Included"
      end
    end
   
    class MyHelpers1 < ControllerWithHelpers
      helper(HelperyTest) do
        def helpery_test
          "World"
        end
      end
      
      def index
        render "helper_test.erb"
      end
    end
    
    class TestHelpers < ActiveSupport::TestCase
      def test_helpers
        controller = MyHelpers1.new
        controller.process(:index)
        assert_equal "Hello World : Included", controller.response_body
      end
    end
    
  end
end
