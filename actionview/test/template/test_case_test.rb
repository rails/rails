# frozen_string_literal: true

require "abstract_unit"
require "rails/engine"
require "capybara/minitest"

module ActionView
  module ATestHelper
  end

  module AnotherTestHelper
    def from_another_helper
      "Howdy!"
    end
  end

  module ASharedTestHelper
    def from_shared_helper
      "Holla!"
    end
  end

  class TestCase
    helper ASharedTestHelper
    DeveloperStruct = Struct.new(:name)

    module SharedTests
      def setup
        ActionView::LookupContext::DetailsKey.clear
        super
      end

      def self.included(test_case)
        test_case.class_eval do
          test "helpers defined on ActionView::TestCase are available" do
            assert_includes test_case.ancestors, ASharedTestHelper
            assert_equal "Holla!", from_shared_helper
          end
        end
      end
    end
  end

  class GeneralViewTest < ActionView::TestCase
    include SharedTests
    test_case = self

    test "memoizes the view" do
      assert_same view, view
    end

    test "exposes params" do
      assert params.is_a? ActionController::Parameters
    end

    test "exposes request" do
      assert request.is_a? ActionDispatch::Request
    end

    test "exposes view as _view for backwards compatibility" do
      assert_same _view, view
    end

    test "returns controller_name" do
      assert_equal "test", controller_name
    end

    test "retrieve non existing config values" do
      assert_nil ActionView::Base.empty.config.something_odd
    end

    test "works without testing a helper module" do
      assert_equal "Eloy", render("developers/developer", developer: DeveloperStruct.new("Eloy"))
    end

    test "can render a layout with block" do
      assert_equal "Before (ChrisCruft)\n!\nAfter",
                    render(layout: "test/layout_for_partial", locals: { name: "ChrisCruft" }) { "!" }
    end

    helper AnotherTestHelper
    test "additional helper classes can be specified as in a controller" do
      assert_includes test_case.ancestors, AnotherTestHelper
      assert_equal "Howdy!", from_another_helper
    end

    test "determine_default_helper_class returns nil if the test name constant resolves to a class" do
      assert_nil self.class.determine_default_helper_class("String")
    end

    test "delegates notice to request.flash[:notice]" do
      assert_called_with(view.request.flash, :[], [:notice]) do
        view.notice
      end
    end

    test "delegates alert to request.flash[:alert]" do
      assert_called_with(view.request.flash, :[], [:alert]) do
        view.alert
      end
    end

    test "uses controller lookup context" do
      assert_equal lookup_context, @controller.lookup_context
    end
  end

  class ClassMethodsTest < ActionView::TestCase
    include SharedTests
    test_case = self

    tests ATestHelper
    test "tests the specified helper module" do
      assert_equal ATestHelper, test_case.helper_class
      assert_includes test_case.ancestors, ATestHelper
    end

    helper AnotherTestHelper
    test "additional helper classes can be specified as in a controller" do
      assert_includes test_case.ancestors, AnotherTestHelper
      assert_equal "Howdy!", from_another_helper

      test_case.helper_class.module_eval do
        def render_from_helper
          from_another_helper
        end
      end
      assert_equal "Howdy!", render(partial: "test/from_helper")
    end
  end

  class HelperInclusionTest < ActionView::TestCase
    def teardown
      ActionController::Base.view_paths.map(&:clear_cache)
    end

    module RenderHelper
      def render_from_helper
        render partial: "customer", collection: @customers
      end
    end

    helper RenderHelper

    test "helper class that is being tested is always included in view instance" do
      @controller.controller_path = "test"

      @customers = [DeveloperStruct.new("Eloy"), DeveloperStruct.new("Manfred")]
      assert_match(/Hello: EloyHello: Manfred/, render(partial: "test/from_helper"))
    end
  end

  class ControllerHelperMethod < ActionView::TestCase
    module SomeHelper
      def some_method
        render partial: "test/from_helper"
      end
    end

    helper SomeHelper

    test "can call a helper method defined on the current controller from a helper" do
      @controller.singleton_class.class_eval <<-EOF, __FILE__, __LINE__ + 1
        def render_from_helper
          'controller_helper_method'
        end
      EOF
      @controller.class.helper_method :render_from_helper

      assert_equal "controller_helper_method", some_method
    end

    class AnotherTestClass < ActionView::TestCase
      test "doesn't use controller helpers from other tests" do
        assert_not_respond_to view, :render_from_helper
        assert_not_includes @controller._helpers.instance_methods, :render_from_helper
      end
    end
  end

  class ViewAssignsTest < ActionView::TestCase
    test "view_assigns returns a Hash of user defined ivars" do
      @a = "b"
      @c = "d"
      assert_equal({ a: "b", c: "d" }, view_assigns)
    end

    test "view_assigns excludes internal ivars" do
      INTERNAL_IVARS.each do |ivar|
        assert defined?(ivar), "expected #{ivar} to be defined"
        assert_not_includes view_assigns.keys, ivar.to_s.tr("@", "").to_sym, "expected #{ivar} to be excluded from view_assigns"
      end
    end
  end

  class HelperExposureTest < ActionView::TestCase
    helper(Module.new do
      def render_from_helper
        from_test_case(suffix: "!")
      end
    end)
    test "is able to make methods available to the view" do
      assert_equal "Word!", render(partial: "test/from_helper")
    end

    def from_test_case(suffix: "?"); "Word#{suffix}"; end
    helper_method :from_test_case
  end

  class IgnoreProtectAgainstForgeryTest < ActionView::TestCase
    module HelperThatInvokesProtectAgainstForgery
      def help_me
        protect_against_forgery?
      end
    end

    helper HelperThatInvokesProtectAgainstForgery

    test "protect_from_forgery? in any helpers returns false" do
      assert_not view.help_me
    end
  end

  class ATestHelperTest < ActionView::TestCase
    include SharedTests
    test_case = self

    test "inflects the name of the helper module to test from the test case class" do
      assert_equal ATestHelper, test_case.helper_class
      assert_includes test_case.ancestors, ATestHelper
    end

    test "a configured test controller is available" do
      assert_kind_of ActionController::Base, controller
      assert_equal "", controller.controller_path
    end

    test "no additional helpers should shared across test cases" do
      assert_not_includes test_case.ancestors, AnotherTestHelper
      assert_raise(NoMethodError) { send :from_another_helper }
    end

    test "is able to use routes" do
      controller.request.assign_parameters(@routes, "foo", "index", {}, "/foo", [])
      with_routing do |set|
        set.draw {
          get :foo, to: "foo#index"
          get :bar, to: "bar#index"
        }
        assert_equal "/foo", url_for
        assert_equal "/bar", url_for(controller: "bar")
      end
    end

    test "is able to use named routes" do
      with_routing do |set|
        set.draw { resources :contents }
        assert_equal "http://test.host/contents/new", new_content_url
        assert_equal "http://test.host/contents/1",   content_url(id: 1)
      end
    end

    test "is able to use mounted routes" do
      with_routing do |set|
        app = Class.new(Rails::Engine) do
          def self.routes
            @routes ||= ActionDispatch::Routing::RouteSet.new
          end

          routes.draw { get "bar", to: lambda { } }

          def self.call(*)
          end
        end

        set.draw { mount app => "/foo", :as => "foo_app" }

        singleton_class.include set.mounted_helpers

        assert_equal "/foo/bar", foo_app.bar_path
      end
    end

    test "named routes can be used from helper included in view" do
      with_routing do |set|
        set.draw { resources :contents }
        _helpers.module_eval do
          def render_from_helper
            new_content_url
          end
        end

        assert_equal "http://test.host/contents/new", render(partial: "test/from_helper")
      end
    end

    test "is able to render partials with local variables" do
      assert_equal "Eloy", render("developers/developer", developer: DeveloperStruct.new("Eloy"))
      assert_equal "Eloy", render(partial: "developers/developer",
                                  locals: { developer: DeveloperStruct.new("Eloy") })
    end

    test "is able to render partials from templates and also use instance variables" do
      @controller.controller_path = "test"

      @customers = [DeveloperStruct.new("Eloy"), DeveloperStruct.new("Manfred")]
      assert_match(/Hello: EloyHello: Manfred/, render(template: "test/list"))
    end

    test "is able to render partials from templates and also use instance variables after view has been referenced" do
      @controller.controller_path = "test"

      view

      @customers = [DeveloperStruct.new("Eloy"), DeveloperStruct.new("Manfred")]
      assert_match(/Hello: EloyHello: Manfred/, render(template: "test/list"))
    end

    test "is able to use helpers that depend on the view flow" do
      assert_not content_for?(:foo)

      content_for :foo, "bar"
      assert content_for?(:foo)
      assert_equal "bar", content_for(:foo)
    end
  end

  class AssertionsTest < ActionView::TestCase
    def render_from_helper
      form_tag("/foo") do
        safe_concat render(plain: "<ul><li>foo</li></ul>")
      end
    end
    helper_method :render_from_helper

    test "uses the output_buffer for assert_select" do
      render(partial: "test/from_helper")

      assert_select "form" do
        assert_select "li", text: "foo"
      end
    end

    test "do not memoize the document_root_element in view tests" do
      concat form_tag("/foo")

      assert_select "form"

      concat content_tag(:b, "Strong", class: "foo")

      assert_select "form"
      assert_select "b.foo"
    end
  end

  class PlaceholderAssertionsTest < ActionView::TestCase
    helper_method def render_from_helper
      content_tag "a", "foo", href: "/bar"
    end

    test "supports placeholders in assert_select calls" do
      render(partial: "test/from_helper")

      assert_select "a[href=?]", "/bar", text: "foo"
    end
  end

  class CapybaraHTMLEncoderTest < ActionView::TestCase
    include ::Capybara::Minitest::Assertions

    def page
      Capybara.string(rendered)
    end

    test "document_root_element can be configured to utilize Capybara" do
      developer = DeveloperStruct.new("Eloy")

      render "developers/developer_with_h1", developer: developer

      assert_kind_of Capybara::Node::Simple, page
      assert_css "h1", text: developer.name
    end
  end

  class RenderedViewContentTest < ActionView::TestCase
    test "#rendered inherits from String" do
      developer = DeveloperStruct.new("Eloy")

      render "developers/developer", developer: developer

      assert_kind_of String, rendered
      assert_kind_of String, rendered.to_s
      assert_equal developer.name, rendered
      assert_match(/#{developer.name}/, rendered)
      assert_includes rendered, developer.name
    end

    test "#rendered resets after each render" do
      render "developers/developer", developer: DeveloperStruct.new("first")

      assert_includes rendered, "first"
      assert_not_includes rendered, "second"
      assert_not_includes rendered, "third"

      render "developers/developer", developer: DeveloperStruct.new("second")

      assert_includes rendered, "first"
      assert_includes rendered, "second"
      assert_not_includes rendered, "third"

      render "developers/developer", developer: DeveloperStruct.new("third")

      assert_includes rendered, "first"
      assert_includes rendered, "second"
      assert_includes rendered, "third"
    end
  end

  class HTMLParserTest < ActionView::TestCase
    test "rendered.html is a Nokogiri::XML::DocumentFragment" do
      developer = DeveloperStruct.new("Eloy")

      render "developers/developer", developer: developer

      assert_kind_of Nokogiri::XML::DocumentFragment, rendered.html
      assert_equal rendered.to_s, rendered.html.to_s
      assert_equal developer.name, document_root_element.text
    end

    test "do not memoize the rendered.html in view tests" do
      concat form_tag("/foo")

      assert_equal "/foo", document_root_element.at("form")["action"]

      concat content_tag(:b, "Strong", class: "foo")

      assert_equal "/foo", document_root_element.at("form")["action"]
      assert_equal "foo", document_root_element.at("b")["class"]
    end
  end

  class JSONParserTest < ActionView::TestCase
    test "rendered.json is an ActiveSupport::HashWithIndifferentAccess" do
      developer = DeveloperStruct.new("Eloy")

      render formats: :json, partial: "developers/developer", locals: { developer: developer }

      assert_kind_of ActiveSupport::HashWithIndifferentAccess, rendered.json
      assert_equal rendered.to_s, rendered.json.to_json
      assert_equal developer.name, rendered.json[:name]
    end
  end

  class MissingHTMLParserTest < ActionView::TestCase
    register_parser :html, nil

    test "rendered.html falls back to returning the value when the parser is missing" do
      developer = DeveloperStruct.new("Eloy")

      render "developers/developer", developer: developer

      assert_kind_of String, rendered.html
      assert_equal developer.name, rendered.html
    end
  end

  module AHelperWithInitialize
    def initialize(*)
      super
      @called_initialize = true
    end
  end

  class AHelperWithInitializeTest < ActionView::TestCase
    test "the helper's initialize was actually called" do
      assert @called_initialize
    end
  end

  class PatternMatchingTestCases < ActionView::TestCase
    test "document_root_element integrates with pattern matching" do
      developer = DeveloperStruct.new("Eloy")

      render "developers/developer_with_h1", developer: developer

      assert_pattern { document_root_element.at("h1") => { content: "Eloy", attributes: [{ name: "id", value: "name" }] } }
      refute_pattern { document_root_element.at("h1") => { content: "Not Eloy" } }
    end

    test "rendered.html integrates with pattern matching" do
      developer = DeveloperStruct.new("Eloy")

      render "developers/developer", developer: developer

      assert_pattern { rendered.html => { content: "Eloy" } }
      refute_pattern { rendered.html => { content: "Not Eloy" } }
    end

    test "rendered.json integrates with pattern matching" do
      developer = DeveloperStruct.new("Eloy")

      render formats: :json, partial: "developers/developer", locals: { developer: developer }

      assert_pattern { rendered.json => { name: "Eloy" } }
      refute_pattern { rendered.json => { name: "Not Eloy" } }
    end
  end
end
