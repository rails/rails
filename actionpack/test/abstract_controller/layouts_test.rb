require File.join(File.expand_path(File.dirname(__FILE__)), "test_helper")

module AbstractControllerTests
  module Layouts

    # Base controller for these tests
    class Base < AbstractController::Base
      use AbstractController::Renderer
      use AbstractController::Layouts
      
      self.view_paths = [ActionView::FixtureTemplate::FixturePath.new(
        "layouts/hello.erb"                     => "With String <%= yield %>",
        "layouts/hello_override.erb"            => "With Override <%= yield %>",
        "layouts/abstract_controller_tests/layouts/with_string_implied_child.erb" =>
                                                   "With Implied <%= yield %>",
        "layouts/omg.erb"                       => "OMGHI2U <%= yield %>",
        "layouts/with_false_layout.erb"         => "False Layout <%= yield %>"
      )]

      def self.controller_path
        @controller_path ||= self.name.sub(/Controller$/, '').underscore
      end
      
      def controller_path() self.class.controller_path end
      
      def render_to_body(options)
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
    
    class WithStringChild < WithString
    end
    
    class WithStringOverriddenChild < WithString
      layout "hello_override"
    end
    
    class WithNilChild < WithString
      layout nil
    end    
    
    class WithStringImpliedChild < WithString
    end
    
    class WithChildOfImplied < WithStringImpliedChild
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
    
    class WithSymbolReturningNil < Base
      layout :nilz
      
      def index
        render :_template => ActionView::TextTemplate.new("Hello nilz!")
      end
      
      def nilz() end
    end
    
    class WithSymbolReturningObj < Base
      layout :objekt
      
      def index
        render :_template => ActionView::TextTemplate.new("Hello nilz!")
      end
      
      def objekt
        Object.new
      end
    end    
    
    class WithSymbolAndNoMethod < Base
      layout :omg_no_method
      
      def index
        render :_template => ActionView::TextTemplate.new("Hello boom!")
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
    
    class WithNilLayout < Base
      layout nil
      
      def index
        render :_template => ActionView::TextTemplate.new("Hello nil!")
      end
    end
    
    # TODO Move to bootloader
    AbstractController::Base.subclasses.each do |klass|
      klass = klass.constantize
      next unless klass < AbstractController::Layouts
      klass.class_eval do
        _write_layout_method
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
        result = WithNilLayout.process(:index)
        assert_equal "Hello nil!", result.response_obj[:body]
      end
      
      test "when layout is specified as a symbol, call the requested method and use the layout returned" do
        result = WithSymbol.process(:index)
        assert_equal "OMGHI2U Hello symbol!", result.response_obj[:body]
      end
      
      test "when layout is specified as a symbol and the method returns nil, don't use a layout" do
        result = WithSymbolReturningNil.process(:index)
        assert_equal "Hello nilz!", result.response_obj[:body]
      end
      
      test "when the layout is specified as a symbol and the method doesn't exist, raise an exception" do
        assert_raises(NoMethodError, /:nilz/) { WithSymbolAndNoMethod.process(:index) }
      end
      
      test "when the layout is specified as a symbol and the method returns something besides a string/false/nil, raise an exception" do
        assert_raises(ArgumentError) { WithSymbolReturningObj.process(:index) }
      end
      
      test "when a child controller does not have a layout, use the parent controller layout" do
        result = WithStringChild.process(:index)
        assert_equal "With String Hello string!", result.response_obj[:body]
      end
      
      test "when a child controller has specified a layout, use that layout and not the parent controller layout" do
        result = WithStringOverriddenChild.process(:index)
        assert_equal "With Override Hello string!", result.response_obj[:body]
      end
      
      test "when a child controller has an implied layout, use that layout and not the parent controller layout" do
        result = WithStringImpliedChild.process(:index)
        assert_equal "With Implied Hello string!", result.response_obj[:body]
      end
      
      test "when a child controller specifies layout nil, do not use the parent layout" do
        result = WithNilChild.process(:index)
        assert_equal "Hello string!", result.response_obj[:body]
      end
            
      test "when a grandchild has no layout specified, the child has an implied layout, and the " \
        "parent has specified a layout, use the child controller layout" do
          result = WithChildOfImplied.process(:index)
          assert_equal "With Implied Hello string!", result.response_obj[:body]
      end
      
      test "raises an exception when specifying layout true" do
        assert_raises ArgumentError do
          Object.class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
            class ::BadOmgFailLolLayout < AbstractControllerTests::Layouts::Base
              layout true
            end
          RUBY_EVAL
        end
      end
    end
  end
end
