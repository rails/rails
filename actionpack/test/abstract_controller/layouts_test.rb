require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module AbstractControllerTests
  module Layouts

    # Base controller for these tests
    class Base < AbstractController::Base
      use AbstractController::Renderer
      use AbstractController::Layouts
      
      self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(
        "layouts/hello.erb"              => "With String <%= yield %>",
        "layouts/omg.erb"                => "OMGHI2U <%= yield %>",
        "layouts/with_false_layout.erb"  => "False Layout <%= yield %>"
      )]

      def self.controller_path
        @controller_path ||= self.name.sub(/Controller$/, '').underscore
      end
      
      def controller_path() self.class.controller_path end
      
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
    
    class WithSymbol < Base
      layout :hello
      
      def index
        render :_template => ActionView::TextTemplate.new("Hello symbol!")
      end
    private  
      def hello
        "omg"
      end
    end
    
    class WithSymbolReturningString < Base
      layout :no_hello
      
      def index
        render :_template => ActionView::TextTemplate.new("Hello missing symbol!")
      end
    private  
      def no_hello
        nil
      end
    end
    
    class WithMissingLayout < Base
      layout "missing"
      
      def index
        render :_template => ActionView::TextTemplate.new("Hello missing!")
      end
    end
    
    class WithFalseLayout < Base
      layout false
      
      def index
        render :_template => ActionView::TextTemplate.new("Hello false!")
      end
    end
    
    class TestBase < ActiveSupport::TestCase
      test "when no layout is specified, and no default is available, render without a layout" do
        result = Blank.process(:index)
        assert_equal "Hello blank!", result.response_obj[:body]
      end
      
      test "when layout is specified as a string, render with that layout" do
        result = WithString.process(:index)
        assert_equal "With String Hello string!", result.response_obj[:body]
      end
      
      test "when layout is specified as a string, but the layout is missing, raise an exception" do
        assert_raises(ActionView::MissingTemplate) { WithMissingLayout.process(:index) }
      end
      
      test "when layout is specified as false, do not use a layout" do
        result = WithFalseLayout.process(:index)
        assert_equal "Hello false!", result.response_obj[:body]
      end
      
      test "when layout is specified as nil, do not use a layout" do
        pending
      end
      
      test "when layout is specified as a symbol, call the requested method and use the layout returned" do
        result = WithSymbol.process(:index)
        assert_equal "OMGHI2U Hello symbol!", result.response_obj[:body]
      end
      
      test "when layout is specified as a symbol and the method returns nil, don't use a layout" do
        pending
      end
      
      test "when the layout is specified as a symbol and the method doesn't exist, raise an exception" do
        pending
      end
      
      test "when the layout is specified as a symbol and the method returns something besides a string/false/nil, raise an exception" do
        pending
      end
      
      test "when a child controller does not have a layout, use the parent controller layout" do
        pending
      end
      
      test "when a child controller has specified a layout, use that layout and not the parent controller layout" do
        pending
      end
      
      test "when a child controller has an implied layout, use that layout and not the parent controller layout" do
        pending
      end
      
      test "when a child controller specifies layout nil, do not use the parent layout" do
        pending
      end
      
      test "when a child controller has an implied layout, use that layout instead of the parent controller layout" do
        pending
      end
      
      test %(
        when a grandchild has no layout specified, the child has an implied layout, and the
        parent has specified a layout, use the child controller layout
      ) do
        pending
      end
      
      test "Raise ArgumentError if layout is called with a bad argument" do
        pending
      end
    end
  end
end