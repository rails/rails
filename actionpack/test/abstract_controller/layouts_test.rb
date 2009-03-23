require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module AbstractControllerTests
  module Layouts

    # Base controller for these tests
    class Base < AbstractController::Base
      include AbstractController::Renderer
      include AbstractController::Layouts
      
      self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(
        "layouts/hello.html.erb" => "With String <%= yield %>"
      )]
      
      def render_to_string(options)
        options[:_layout] = _default_layout
        super
      end
    end
    
    class Blank < Base
      self.view_paths = []
      
      def index
        render :_template => ActionView::TextTemplate.new("Hello blank!")
      end
    end
    
    class WithString < Base
      layout "hello"
      
      def index
        render :_template => ActionView::TextTemplate.new("Hello string!")
      end
    end
    
    class WithMissingLayout < Base
      layout "missing"
      
      def index
        render :_template => ActionView::TextTemplate.new("Hello missing!")
      end
    end
      
    
    class TestBase < ActiveSupport::TestCase
      test "when no layout is specified, and no default is available, render without a layout" do
        result = Blank.process(:index)
        assert_equal "Hello blank!", result.response_obj[:body]
      end
      
      test "when layout is specified as a string, render with that layout" do
        result = Blank.process(:index)
        assert_equal "With String Hello string!", result.response_obj[:body]
      end
      
      test "when layout is specified as a string, but the layout is missing, raise an exception" do
        assert_raises(ActionView::MissingTemplate) { WithMissingLayout.process(:index) }
      end
    end


  end
end