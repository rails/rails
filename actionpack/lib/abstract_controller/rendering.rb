require 'abstract_controller/error'
require 'active_support/concern'
require 'active_support/core_ext/class/attribute'
require 'action_view'
require 'action_view/view_paths'
require 'set'

module AbstractController
  class DoubleRenderError < Error
    DEFAULT_MESSAGE = "Render and/or redirect were called multiple times in this action. Please note that you may only call render OR redirect, and at most once per action. Also note that neither redirect nor render terminate execution of the action, so if you want to exit an action after redirecting, you need to do something like \"redirect_to(...) and return\"."

    def initialize(message = nil)
      super(message || DEFAULT_MESSAGE)
    end
  end

  module Rendering
    extend ActiveSupport::Concern
    include ActionView::ViewPaths

    # Normalizes arguments, options and then delegates render_to_body and
    # sticks the result in <tt>self.response_body</tt>.
    # :api: public
    def render(*args, &block)
      options = _normalize_render(*args, &block)
      rendered_body = render_to_body(options)
      if options[:html]
        _set_html_content_type
      else
        _set_rendered_content_type rendered_format
      end
      self.response_body = rendered_body
    end

    # Raw rendering of a template to a string.
    #
    # It is similar to render, except that it does not
    # set the +response_body+ and it should be guaranteed
    # to always return a string.
    #
    # If a component extends the semantics of +response_body+
    # (as ActionController extends it to be anything that
    # responds to the method each), this method needs to be
    # overridden in order to still return a string.
    # :api: plugin
    def render_to_string(*args, &block)
      options = _normalize_render(*args, &block)
      render_to_body(options)
    end

    # Performs the actual template rendering.
    # :api: public
    def render_to_body(options = {})
    end

    # Returns Content-Type of rendered content
    # :api: public
    def rendered_format
      Mime[:text]
    end

    DEFAULT_PROTECTED_INSTANCE_VARIABLES = Set.new %i(
      @_action_name @_response_body @_formats @_prefixes
    )

    # This method should return a hash with assigns.
    # You can overwrite this configuration per controller.
    # :api: public
    def view_assigns
      protected_vars = _protected_ivars
      variables      = instance_variables

      variables.reject! { |s| protected_vars.include? s }
      variables.each_with_object({}) { |name, hash|
        hash[name.slice(1, name.length)] = instance_variable_get(name)
      }
    end

    # Normalize args by converting <tt>render "foo"</tt> to
    # <tt>render :action => "foo"</tt> and <tt>render "foo/bar"</tt> to
    # <tt>render :file => "foo/bar"</tt>.
    # :api: plugin
    def _normalize_args(action=nil, options={})
      if action.respond_to?(:permitted?)
        if action.permitted?
          action
        else
          raise ArgumentError, "render parameters are not permitted"
        end
      elsif action.is_a?(Hash)
        action
      else
        options
      end
    end

    # Normalize options.
    # :api: plugin
    def _normalize_options(options)
      options
    end

    # Process extra options.
    # :api: plugin
    def _process_options(options)
      options
    end

    # Process the rendered format.
    # :api: private
    def _process_format(format)
    end

    def _set_html_content_type # :nodoc:
    end

    def _set_rendered_content_type(format) # :nodoc:
    end

    # Normalize args and options.
    # :api: private
    def _normalize_render(*args, &block)
      options = _normalize_args(*args, &block)
      #TODO: remove defined? when we restore AP <=> AV dependency
      if defined?(request) && !request.nil? && request.variant.present?
        options[:variant] = request.variant
      end
      _normalize_options(options)
      options
    end

    def _protected_ivars # :nodoc:
      DEFAULT_PROTECTED_INSTANCE_VARIABLES
    end
  end
end
