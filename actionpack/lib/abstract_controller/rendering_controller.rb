require "abstract_controller/logger"

module AbstractController
  module RenderingController
    extend ActiveSupport::Concern

    include AbstractController::Logger

    included do
      attr_internal :formats

      extlib_inheritable_accessor :_view_paths

      self._view_paths ||= ActionView::PathSet.new
    end

    # An instance of a view class. The default view class is ActionView::Base
    #
    # The view class must have the following methods:
    # View.for_controller[controller] Create a new ActionView instance for a 
    #   controller
    # View#render_partial[options]
    #   - responsible for setting options[:_template]
    #   - Returns String with the rendered partial
    #   options<Hash>:: see _render_partial in ActionView::Base
    # View#render_template[template, layout, options, partial]
    #   - Returns String with the rendered template
    #   template<ActionView::Template>:: The template to render
    #   layout<ActionView::Template>:: The layout to render around the template
    #   options<Hash>:: See _render_template_with_layout in ActionView::Base
    #   partial<Boolean>:: Whether or not the template to render is a partial
    #
    # Override this method in a to change the default behavior.
    def view_context
      @_view_context ||= ActionView::Base.for_controller(self)
    end

    # Mostly abstracts the fact that calling render twice is a DoubleRenderError.
    # Delegates render_to_body and sticks the result in self.response_body.
    def render(*args)
      if response_body
        raise AbstractController::DoubleRenderError, "OMG"
      end

      self.response_body = render_to_body(*args)
    end

    # Raw rendering of a template to a Rack-compatible body.
    #
    # ==== Options
    # _partial_object<Object>:: The object that is being rendered. If this
    #   exists, we are in the special case of rendering an object as a partial.
    #
    # :api: plugin
    def render_to_body(options = {})
      # TODO: Refactor so we can just use the normal template logic for this
      if options.key?(:partial)
        view_context.render_partial(options)
      else
        _determine_template(options)
        _render_template(options)
      end
    end

    # Raw rendering of a template to a string. Just convert the results of
    # render_to_body into a String.
    #
    # :api: plugin
    def render_to_string(options = {})
      AbstractController::RenderingController.body_to_s(render_to_body(options))
    end

    # Renders the template from an object.
    #
    # ==== Options
    # _template<ActionView::Template>:: The template to render
    # _layout<ActionView::Template>:: The layout to wrap the template in (optional)
    # _partial<TrueClass, FalseClass>:: Whether or not the template to be rendered is a partial
    def _render_template(options)
      view_context.render_template(options)
    end

    # The list of view paths for this controller. See ActionView::ViewPathSet for
    # more details about writing custom view paths.
    def view_paths
      _view_paths
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
    # Take in a set of options and determine the template to render
    #
    # ==== Options
    # _template<ActionView::Template>:: If this is provided, the search is over
    # _template_name<#to_s>:: The name of the template to look up. Otherwise,
    #   use the current action name.
    # _prefix<String>:: The prefix to look inside of. In a file system, this corresponds
    #   to a directory.
    # _partial<TrueClass, FalseClass>:: Whether or not the file to look up is a partial
    def _determine_template(options)
      name = (options[:_template_name] || action_name).to_s

      options[:_template] ||= view_paths.find(
        name, { :formats => formats }, options[:_prefix], options[:_partial]
      )
    end

    module ClassMethods
      # Append a path to the list of view paths for this controller.
      #
      # ==== Parameters
      # path<String, ViewPath>:: If a String is provided, it gets converted into 
      # the default view path. You may also provide a custom view path 
      # (see ActionView::ViewPathSet for more information)
      def append_view_path(path)
        self.view_paths << path
      end

      # Prepend a path to the list of view paths for this controller.
      #
      # ==== Parameters
      # path<String, ViewPath>:: If a String is provided, it gets converted into 
      # the default view path. You may also provide a custom view path 
      # (see ActionView::ViewPathSet for more information)
      def prepend_view_path(path)
        self.view_paths.unshift(path)
      end

      # A list of all of the default view paths for this controller.
      def view_paths
        self._view_paths
      end

      # Set the view paths.
      #
      # ==== Parameters
      # paths<ViewPathSet, Object>:: If a ViewPathSet is provided, use that;
      #   otherwise, process the parameter into a ViewPathSet.
      def view_paths=(paths)
        self._view_paths = paths.is_a?(ActionView::PathSet) ?
                            paths : ActionView::Base.process_view_paths(paths)
      end
    end
  end
end
