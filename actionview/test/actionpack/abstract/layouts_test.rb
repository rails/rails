require "abstract_unit"

module AbstractControllerTests
  module Layouts

    # Base controller for these tests
    class Base < AbstractController::Base
      include AbstractController::Rendering
      include ActionView::Rendering
      include ActionView::Layouts

      abstract!

      self.view_paths = [ActionView::FixtureResolver.new(
        "some/template.erb"             => "hello <%= foo %> bar",
        "layouts/hello.erb"             => "With String <%= yield %>",
        "layouts/hello_locals.erb"      => "With String <%= yield %>",
        "layouts/hello_override.erb"    => "With Override <%= yield %>",
        "layouts/overwrite.erb"         => "Overwrite <%= yield %>",
        "layouts/with_false_layout.erb" => "False Layout <%= yield %>",
        "abstract_controller_tests/layouts/with_string_implied_child.erb" =>
                                           "With Implied <%= yield %>",
        "abstract_controller_tests/layouts/with_grand_child_of_implied.erb" =>
                                           "With Grand Child <%= yield %>"

      )]
    end

    class Blank < Base
      self.view_paths = []

      def index
        render template: ActionView::Template::Text.new("Hello blank!")
      end
    end

    class WithStringLocals < Base
      layout "hello_locals"

      def index
        render template: "some/template", locals: { foo: "less than 3" }
      end
    end

    class WithString < Base
      layout "hello"

      def index
        render template: ActionView::Template::Text.new("Hello string!")
      end

      def action_has_layout_false
        render template: ActionView::Template::Text.new("Hello string!")
      end

      def overwrite_default
        render template: ActionView::Template::Text.new("Hello string!"), layout: :default
      end

      def overwrite_false
        render template: ActionView::Template::Text.new("Hello string!"), layout: false
      end

      def overwrite_string
        render template: ActionView::Template::Text.new("Hello string!"), layout: "overwrite"
      end

      def overwrite_skip
        render plain: "Hello text!"
      end
    end

    class WithStringChild < WithString
    end

    class WithStringOverriddenChild < WithString
      layout "hello_override"
    end

    class WithStringImpliedChild < WithString
      layout nil
    end

    class WithChildOfImplied < WithStringImpliedChild
    end

    class WithGrandChildOfImplied < WithStringImpliedChild
      layout nil
    end

    class WithProc < Base
      layout proc { "overwrite" }

      def index
        render template: ActionView::Template::Text.new("Hello proc!")
      end
    end

    class WithProcReturningNil < WithString
      layout proc { nil }

      def index
        render template: ActionView::Template::Text.new("Hello nil!")
      end
    end

    class WithProcReturningFalse < WithString
      layout proc { false }

      def index
        render template: ActionView::Template::Text.new("Hello false!")
      end
    end

    class WithZeroArityProc < Base
      layout proc { "overwrite" }

      def index
        render template: ActionView::Template::Text.new("Hello zero arity proc!")
      end
    end

    class WithProcInContextOfInstance < Base
      def an_instance_method; end

      layout proc {
        break unless respond_to? :an_instance_method
        "overwrite"
      }

      def index
        render template: ActionView::Template::Text.new("Hello again zero arity proc!")
      end
    end

    class WithSymbol < Base
      layout :hello

      def index
        render template: ActionView::Template::Text.new("Hello symbol!")
      end
    private
      def hello
        "overwrite"
      end
    end

    class WithSymbolReturningNil < Base
      layout :nilz

      def index
        render template: ActionView::Template::Text.new("Hello nilz!")
      end

      def nilz() end
    end

    class WithSymbolReturningObj < Base
      layout :objekt

      def index
        render template: ActionView::Template::Text.new("Hello nilz!")
      end

      def objekt
        Object.new
      end
    end

    class WithSymbolAndNoMethod < Base
      layout :no_method

      def index
        render template: ActionView::Template::Text.new("Hello boom!")
      end
    end

    class WithMissingLayout < Base
      layout "missing"

      def index
        render template: ActionView::Template::Text.new("Hello missing!")
      end
    end

    class WithFalseLayout < Base
      layout false

      def index
        render template: ActionView::Template::Text.new("Hello false!")
      end
    end

    class WithNilLayout < Base
      layout nil

      def index
        render template: ActionView::Template::Text.new("Hello nil!")
      end
    end

    class WithOnlyConditional < WithStringImpliedChild
      layout "overwrite", only: :show

      def index
        render template: ActionView::Template::Text.new("Hello index!")
      end

      def show
        render template: ActionView::Template::Text.new("Hello show!")
      end
    end

    class WithOnlyConditionalFlipped < WithOnlyConditional
      layout "hello_override", only: :index
    end

    class WithOnlyConditionalFlippedAndInheriting < WithOnlyConditional
      layout nil, only: :index
    end

    class WithExceptConditional < WithStringImpliedChild
      layout "overwrite", except: :show

      def index
        render template: ActionView::Template::Text.new("Hello index!")
      end

      def show
        render template: ActionView::Template::Text.new("Hello show!")
      end
    end

    class AbstractWithString < Base
      layout "hello"
      abstract!
    end

    class AbstractWithStringChild < AbstractWithString
      def index
        render template: ActionView::Template::Text.new("Hello abstract child!")
      end
    end

    class AbstractWithStringChildDefaultsToInherited < AbstractWithString
      layout nil

      def index
        render template: ActionView::Template::Text.new("Hello abstract child!")
      end
    end

    class WithConditionalOverride < WithString
      layout "overwrite", only: :overwritten

      def non_overwritten
        render template: ActionView::Template::Text.new("Hello non overwritten!")
      end

      def overwritten
        render template: ActionView::Template::Text.new("Hello overwritten!")
      end
    end

    class WithConditionalOverrideFlipped < WithConditionalOverride
      layout "hello_override", only: :non_overwritten
    end

    class WithConditionalOverrideFlippedAndInheriting < WithConditionalOverride
      layout nil, only: :non_overwritten
    end

    class TestBase < ActiveSupport::TestCase
      test "when no layout is specified, and no default is available, render without a layout" do
        controller = Blank.new
        controller.process(:index)
        assert_equal "Hello blank!", controller.response_body
      end

      test "with locals" do
        controller = WithStringLocals.new
        controller.process(:index)
        assert_equal "With String hello less than 3 bar", controller.response_body
      end

      test "cache should not grow when locals change for a string template" do
        cache = WithString.view_paths.paths.first.instance_variable_get(:@cache)

        controller = WithString.new
        controller.process(:index) # heat the cache

        size = cache.size

        10.times do |x|
          controller = WithString.new
          controller.define_singleton_method :index do
            render template: ActionView::Template::Text.new("Hello string!"), locals: { :"x#{x}" => :omg }
          end
          controller.process(:index)
        end

        assert_equal size, cache.size
      end

      test "when layout is specified as a string, render with that layout" do
        controller = WithString.new
        controller.process(:index)
        assert_equal "With String Hello string!", controller.response_body
      end

      test "when layout is overwritten by :default in render, render default layout" do
        controller = WithString.new
        controller.process(:overwrite_default)
        assert_equal "With String Hello string!", controller.response_body
      end

      test "when layout is overwritten by string in render, render new layout" do
        controller = WithString.new
        controller.process(:overwrite_string)
        assert_equal "Overwrite Hello string!", controller.response_body
      end

      test "when layout is overwritten by false in render, render no layout" do
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

      test "when layout is specified as a proc, do not leak any methods into controller's action_methods" do
        assert_equal Set.new(["index"]), WithProc.action_methods
      end

      test "when layout is specified as a proc, call it and use the layout returned" do
        controller = WithProc.new
        controller.process(:index)
        assert_equal "Overwrite Hello proc!", controller.response_body
      end

      test "when layout is specified as a proc and the proc returns nil, use inherited layout" do
        controller = WithProcReturningNil.new
        controller.process(:index)
        assert_equal "With String Hello nil!", controller.response_body
      end

      test "when layout is specified as a proc and the proc returns false, use no layout instead of inherited layout" do
        controller = WithProcReturningFalse.new
        controller.process(:index)
        assert_equal "Hello false!", controller.response_body
      end

      test "when layout is specified as a proc without parameters it works just the same" do
        controller = WithZeroArityProc.new
        controller.process(:index)
        assert_equal "Overwrite Hello zero arity proc!", controller.response_body
      end

      test "when layout is specified as a proc without parameters the block is evaluated in the context of an instance" do
        controller = WithProcInContextOfInstance.new
        controller.process(:index)
        assert_equal "Overwrite Hello again zero arity proc!", controller.response_body
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
        assert_raises(NameError) { WithSymbolAndNoMethod.new.process(:index) }
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

      test "when a grandchild has no layout specified, the child has an implied layout, and the " \
        "parent has specified a layout, use the child controller layout" do
          controller = WithChildOfImplied.new
          controller.process(:index)
          assert_equal "With Implied Hello string!", controller.response_body
      end

      test "when a grandchild has nil layout specified, the child has an implied layout, and the " \
        "parent has specified a layout, use the grand child controller layout" do
          controller = WithGrandChildOfImplied.new
          controller.process(:index)
          assert_equal "With Grand Child Hello string!", controller.response_body
      end

      test "a child inherits layout from abstract controller" do
        controller = AbstractWithStringChild.new
        controller.process(:index)
        assert_equal "With String Hello abstract child!", controller.response_body
      end

      test "a child inherits layout from abstract controller2" do
        controller = AbstractWithStringChildDefaultsToInherited.new
        controller.process(:index)
        assert_equal "With String Hello abstract child!", controller.response_body
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

      test "when specify an :only option which match current action name" do
        controller = WithOnlyConditional.new
        controller.process(:show)
        assert_equal "Overwrite Hello show!", controller.response_body
      end

      test "when specify an :only option which does not match current action name" do
        controller = WithOnlyConditional.new
        controller.process(:index)
        assert_equal "With Implied Hello index!", controller.response_body
      end

      test "when specify an :only option which match current action name and is opposite from parent controller" do
        controller = WithOnlyConditionalFlipped.new
        controller.process(:show)
        assert_equal "With Implied Hello show!", controller.response_body
      end

      test "when specify an :only option which does not match current action name and is opposite from parent controller" do
        controller = WithOnlyConditionalFlipped.new
        controller.process(:index)
        assert_equal "With Override Hello index!", controller.response_body
      end

      test "when specify to inherit and an :only option which match current action name and is opposite from parent controller" do
        controller = WithOnlyConditionalFlippedAndInheriting.new
        controller.process(:show)
        assert_equal "With Implied Hello show!", controller.response_body
      end

      test "when specify to inherit and an :only option which does not match current action name and is opposite from parent controller" do
        controller = WithOnlyConditionalFlippedAndInheriting.new
        controller.process(:index)
        assert_equal "Overwrite Hello index!", controller.response_body
      end

      test "when specify an :except option which match current action name" do
        controller = WithExceptConditional.new
        controller.process(:show)
        assert_equal "With Implied Hello show!", controller.response_body
      end

      test "when specify an :except option which does not match current action name" do
        controller = WithExceptConditional.new
        controller.process(:index)
        assert_equal "Overwrite Hello index!", controller.response_body
      end

      test "when specify overwrite as an :only option which match current action name" do
        controller = WithConditionalOverride.new
        controller.process(:overwritten)
        assert_equal "Overwrite Hello overwritten!", controller.response_body
      end

      test "when specify overwrite as an :only option which does not match current action name" do
        controller = WithConditionalOverride.new
        controller.process(:non_overwritten)
        assert_equal "Hello non overwritten!", controller.response_body
      end

      test "when specify overwrite as an :only option which match current action name and is opposite from parent controller" do
        controller = WithConditionalOverrideFlipped.new
        controller.process(:overwritten)
        assert_equal "Hello overwritten!", controller.response_body
      end

      test "when specify overwrite as an :only option which does not match current action name and is opposite from parent controller" do
        controller = WithConditionalOverrideFlipped.new
        controller.process(:non_overwritten)
        assert_equal "With Override Hello non overwritten!", controller.response_body
      end

      test "when specify to inherit and overwrite as an :only option which match current action name and is opposite from parent controller" do
        controller = WithConditionalOverrideFlippedAndInheriting.new
        controller.process(:overwritten)
        assert_equal "Hello overwritten!", controller.response_body
      end

      test "when specify to inherit and overwrite as an :only option which does not match current action name and is opposite from parent controller" do
        controller = WithConditionalOverrideFlippedAndInheriting.new
        controller.process(:non_overwritten)
        assert_equal "Overwrite Hello non overwritten!", controller.response_body
      end

      test "layout for anonymous controller" do
        klass = Class.new(WithString) do
          def index
            render plain: "index", layout: true
          end
        end

        controller = klass.new
        controller.process(:index)
        assert_equal "With String index", controller.response_body
      end

      test "when layout is disabled with #action_has_layout? returning false, render no layout" do
        controller = WithString.new
        controller.instance_eval do
          def action_has_layout?
            false
          end
        end
        controller.process(:action_has_layout_false)
        assert_equal "Hello string!", controller.response_body
      end
    end
  end
end
