require 'abstract_unit'
require 'controller/fake_controllers'

module ActionView

  module ATestHelper
  end

  module AnotherTestHelper
    def from_another_helper
      'Howdy!'
    end
  end

  module ASharedTestHelper
    def from_shared_helper
      'Holla!'
    end
  end

  class TestCase
    helper ASharedTestHelper

    module SharedTests
      def self.included(test_case)
        test_case.class_eval do
          test "helpers defined on ActionView::TestCase are available" do
            assert test_case.ancestors.include?(ASharedTestHelper)
            assert_equal 'Holla!', from_shared_helper
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

    test "exposes view as _view for backwards compatibility" do
      assert_same _view, view
    end

    test "retrieve non existing config values" do
      assert_equal nil, ActionView::Base.new.config.something_odd
    end

    test "works without testing a helper module" do
      assert_equal 'Eloy', render('developers/developer', :developer => stub(:name => 'Eloy'))
    end

    test "can render a layout with block" do
      assert_equal "Before (ChrisCruft)\n!\nAfter",
                    render(:layout => "test/layout_for_partial", :locals => {:name => "ChrisCruft"}) {"!"}
    end

    helper AnotherTestHelper
    test "additional helper classes can be specified as in a controller" do
      assert test_case.ancestors.include?(AnotherTestHelper)
      assert_equal 'Howdy!', from_another_helper
    end

    test "determine_default_helper_class returns nil if the test name constant resolves to a class" do
      assert_nil self.class.determine_default_helper_class("String")
    end

    test "delegates notice to request.flash[:notice]" do
      view.request.flash.expects(:[]).with(:notice)
      view.notice
    end

    test "delegates alert to request.flash[:alert]" do
      view.request.flash.expects(:[]).with(:alert)
      view.alert
    end

    test "uses controller lookup context" do
      assert_equal self.lookup_context, @controller.lookup_context
    end
  end

  class ClassMethodsTest < ActionView::TestCase
    include SharedTests
    test_case = self

    tests ATestHelper
    test "tests the specified helper module" do
      assert_equal ATestHelper, test_case.helper_class
      assert test_case.ancestors.include?(ATestHelper)
    end

    helper AnotherTestHelper
    test "additional helper classes can be specified as in a controller" do
      assert test_case.ancestors.include?(AnotherTestHelper)
      assert_equal 'Howdy!', from_another_helper

      test_case.helper_class.module_eval do
        def render_from_helper
          from_another_helper
        end
      end
      assert_equal 'Howdy!', render(:partial => 'test/from_helper')
    end
  end

  class HelperInclusionTest < ActionView::TestCase
    module RenderHelper
      def render_from_helper
        render :partial => 'customer', :collection => @customers
      end
    end

    helper RenderHelper

    test "helper class that is being tested is always included in view instance" do
      @controller.controller_path = 'test'

      @customers = [stub(:name => 'Eloy'), stub(:name => 'Manfred')]
      assert_match(/Hello: EloyHello: Manfred/, render(:partial => 'test/from_helper'))
    end
  end

  class ControllerHelperMethod < ActionView::TestCase
    module SomeHelper
      def some_method
        render :partial => 'test/from_helper'
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

      assert_equal 'controller_helper_method', some_method
    end
  end

  class ViewAssignsTest < ActionView::TestCase
    test "view_assigns returns a Hash of user defined ivars" do
      @a = 'b'
      @c = 'd'
      assert_equal({:a => 'b', :c => 'd'}, view_assigns)
    end

    test "view_assigns excludes internal ivars" do
      INTERNAL_IVARS.each do |ivar|
        assert defined?(ivar), "expected #{ivar} to be defined"
        assert !view_assigns.keys.include?(ivar.to_s.sub('@', '').to_sym), "expected #{ivar} to be excluded from view_assigns"
      end
    end
  end

  class HelperExposureTest < ActionView::TestCase
    helper(Module.new do
      def render_from_helper
        from_test_case
      end
    end)
    test "is able to make methods available to the view" do
      assert_equal 'Word!', render(:partial => 'test/from_helper')
    end

    def from_test_case; 'Word!'; end
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
      assert !view.help_me
    end

  end

  class ATestHelperTest < ActionView::TestCase
    include SharedTests
    test_case = self

    test "inflects the name of the helper module to test from the test case class" do
      assert_equal ATestHelper, test_case.helper_class
      assert test_case.ancestors.include?(ATestHelper)
    end

    test "a configured test controller is available" do
      assert_kind_of ActionController::Base, controller
      assert_equal '', controller.controller_path
    end

    test "no additional helpers should shared across test cases" do
      assert !test_case.ancestors.include?(AnotherTestHelper)
      assert_raise(NoMethodError) { send :from_another_helper }
    end

    test "is able to use routes" do
      controller.request.assign_parameters(@routes, 'foo', 'index')
      assert_equal '/foo', url_for
      assert_equal '/bar', url_for(:controller => 'bar')
    end

    test "is able to use named routes" do
      with_routing do |set|
        set.draw { resources :contents }
        assert_equal 'http://test.host/contents/new', new_content_url
        assert_equal 'http://test.host/contents/1',   content_url(:id => 1)
      end
    end

    test "is able to use mounted routes" do
      with_routing do |set|
        app = Class.new do
          def self.routes
            @routes ||= ActionDispatch::Routing::RouteSet.new
          end

          routes.draw { get "bar", :to => lambda {} }

          def self.call(*)
          end
        end

        set.draw { mount app => "/foo", :as => "foo_app" }

        assert_equal '/foo/bar', foo_app.bar_path
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

        assert_equal 'http://test.host/contents/new', render(:partial => 'test/from_helper')
      end
    end

    test "is able to render partials with local variables" do
      assert_equal 'Eloy', render('developers/developer', :developer => stub(:name => 'Eloy'))
      assert_equal 'Eloy', render(:partial => 'developers/developer',
                                  :locals => { :developer => stub(:name => 'Eloy') })
    end

    test "is able to render partials from templates and also use instance variables" do
      @controller.controller_path = "test"

      @customers = [stub(:name => 'Eloy'), stub(:name => 'Manfred')]
      assert_match(/Hello: EloyHello: Manfred/, render(:file => 'test/list'))
    end

    test "is able to render partials from templates and also use instance variables after view has been referenced" do
      @controller.controller_path = "test"

      view

      @customers = [stub(:name => 'Eloy'), stub(:name => 'Manfred')]
      assert_match(/Hello: EloyHello: Manfred/, render(:file => 'test/list'))
    end

  end

  class AssertionsTest < ActionView::TestCase
    def render_from_helper
      form_tag('/foo') do
        safe_concat render(:text => '<ul><li>foo</li></ul>')
      end
    end
    helper_method :render_from_helper

    test "uses the output_buffer for assert_select" do
      render(:partial => 'test/from_helper')

      assert_select 'form' do
        assert_select 'li', :text => 'foo'
      end
    end
  end

  class RenderTemplateTest < ActionView::TestCase
    test "supports specifying templates with a Regexp" do
      controller.controller_path = "fun"
      render(:template => "fun/games/hello_world")
      assert_template %r{\Afun/games/hello_world\Z}
    end

    test "supports specifying partials" do
      controller.controller_path = "test"
      render(:template => "test/calling_partial_with_layout")
      assert_template :partial => "_partial_for_use_in_layout"
    end

    test "supports specifying locals (passing)" do
      controller.controller_path = "test"
      render(:template => "test/calling_partial_with_layout")
      assert_template :partial => "_partial_for_use_in_layout", :locals => { :name => "David" }
    end

    test "supports specifying locals (failing)" do
      controller.controller_path = "test"
      render(:template => "test/calling_partial_with_layout")
      assert_raise ActiveSupport::TestCase::Assertion, /Somebody else.*David/m do
        assert_template :partial => "_partial_for_use_in_layout", :locals => { :name => "Somebody Else" }
      end
    end

    test 'supports different locals on the same partial' do
      controller.controller_path = "test"
      render(:template => "test/render_two_partials")
      assert_template partial: '_partial', locals: { 'first' => '1' }
      assert_template partial: '_partial', locals: { 'second' => '2' }
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
end
