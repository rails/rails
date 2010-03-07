require 'action_controller/test_case'
require 'action_view'

module ActionView
  class Base
    alias_method :initialize_without_template_tracking, :initialize
    def initialize(*args)
      @_rendered = { :template => nil, :partials => Hash.new(0) }
      initialize_without_template_tracking(*args)
    end

    attr_internal :rendered
  end

  class Template
    alias_method :render_without_tracking, :render
    def render(view, locals, &blk)
      rendered = view.rendered
      rendered[:partials][self] += 1 if partial?
      rendered[:template] ||= []
      rendered[:template] << self
      render_without_tracking(view, locals, &blk)
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

        @request.env.delete('PATH_INFO')

        @params = {}
      end
    end

    include ActionDispatch::Assertions, ActionDispatch::TestProcess
    include ActionView::Context

    include ActionController::PolymorphicRoutes
    include ActionController::RecordIdentifier

    include ActionView::Helpers
    include ActionController::Helpers

    class_inheritable_accessor :helper_class
    attr_accessor :controller, :output_buffer, :rendered

    setup :setup_with_controller
    def setup_with_controller
      @controller = TestController.new
      @output_buffer = ActiveSupport::SafeBuffer.new
      @rendered = ''

      self.class.send(:include_helper_modules!)
      make_test_case_available_to_view!
    end

    def config
      @controller.config
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
          _helpers.module_eval <<-end_eval
            def #{method}(*args, &block)                    # def current_user(*args, &block)
              _test_case.send(%(#{method}), *args, &block)  #   test_case.send(%(current_user), *args, &block)
            end                                             # end
          end_eval
        end
      end

      private
        def include_helper_modules!
          helper(helper_class) if helper_class
          include _helpers
        end
    end

    private
      def make_test_case_available_to_view!
        test_case_instance = self
        _helpers.module_eval do
          define_method(:_test_case) { test_case_instance }
          private :_test_case
        end
      end

      def _view
        view = ActionView::Base.new(ActionController::Base.view_paths, _assigns, @controller)
        view.class.send :include, _helpers
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
        if @controller._router.named_routes.helpers.include?(selector)
          @controller.__send__(selector, *args)
        else
          super
        end
      end
  end
end
