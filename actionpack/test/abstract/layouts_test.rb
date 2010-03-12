require 'abstract_unit'

module AbstractControllerTests
  module Layouts

    # Base controller for these tests
    class Base < AbstractController::Base
      include AbstractController::Rendering
      include AbstractController::Layouts

      def _prefix
        "template"
      end

      self.view_paths = [ActionView::FixtureResolver.new(
        "abstract_controller_tests/layouts/with_string_implied_child.erb" =>
                                           "With Implied <%= yield %>",
        "layouts/hello.erb"             => "With String <%= yield %>",
        "layouts/hello_override.erb"    => "With Override <%= yield %>",
        "layouts/overwrite.erb"         => "Overwrite <%= yield %>",
        "layouts/with_false_layout.erb" => "False Layout <%= yield %>"
      )]
    end
    
    class Blank < Base
      self.view_paths = ActionView::FixtureResolver.new("template/index.erb" => "Hello blank!")

      def index
        render 
      end
    end
    
    class WithString < Base
      layout "hello"

      append_view_path ActionView::FixtureResolver.new(
        "template/index.erb"             => "Hello string!",
        "template/overwrite_default.erb" => "Hello string!",
        "template/overwrite_false.erb"   => "Hello string!",
        "template/overwrite_string.erb"  => "Hello string!"
      )

      def index
        render
      end

      def overwrite_default
        render :layout => :default
      end

      def overwrite_false
        render :layout => false
      end

      def overwrite_string
        render :layout => "overwrite"
      end

      def overwrite_skip
        render :text => "Hello text!"
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

    class WithProc < Base
      layout proc { |c| "overwrite" }

      append_view_path ActionView::FixtureResolver.new(
        "template/index.erb" => "Hello proc!"
      )

      def index
        render
      end
    end

    class WithSymbol < Base
      layout :hello

      append_view_path ActionView::FixtureResolver.new(
        "template/index.erb" => "Hello symbol!"
      )

      def index
        render
      end

    private

      def hello
        "overwrite"
      end
    end
    
    class WithSymbolReturningString < Base
      layout :no_hello

      append_view_path ActionView::FixtureResolver.new(
        "template/index.erb" => "Hello missing symbol!"
      )

      def index
        render
      end

    private

      def no_hello
        nil
      end
    end
    
    class WithSymbolReturningNil < Base
      layout :nilz

      append_view_path ActionView::FixtureResolver.new(
        "template/index.erb" => "Hello nilz!"
      )

      def index
        render
      end
      
      def nilz
      end
    end
    
    class WithSymbolReturningObj < Base
      layout :objekt

      append_view_path ActionView::FixtureResolver.new(
        "template/index.erb" => "Hello object!"
      )

      def index
        render
      end
      
      def objekt
        Object.new
      end
    end    
    
    class WithSymbolAndNoMethod < Base
      layout :no_method

      append_view_path ActionView::FixtureResolver.new(
        "template/index.erb" => "Hello boom!"
      )

      def index
        render
      end
    end
    
    class WithMissingLayout < Base
      layout "missing"

      append_view_path ActionView::FixtureResolver.new(
        "template/index.erb" => "Hello missing!"
      )

      def index
        render
      end
    end
    
    class WithFalseLayout < Base
      layout false

      append_view_path ActionView::FixtureResolver.new(
        "template/index.erb" => "Hello false!"
      )

      def index
        render
      end
    end
    
    class WithNilLayout < Base
      layout nil

      append_view_path ActionView::FixtureResolver.new(
        "template/index.erb" => "Hello nil!"
      )
      
      def index
        render
      end
    end
    
    class TestBase < ActiveSupport::TestCase
      test "when no layout is specified, and no default is available, render without a layout" do
        controller = Blank.new
        controller.process(:index)
        assert_equal "Hello blank!", controller.response_body
      end
      
      test "when layout is specified as a string, render with that layout" do
        controller = WithString.new
        controller.process(:index)
        assert_equal "With String Hello string!", controller.response_body
      end

      test "when layout is overwriten by :default in render, render default layout" do
        controller = WithString.new
        controller.process(:overwrite_default)
        assert_equal "With String Hello string!", controller.response_body
      end

      test "when layout is overwriten by string in render, render new layout" do
        controller = WithString.new
        controller.process(:overwrite_string)
        assert_equal "Overwrite Hello string!", controller.response_body
      end

      test "when layout is overwriten by false in render, render no layout" do
        controller = WithString.new
        controller.process(:overwrite_false)
        assert_equal "Hello string!", controller.response_body
      end

      test "when text is rendered, render no layout" do
        controller = WithString.new
        controller.process(:overwrite_skip)
        assert_equal "Hello text!", controller.response_body
      end

      test "when layout is specified as a string, but the layout is missing, raise an exception" do
        assert_raises(ActionView::MissingTemplate) { WithMissingLayout.new.process(:index) }
      end
      
      test "when layout is specified as false, do not use a layout" do
        controller = WithFalseLayout.new
        controller.process(:index)
        assert_equal "Hello false!", controller.response_body
      end
      
      test "when layout is specified as nil, do not use a layout" do
        controller = WithNilLayout.new
        controller.process(:index)
        assert_equal "Hello nil!", controller.response_body
      end

      test "when layout is specified as a proc, call it and use the layout returned" do
        controller = WithProc.new
        controller.process(:index)
        assert_equal "Overwrite Hello proc!", controller.response_body
      end
      
      test "when layout is specified as a symbol, call the requested method and use the layout returned" do
        controller = WithSymbol.new
        controller.process(:index)
        assert_equal "Overwrite Hello symbol!", controller.response_body
      end
      
      test "when layout is specified as a symbol and the method returns nil, don't use a layout" do
        controller = WithSymbolReturningNil.new
        controller.process(:index)
        assert_equal "Hello nilz!", controller.response_body
      end
      
      test "when the layout is specified as a symbol and the method doesn't exist, raise an exception" do
        assert_raises(NoMethodError) { WithSymbolAndNoMethod.new.process(:index) }
      end
      
      test "when the layout is specified as a symbol and the method returns something besides a string/false/nil, raise an exception" do
        assert_raises(ArgumentError) { WithSymbolReturningObj.new.process(:index) }
      end
      
      test "when a child controller does not have a layout, use the parent controller layout" do
        controller = WithStringChild.new
        controller.process(:index)
        assert_equal "With String Hello string!", controller.response_body
      end
      
      test "when a child controller has specified a layout, use that layout and not the parent controller layout" do
        controller = WithStringOverriddenChild.new
        controller.process(:index)
        assert_equal "With Override Hello string!", controller.response_body
      end
      
      test "when a child controller has an implied layout, use that layout and not the parent controller layout" do
        controller = WithStringImpliedChild.new
        controller.process(:index)
        assert_equal "With Implied Hello string!", controller.response_body
      end
      
      test "when a child controller specifies layout nil, do not use the parent layout" do
        controller = WithNilChild.new
        controller.process(:index)
        assert_equal "Hello string!", controller.response_body
      end
            
      test "when a grandchild has no layout specified, the child has an implied layout, and the " \
        "parent has specified a layout, use the child controller layout" do
          controller = WithChildOfImplied.new
          controller.process(:index)
          assert_equal "With Implied Hello string!", controller.response_body
      end
      
      test "raises an exception when specifying layout true" do
        assert_raises ArgumentError do
          Object.class_eval do
            class ::BadFailLayout < AbstractControllerTests::Layouts::Base
              layout true
            end
          end
        end
      end
    end
  end
end
