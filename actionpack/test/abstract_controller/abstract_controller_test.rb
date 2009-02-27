$:.unshift(File.dirname(__FILE__) + '/../../lib')
$:.unshift(File.dirname(__FILE__) + '/../../../activesupport/lib')

require 'test/unit'
require 'active_support'
require 'active_support/test_case'
require 'action_controller'
require 'action_view/base'

begin
  require 'ruby-debug'
  Debugger.settings[:autoeval] = true
  Debugger.start
rescue LoadError
  # Debugging disabled. `gem install ruby-debug` to enable.
end

require 'action_controller/abstract/base'
require 'action_controller/abstract/renderer'
require 'action_controller/abstract/layouts'

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
      
      def action_with_ivars
        @my_ivar = "Hello"
        render "action_with_ivars.erb"
      end
      
      def naked_render
        render
      end
    end
    
    class TestRenderer < ActiveSupport::TestCase
      test "rendering templates works" do
        result = Me2.process(:index)
        assert_equal "Hello from index.erb", result.response_obj[:body]
      end
      
      test "rendering passes ivars to the view" do
        result = Me2.process(:action_with_ivars)
        assert_equal "Hello from index_with_ivars.erb", result.response_obj[:body]
      end
      
      test "rendering with no template name" do
        result = Me2.process(:naked_render)
        assert_equal "Hello from naked_render.erb", result.response_obj[:body]
      end
    end
    
    class PrefixedViews < RenderingController
      private
      def self.prefix
        name.underscore
      end
      
      def _prefix
        self.class.prefix
      end
    end
    
    class Me3 < PrefixedViews
      def index
        render
      end
      
      def formatted
        self.formats = [:html]
        render
      end
    end
    
    class TestPrefixedViews < ActiveSupport::TestCase
      test "templates are located inside their 'prefix' folder" do
        result = Me3.process(:index)
        assert_equal "Hello from me3/index.erb", result.response_obj[:body]
      end

      test "templates included their format" do
        result = Me3.process(:formatted)
        assert_equal "Hello from me3/formatted.html.erb", result.response_obj[:body]
      end
    end
    
    class WithLayouts < PrefixedViews
      include Layouts
      
      private
      def self.layout(formats)
        begin
          view_paths.find_by_parts(name.underscore, formats, "layouts")
        rescue ActionView::MissingTemplate
          begin
            view_paths.find_by_parts("application", formats, "layouts")
          rescue ActionView::MissingTemplate
          end
        end
      end
      
      def _layout
        self.class.layout(formats)
      end
    end
    
    class Me4 < WithLayouts
      def index
        render
      end
    end
    
    class Me5 < WithLayouts
      def index
        render
      end
    end
    
    class TestLayouts < ActiveSupport::TestCase
      test "layouts are included" do
        result = Me4.process(:index)
        assert_equal "Me4 Enter : Hello from me4/index.erb : Exit", result.response_obj[:body]
      end
      
      test "it can fall back to the application layout" do
        result = Me5.process(:index)
        assert_equal "Application Enter : Hello from me5/index.erb : Exit", result.response_obj[:body]        
      end
    end
    
  end
end