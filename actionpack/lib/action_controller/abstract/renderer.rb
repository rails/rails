require "action_controller/abstract/logger"

module AbstractController
  module Renderer
    extend ActiveSupport::DependencyModule

    depends_on AbstractController::Logger

    included do
      attr_internal :formats

      extlib_inheritable_accessor :_view_paths

      self._view_paths ||= ActionView::PathSet.new
    end

    def _action_view
      @_action_view ||= ActionView::Base.new(self.class.view_paths, {}, self)      
    end
        
    def render(*args)
      if response_body
        raise AbstractController::DoubleRenderError, "OMG"
      end
      
      self.response_body = render_to_body(*args)
    end
    
    # Raw rendering of a template to a Rack-compatible body.
    # ====
    # @option _prefix<String> The template's path prefix
    # @option _layout<String> The relative path to the layout template to use
    # 
    # :api: plugin
    def render_to_body(options = {})
      # TODO: Refactor so we can just use the normal template logic for this
      if options[:_partial_object]
        _action_view._render_partial_from_controller(options)
      else
        _determine_template(options)
        _render_template(options)
      end
    end

    # Raw rendering of a template to a string.
    # ====
    # @option _prefix<String> The template's path prefix
    # @option _layout<String> The relative path to the layout template to use
    # 
    # :api: plugin
    def render_to_string(options = {})
      AbstractController::Renderer.body_to_s(render_to_body(options))
    end

    def _render_template(options)
      _action_view._render_template_from_controller(options[:_template], options[:_layout], options, options[:_partial])
    end
    
    def view_paths() _view_paths end

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

    def _determine_template(options)
      name = (options[:_template_name] || action_name).to_s

      options[:_template] ||= view_paths.find_by_parts(
        name, { :formats => formats }, options[:_prefix], options[:_partial]
      )
    end

    module ClassMethods
      
      def append_view_path(path)
        self.view_paths << path
      end
      
      def view_paths
        self._view_paths
      end
      
      def view_paths=(paths)
        self._view_paths = paths.is_a?(ActionView::PathSet) ?
                            paths : ActionView::Base.process_view_paths(paths)
      end
    end
  end
end
