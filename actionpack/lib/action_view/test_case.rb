require 'active_support/test_case'

module ActionView
  class Base
    alias_method :initialize_without_template_tracking, :initialize
    def initialize(*args)
      @_rendered = { :template => nil, :partials => Hash.new(0) }
      initialize_without_template_tracking(*args)
    end
  end

  module Renderable
    alias_method :render_without_template_tracking, :render
    def render(view, local_assigns = {})
      if respond_to?(:path) && !is_a?(InlineTemplate)
        rendered = view.instance_variable_get(:@_rendered)
        rendered[:partials][self] += 1 if is_a?(RenderablePartial)
        rendered[:template] ||= self
      end
      render_without_template_tracking(view, local_assigns)
    end
  end

  class TestCase < ActiveSupport::TestCase
    class TestController < ActionController::Base
      attr_accessor :request, :response, :params

      def self.controller_path
        ''
      end

      def initialize
        @request = ActionController::TestRequest.new
        @response = ActionController::TestResponse.new

        @params = {}
        send(:initialize_current_url)
      end
    end

    include ActionController::TestCase::Assertions
    include ActionController::TestProcess

    include ActionController::PolymorphicRoutes
    include ActionController::RecordIdentifier

    include ActionView::Helpers
    include ActionController::Helpers

    class_inheritable_accessor :helper_class
    attr_accessor :controller, :output_buffer, :rendered

    setup :setup_with_controller
    def setup_with_controller
      @controller = TestController.new
      @output_buffer = ''
      @rendered = ''

      self.class.send(:include_helper_modules!)
      make_test_case_available_to_view!
    end

    def render(options = {}, local_assigns = {}, &block)
      @rendered << output = _view.render(options, local_assigns, &block)
      output
    end

    def protect_against_forgery?
      false
    end

    class << self
      def tests(helper_class)
        self.helper_class = helper_class
      end

      def helper_class
        if current_helper_class = read_inheritable_attribute(:helper_class)
          current_helper_class
        else
          self.helper_class = determine_default_helper_class(name)
        end
      end

      def determine_default_helper_class(name)
        name.sub(/Test$/, '').constantize
      rescue NameError
        nil
      end

      def helper_method(*methods)
        # Almost a duplicate from ActionController::Helpers
        methods.flatten.each do |method|
          master_helper_module.module_eval <<-end_eval
            def #{method}(*args, &block)                    # def current_user(*args, &block)
              _test_case.send(%(#{method}), *args, &block)  #   test_case.send(%(current_user), *args, &block)
            end                                             # end
          end_eval
        end
      end

      private
        def include_helper_modules!
          helper(helper_class) if helper_class
          include master_helper_module
        end
    end

    private
      def make_test_case_available_to_view!
        test_case_instance = self
        master_helper_module.module_eval do
          define_method(:_test_case) { test_case_instance }
          private :_test_case
        end
      end

      def _view
        view = ActionView::Base.new(ActionController::Base.view_paths, _assigns, @controller)
        view.helpers.include master_helper_module
        view.output_buffer = self.output_buffer
        view
      end

      # Support the selector assertions
      #
      # Need to experiment if this priority is the best one: rendered => output_buffer
      def response_from_page_or_rjs
        HTML::Document.new(rendered.blank? ? output_buffer : rendered).root
      end

      EXCLUDE_IVARS = %w{
        @output_buffer
        @fixture_cache
        @method_name
        @_result
        @loaded_fixtures
        @test_passed
        @view
      }

      def _instance_variables
        instance_variables - EXCLUDE_IVARS
      end

      def _assigns
        _instance_variables.inject({}) do |hash, var|
          name = var[1..-1].to_sym
          hash[name] = instance_variable_get(var)
          hash
        end
      end

      def method_missing(selector, *args)
        if ActionController::Routing::Routes.named_routes.helpers.include?(selector)
          @controller.__send__(selector, *args)
        else
          super
        end
      end
  end
end