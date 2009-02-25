$:.unshift(File.dirname(__FILE__) + '/../../lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')

require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'action_controller'

begin
  require 'ruby-debug'
  Debugger.settings[:autoeval] = true
  Debugger.start
rescue LoadError
  # Debugging disabled. `gem install ruby-debug` to enable.
end

require 'action_controller/abstract/base'
require 'action_controller/abstract/renderer'

module AbstractController
  module Testing
  
    class SimpleController < AbstractController::Base
    end
    
    class Me < SimpleController
      def index
        self.response_body = "Hello world"
        "Something else"
      end
    end
    
    class TestBasic < ActiveSupport::TestCase
      test "dispatching works" do
        result = Me.process(:index)
        assert_equal "Hello world", result.response_obj[:body]
      end
    end
    
    class RenderingController < AbstractController::Base
      include Renderer
            
      append_view_path File.expand_path(File.join(File.dirname(__FILE__), "views"))
    end
    
    class Me2 < RenderingController
      def index
        render "index.erb"
      end
    end
    
    class TestRenderer < ActiveSupport::TestCase
      test "rendering templates works" do
        result = Me2.process(:index)
        assert_equal "Hello from index.erb", result.response_obj[:body]
      end
    end
    
  end
end