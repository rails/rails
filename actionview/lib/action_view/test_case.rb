# frozen_string_literal: true

require "active_support/core_ext/module/redefine_method"
require "action_controller"
require "action_controller/test_case"
require "action_view"

require "rails-dom-testing"

module ActionView
  # = Action View Test Case
  #
  # Read more about <tt>ActionView::TestCase</tt> in {Testing Rails Applications}[https://guides.rubyonrails.org/testing.html#testing-view-partials]
  # in the guides.
  class TestCase < ActiveSupport::TestCase
    class TestController < ActionController::Base
      include ActionDispatch::TestProcess

      attr_accessor :request, :response, :params

      class << self
        # Overrides AbstractController::Base#controller_path
        attr_accessor :controller_path
      end

      def controller_path=(path)
        self.class.controller_path = path
      end

      def self.controller_name
        "test"
      end

      def initialize
        super
        self.class.controller_path = ""
        @request = ActionController::TestRequest.create(self.class)
        @response = ActionDispatch::TestResponse.new

        @request.env.delete("PATH_INFO")
        @params = ActionController::Parameters.new
      end
    end

    module Behavior
      extend ActiveSupport::Concern

      include ActionDispatch::Assertions, ActionDispatch::TestProcess
      include Rails::Dom::Testing::Assertions
      include ActionController::TemplateAssertions
      include ActionView::Context

      include ActionDispatch::Routing::PolymorphicRoutes

      include AbstractController::Helpers
      include ActionView::Helpers
      include ActionView::RecordIdentifier
      include ActionView::RoutingUrlFor

      include ActiveSupport::Testing::ConstantLookup

      delegate :lookup_context, to: :controller
      attr_accessor :controller, :request, :output_buffer, :rendered

      module ClassMethods
        def inherited(descendant) # :nodoc:
          super

          descendant_content_class = content_class.dup

          if descendant_content_class.respond_to?(:set_temporary_name)
            descendant_content_class.set_temporary_name("rendered_content")
          end

          descendant.content_class = descendant_content_class
        end

        # Register a callable to parse rendered content for a given template
        # format.
        #
        # Each registered parser will also define a +#rendered.[FORMAT]+ helper
        # method, where +[FORMAT]+ corresponds to the value of the
        # +format+ argument.
        #
        # By default, ActionView::TestCase defines parsers for:
        #
        # * +:html+ - returns an instance of +Nokogiri::XML::Node+
        # * +:json+ - returns an instance of ActiveSupport::HashWithIndifferentAccess
        #
        # These pre-registered parsers also define corresponding helpers:
        #
        # * +:html+ - defines +rendered.html+
        # * +:json+ - defines +rendered.json+
        #
        # ==== Parameters
        #
        # [+format+]
        #   The name (as a +Symbol+) of the format used to render the content.
        #
        # [+callable+]
        #   The parser. A callable object that accepts the rendered string as
        #   its sole argument. Alternatively, the parser can be specified as a
        #   block.
        #
        # ==== Examples
        #
        #   test "renders HTML" do
        #     article = Article.create!(title: "Hello, world")
        #
        #     render partial: "articles/article", locals: { article: article }
        #
        #     assert_pattern { rendered.html.at("main h1") => { content: "Hello, world" } }
        #   end
        #
        #   test "renders JSON" do
        #     article = Article.create!(title: "Hello, world")
        #
        #     render formats: :json, partial: "articles/article", locals: { article: article }
        #
        #     assert_pattern { rendered.json => { title: "Hello, world" } }
        #   end
        #
        # To parse the rendered content into RSS, register a call to +RSS::Parser.parse+:
        #
        #   register_parser :rss, -> rendered { RSS::Parser.parse(rendered) }
        #
        #   test "renders RSS" do
        #     article = Article.create!(title: "Hello, world")
        #
        #     render formats: :rss, partial: article
        #
        #     assert_equal "Hello, world", rendered.rss.items.last.title
        #   end
        #
        # To parse the rendered content into a +Capybara::Simple::Node+,
        # re-register an +:html+ parser with a call to +Capybara.string+:
        #
        #   register_parser :html, -> rendered { Capybara.string(rendered) }
        #
        #   test "renders HTML" do
        #     article = Article.create!(title: "Hello, world")
        #
        #     render partial: article
        #
        #     rendered.html.assert_css "h1", text: "Hello, world"
        #   end
        #
        def register_parser(format, callable = nil, &block)
          parser = callable || block || :itself.to_proc
          content_class.redefine_method(format) do
            parser.call(to_s)
          end
        end

        def tests(helper_class)
          case helper_class
          when String, Symbol
            self.helper_class = "#{helper_class.to_s.underscore}_helper".camelize.safe_constantize
          when Module
            self.helper_class = helper_class
          end
        end

        def determine_default_helper_class(name)
          determine_constant_from_test_name(name) do |constant|
            Module === constant && !(Class === constant)
          end
        end

        def helper_method(*methods)
          # Almost a duplicate from ActionController::Helpers
          methods.flatten.each do |method|
            _helpers_for_modification.module_eval <<~end_eval, __FILE__, __LINE__ + 1
              def #{method}(...)                    # def current_user(...)
                _test_case.send(:'#{method}', ...)  #   _test_case.send(:'current_user', ...)
              end                                   # end
            end_eval
          end
        end

        attr_writer :helper_class

        def helper_class
          @helper_class ||= determine_default_helper_class(name)
        end

        def new(*)
          include_helper_modules!
          super
        end

      private
        def include_helper_modules!
          helper(helper_class) if helper_class
          include _helpers
        end
      end

      included do
        class_attribute :content_class, instance_accessor: false, default: RenderedViewContent

        setup :setup_with_controller

        register_parser :html, -> rendered { Rails::Dom::Testing.html_document_fragment.parse(rendered) }
        register_parser :json, -> rendered { JSON.parse(rendered, object_class: ActiveSupport::HashWithIndifferentAccess) }

        ActiveSupport.run_load_hooks(:action_view_test_case, self)

        helper do
          def protect_against_forgery?
            false
          end

          def _test_case
            controller._test_case
          end
        end
      end

      def setup_with_controller
        controller_class = Class.new(ActionView::TestCase::TestController)
        @controller = controller_class.new
        @request = @controller.request
        @view_flow = ActionView::OutputFlow.new
        @output_buffer = ActionView::OutputBuffer.new
        @rendered = self.class.content_class.new(+"")

        test_case_instance = self
        controller_class.define_method(:_test_case) { test_case_instance }
      end

      def config
        @controller.config if @controller.respond_to?(:config)
      end

      def render(options = {}, local_assigns = {}, &block)
        view.assign(view_assigns)
        @rendered << output = view.render(options, local_assigns, &block)
        output
      end

      def rendered_views
        @_rendered_views ||= RenderedViewsCollection.new
      end

      ##
      # :method: rendered
      #
      # Returns the content rendered by the last +render+ call.
      #
      # The returned object behaves like a string but also exposes a number of methods
      # that allows you to parse the content string in formats registered using
      # <tt>.register_parser</tt>.
      #
      # By default includes the following parsers:
      #
      # +.html+
      #
      # Parse the <tt>rendered</tt> content String into HTML. By default, this means
      # a <tt>Nokogiri::XML::Node</tt>.
      #
      #   test "renders HTML" do
      #     article = Article.create!(title: "Hello, world")
      #
      #     render partial: "articles/article", locals: { article: article }
      #
      #     assert_pattern { rendered.html.at("main h1") => { content: "Hello, world" } }
      #   end
      #
      # To parse the rendered content into a <tt>Capybara::Simple::Node</tt>,
      # re-register an <tt>:html</tt> parser with a call to
      # <tt>Capybara.string</tt>:
      #
      #   register_parser :html, -> rendered { Capybara.string(rendered) }
      #
      #   test "renders HTML" do
      #     article = Article.create!(title: "Hello, world")
      #
      #     render partial: article
      #
      #     rendered.html.assert_css "h1", text: "Hello, world"
      #   end
      #
      # +.json+
      #
      # Parse the <tt>rendered</tt> content String into JSON. By default, this means
      # a <tt>ActiveSupport::HashWithIndifferentAccess</tt>.
      #
      #   test "renders JSON" do
      #     article = Article.create!(title: "Hello, world")
      #
      #     render formats: :json, partial: "articles/article", locals: { article: article }
      #
      #     assert_pattern { rendered.json => { title: "Hello, world" } }
      #   end

      def _routes
        @controller._routes if @controller.respond_to?(:_routes)
      end

      class RenderedViewContent < String # :nodoc:
      end

      class RenderedViewsCollection
        def initialize
          @rendered_views ||= Hash.new { |hash, key| hash[key] = [] }
        end

        def add(view, locals)
          @rendered_views[view] ||= []
          @rendered_views[view] << locals
        end

        def locals_for(view)
          @rendered_views[view]
        end

        def rendered_views
          @rendered_views.keys
        end

        def view_rendered?(view, expected_locals)
          locals_for(view).any? do |actual_locals|
            expected_locals.all? { |key, value| value == actual_locals[key] }
          end
        end
      end

    private
      # Need to experiment if this priority is the best one: rendered => output_buffer
      def document_root_element
        Rails::Dom::Testing.html_document.parse(@rendered.blank? ? @output_buffer.to_str : @rendered).root
      end

      module Locals
        attr_accessor :rendered_views

        def render(options = {}, local_assigns = {})
          case options
          when Hash
            if block_given?
              rendered_views.add options[:layout], options[:locals]
            elsif options.key?(:partial)
              rendered_views.add options[:partial], options[:locals]
            end
          else
            rendered_views.add options, local_assigns
          end

          super
        end
      end

      # The instance of ActionView::Base that is used by +render+.
      def view
        @view ||= begin
          view = @controller.view_context
          view.singleton_class.include(_helpers)
          view.extend(Locals)
          view.rendered_views = rendered_views
          view.output_buffer = output_buffer
          view
        end
      end

      alias_method :_view, :view

      INTERNAL_IVARS = [
        :@NAME,
        :@failures,
        :@assertions,
        :@__io__,
        :@_assertion_wrapped,
        :@_assertions,
        :@_result,
        :@_routes,
        :@controller,
        :@_controller,
        :@_request,
        :@_config,
        :@_default_form_builder,
        :@_layouts,
        :@_files,
        :@_rendered_views,
        :@method_name,
        :@output_buffer,
        :@_partials,
        :@passed,
        :@rendered,
        :@request,
        :@routes,
        :@tagged_logger,
        :@_templates,
        :@options,
        :@test_passed,
        :@view,
        :@view_context_class,
        :@view_flow,
        :@_subscribers,
        :@html_document,
      ]

      def _user_defined_ivars
        instance_variables - INTERNAL_IVARS
      end

      # Returns a Hash of instance variables and their values, as defined by
      # the user in the test case, which are then assigned to the view being
      # rendered. This is generally intended for internal use and extension
      # frameworks.
      def view_assigns
        Hash[_user_defined_ivars.map do |ivar|
          [ivar[1..-1].to_sym, instance_variable_get(ivar)]
        end]
      end

      def method_missing(selector, ...)
        begin
          routes = @controller.respond_to?(:_routes) && @controller._routes
        rescue
          # Don't call routes, if there is an error on _routes call
        end

        if routes &&
           (routes.named_routes.route_defined?(selector) ||
             routes.mounted_helpers.method_defined?(selector))
          @controller.__send__(selector, ...)
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        begin
          routes = @controller.respond_to?(:_routes) && @controller._routes
        rescue
          # Don't call routes, if there is an error on _routes call
        end

        routes &&
          (routes.named_routes.route_defined?(name) ||
           routes.mounted_helpers.method_defined?(name))
      end
    end

    include Behavior
  end
end
