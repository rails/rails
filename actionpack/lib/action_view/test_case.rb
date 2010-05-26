require 'active_support/core_ext/object/blank'
require 'action_controller'
require 'action_controller/test_case'
require 'action_view'

module ActionView
  class TestCase < ActiveSupport::TestCase
    class TestController < ActionController::Base
      include ActionDispatch::TestProcess

      attr_accessor :request, :response, :params

      class << self
        attr_writer :controller_path
      end

      def controller_path=(path)
        self.class.controller_path=(path)
      end

      def initialize
        self.class.controller_path = ""
        @request = ActionController::TestRequest.new
        @response = ActionController::TestResponse.new

        @request.env.delete('PATH_INFO')

        @params = {}
      end
    end

    module Behavior
      extend ActiveSupport::Concern

      include ActionDispatch::Assertions, ActionDispatch::TestProcess
      include ActionController::TemplateAssertions
      include ActionView::Context

      include ActionController::PolymorphicRoutes
      include ActionController::RecordIdentifier

      include AbstractController::Helpers
      include ActionView::Helpers

      attr_accessor :controller, :output_buffer, :rendered
      
      module ClassMethods
        def tests(helper_class)
          self.helper_class = helper_class
        end

        def determine_default_helper_class(name)
          mod = name.sub(/Test$/, '').constantize
          mod.is_a?(Class) ? nil : mod
        rescue NameError
          nil
        end

        def helper_method(*methods)
          # Almost a duplicate from ActionController::Helpers
          methods.flatten.each do |method|
            _helpers.module_eval <<-end_eval
              def #{method}(*args, &block)                    # def current_user(*args, &block)
                _test_case.send(%(#{method}), *args, &block)  #   test_case.send(%(current_user), *args, &block)
              end                                             # end
            end_eval
          end
        end

        attr_writer :helper_class

        def helper_class
          @helper_class ||= determine_default_helper_class(name)
        end

      private

        def include_helper_modules!
          helper(helper_class) if helper_class
          include _helpers
        end

      end

      def setup_with_controller
        @controller = ActionView::TestCase::TestController.new
        @output_buffer = ActiveSupport::SafeBuffer.new
        @rendered = ''

        self.class.send(:include_helper_modules!)
        make_test_case_available_to_view!
        say_no_to_protect_against_forgery!
      end

      def config
        @controller.config if @controller.respond_to?(:config)
      end

      def render(options = {}, local_assigns = {}, &block)
        @rendered << output = _view.render(options, local_assigns, &block)
        output
      end

      included do
        setup :setup_with_controller
      end

    private

      # Support the selector assertions
      #
      # Need to experiment if this priority is the best one: rendered => output_buffer
      def response_from_page_or_rjs
        HTML::Document.new(@rendered.blank? ? @output_buffer : @rendered).root
      end

      def say_no_to_protect_against_forgery!
        _helpers.module_eval do
          def protect_against_forgery?
            false
          end
        end
      end

      def make_test_case_available_to_view!
        test_case_instance = self
        _helpers.module_eval do
          define_method(:_test_case) { test_case_instance }
          private :_test_case
        end
      end

      def _view
        view = ActionView::Base.new(ActionController::Base.view_paths, _assigns, @controller)
        view.singleton_class.send :include, _helpers
        view.singleton_class.send :include, @controller._router.url_helpers
        view.singleton_class.send :delegate, :alert, :notice, :to => "request.flash"
        view.output_buffer = self.output_buffer
        view
      end

      EXCLUDE_IVARS = %w{
        @_result
        @output_buffer
        @rendered
        @templates
        @view_context_class
        @layouts
        @partials
        @controller

        @method_name
        @fixture_cache
        @loaded_fixtures
        @test_passed
      }

      def _instance_variables
        instance_variables - EXCLUDE_IVARS
        instance_variables
      end

      def _assigns
        _instance_variables.inject({}) do |hash, var|
          name = var[1..-1].to_sym
          hash[name] = instance_variable_get(var)
          hash
        end
      end

      def _router
        @controller._router if @controller.respond_to?(:_router)
      end

      def method_missing(selector, *args)
        if @controller.respond_to?(:_router) &&
        @controller._router.named_routes.helpers.include?(selector)
          @controller.__send__(selector, *args)
        else
          super
        end
      end

    end

    include Behavior

  end
end
