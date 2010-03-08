require "abstract_controller/base"
require "active_support/core_ext/array/wrap"

module AbstractController
  class DoubleRenderError < Error
    DEFAULT_MESSAGE = "Render and/or redirect were called multiple times in this action. Please note that you may only call render OR redirect, and at most once per action. Also note that neither redirect nor render terminate execution of the action, so if you want to exit an action after redirecting, you need to do something like \"redirect_to(...) and return\"."

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  module ViewPaths
    extend ActiveSupport::Concern

    included do
      class_attribute :_view_paths
      self._view_paths = ActionView::PathSet.new
    end

    delegate :find_template, :template_exists?,
             :view_paths, :formats, :formats=, :to => :lookup_context

    # LookupContext is the object responsible to hold all information required to lookup
    # templates, i.e. view paths and details. Check ActionView::LookupContext for more
    # information.
    def lookup_context
      @lookup_context ||= ActionView::LookupContext.new(self.class._view_paths, details_for_lookup)
    end

    def details_for_lookup
      { }
    end

    def append_view_path(path)
      lookup_context.view_paths.push(*path)
    end

    def prepend_view_path(path)
      lookup_context.view_paths.unshift(*path)
    end

    module ClassMethods
      # Append a path to the list of view paths for this controller.
      #
      # ==== Parameters
      # path<String, ViewPath>:: If a String is provided, it gets converted into
      # the default view path. You may also provide a custom view path
      # (see ActionView::ViewPathSet for more information)
      def append_view_path(path)
        self.view_paths = view_paths.dup + Array(path)
      end

      # Prepend a path to the list of view paths for this controller.
      #
      # ==== Parameters
      # path<String, ViewPath>:: If a String is provided, it gets converted into
      # the default view path. You may also provide a custom view path
      # (see ActionView::ViewPathSet for more information)
      def prepend_view_path(path)
        self.view_paths = Array(path) + view_paths.dup
      end

      # A list of all of the default view paths for this controller.
      def view_paths
        _view_paths
      end

      # Set the view paths.
      #
      # ==== Parameters
      # paths<ViewPathSet, Object>:: If a ViewPathSet is provided, use that;
      #   otherwise, process the parameter into a ViewPathSet.
      def view_paths=(paths)
        self._view_paths = paths.is_a?(ActionView::PathSet) ? paths : ActionView::Base.process_view_paths(paths)
        self._view_paths.freeze
      end
    end
  end

  module Rendering
    extend ActiveSupport::Concern
    include AbstractController::ViewPaths

    # An instance of a view class. The default view class is ActionView::Base
    #
    # The view class must have the following methods:
    # View.for_controller[controller]
    #   Create a new ActionView instance for a controller
    # View#render_template[options]
    #   Returns String with the rendered template
    #
    # Override this method in a module to change the default behavior.
    def view_context
      @_view_context ||= ActionView::Base.for_controller(self)
    end

    # Mostly abstracts the fact that calling render twice is a DoubleRenderError.
    # Delegates render_to_body and sticks the result in self.response_body.
    def render(*args, &block)
      options = _normalize_args(*args, &block)
      _normalize_options(options)
      self.response_body = render_to_body(options)
    end

    # Raw rendering of a template to a Rack-compatible body.
    # :api: plugin
    def render_to_body(options = {})
      _process_options(options)
      _render_template(options)
    end

    # Raw rendering of a template to a string. Just convert the results of
    # render_to_body into a String.
    # :api: plugin
    def render_to_string(options={})
      _normalize_options(options)
      AbstractController::Rendering.body_to_s(render_to_body(options))
    end

    # Find and renders a template based on the options given.
    def _render_template(options)
      view_context.render_template(options) { |template| _with_template_hook(template) }
    end

    # The prefix used in render "foo" shortcuts.
    def _prefix
      controller_path
    end

    # Return a string representation of a Rack-compatible response body.
    def self.body_to_s(body)
      if body.respond_to?(:to_str)
        body
      else
        strings = []
        body.each { |part| strings << part.to_s }
        body.close if body.respond_to?(:close)
        strings.join
      end
    end

  private

    # Normalize options by converting render "foo" to render :action => "foo" and
    # render "foo/bar" to render :file => "foo/bar".
    def _normalize_args(action=nil, options={})
      case action
      when NilClass
      when Hash
        options, action = action, nil
      when String, Symbol
        action = action.to_s
        key = action.include?(?/) ? :file : :action
        options[key] = action
      else
        options.merge!(:partial => action)
      end

      options
    end

    def _normalize_options(options)
      if options[:partial] == true
        options[:partial] = action_name
      end

      if (options.keys & [:partial, :file, :template]).empty?
        options[:_prefix] ||= _prefix 
      end

      options[:template] ||= (options[:action] || action_name).to_s

      details = _normalize_details(options)
      lookup_context.update_details(details)
      options
    end

    def _normalize_details(options)
      details = {}
      details[:formats] = Array(options[:format]) if options[:format]
      details[:locale]  = Array(options[:locale]) if options[:locale]
      details
    end

    def _process_options(options)
    end

    def _with_template_hook(template)
      self.formats = template.details[:formats]
    end
  end
end
