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
    include ActionController::TestCase::Assertions
    include ActionController::TestProcess

    class_inheritable_accessor :helper_class
    @@helper_class = nil

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
    end

    include ActionView::Helpers
    include ActionController::PolymorphicRoutes
    include ActionController::RecordIdentifier

    setup :setup_with_helper_class

    def setup_with_helper_class
      if helper_class && !self.class.ancestors.include?(helper_class)
        self.class.send(:include, helper_class)
      end

      self.output_buffer = ''
    end

    class TestController < ActionController::Base
      attr_accessor :request, :response, :params

      def initialize
        @request = ActionController::TestRequest.new
        @response = ActionController::TestResponse.new
        
        @params = {}
        send(:initialize_current_url)
      end
    end

    protected
      attr_accessor :output_buffer

    private
      def method_missing(selector, *args)
        controller = TestController.new
        return controller.__send__(selector, *args) if ActionController::Routing::Routes.named_routes.helpers.include?(selector)
        super
      end
  end
end
