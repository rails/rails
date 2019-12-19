# frozen_string_literal: true

require "set"

module ActionController
  # See <tt>Renderers.add</tt>
  def self.add_renderer(key, &block)
    Renderers.add(key, &block)
  end

  # See <tt>Renderers.remove</tt>
  def self.remove_renderer(key)
    Renderers.remove(key)
  end

  # See <tt>Responder#api_behavior</tt>
  class MissingRenderer < LoadError
    def initialize(format)
      super "No renderer defined for format: #{format}"
    end
  end

  module Renderers
    extend ActiveSupport::Concern

    # A Set containing renderer names that correspond to available renderer procs.
    # Default values are <tt>:json</tt>, <tt>:js</tt>, <tt>:xml</tt>.
    RENDERERS = Set.new

    included do
      class_attribute :_renderers, default: Set.new.freeze
    end

    # Used in <tt>ActionController::Base</tt>
    # and <tt>ActionController::API</tt> to include all
    # renderers by default.
    module All
      extend ActiveSupport::Concern
      include Renderers

      included do
        self._renderers = RENDERERS
      end
    end

    # Adds a new renderer to call within controller actions.
    # A renderer is invoked by passing its name as an option to
    # <tt>AbstractController::Rendering#render</tt>. To create a renderer
    # pass it a name and a block. The block takes two arguments, the first
    # is the value paired with its key and the second is the remaining
    # hash of options passed to +render+.
    #
    # Create a csv renderer:
    #
    #   ActionController::Renderers.add :csv do |obj, options|
    #     filename = options[:filename] || 'data'
    #     str = obj.respond_to?(:to_csv) ? obj.to_csv : obj.to_s
    #     send_data str, type: Mime[:csv],
    #       disposition: "attachment; filename=#{filename}.csv"
    #   end
    #
    # Note that we used Mime[:csv] for the csv mime type as it comes with Rails.
    # For a custom renderer, you'll need to register a mime type with
    # <tt>Mime::Type.register</tt>.
    #
    # To use the csv renderer in a controller action:
    #
    #   def show
    #     @csvable = Csvable.find(params[:id])
    #     respond_to do |format|
    #       format.html
    #       format.csv { render csv: @csvable, filename: @csvable.name }
    #     end
    #   end
    def self.add(key, &block)
      define_method(_render_with_renderer_method_name(key), &block)
      RENDERERS << key.to_sym
    end

    # This method is the opposite of add method.
    #
    # To remove a csv renderer:
    #
    #   ActionController::Renderers.remove(:csv)
    def self.remove(key)
      RENDERERS.delete(key.to_sym)
      method_name = _render_with_renderer_method_name(key)
      remove_possible_method(method_name)
    end

    def self._render_with_renderer_method_name(key)
      "_render_with_renderer_#{key}"
    end

    module ClassMethods
      # Adds, by name, a renderer or renderers to the +_renderers+ available
      # to call within controller actions.
      #
      # It is useful when rendering from an <tt>ActionController::Metal</tt> controller or
      # otherwise to add an available renderer proc to a specific controller.
      #
      # Both <tt>ActionController::Base</tt> and <tt>ActionController::API</tt>
      # include <tt>ActionController::Renderers::All</tt>, making all renderers
      # available in the controller. See <tt>Renderers::RENDERERS</tt> and <tt>Renderers.add</tt>.
      #
      # Since <tt>ActionController::Metal</tt> controllers cannot render, the controller
      # must include <tt>AbstractController::Rendering</tt>, <tt>ActionController::Rendering</tt>,
      # and <tt>ActionController::Renderers</tt>, and have at least one renderer.
      #
      # Rather than including <tt>ActionController::Renderers::All</tt> and including all renderers,
      # you may specify which renderers to include by passing the renderer name or names to
      # +use_renderers+. For example, a controller that includes only the <tt>:json</tt> renderer
      # (+_render_with_renderer_json+) might look like:
      #
      #   class MetalRenderingController < ActionController::Metal
      #     include AbstractController::Rendering
      #     include ActionController::Rendering
      #     include ActionController::Renderers
      #
      #     use_renderers :json
      #
      #     def show
      #       render json: record
      #     end
      #   end
      #
      # You must specify a +use_renderer+, else the +controller.renderer+ and
      # +controller._renderers+ will be <tt>nil</tt>, and the action will fail.
      def use_renderers(*args)
        renderers = _renderers + args
        self._renderers = renderers.freeze
      end
      alias use_renderer use_renderers
    end

    # Called by +render+ in <tt>AbstractController::Rendering</tt>
    # which sets the return value as the +response_body+.
    #
    # If no renderer is found, +super+ returns control to
    # <tt>ActionView::Rendering.render_to_body</tt>, if present.
    def render_to_body(options)
      _render_to_body_with_renderer(options) || super
    end

    def _render_to_body_with_renderer(options)
      _renderers.each do |name|
        if options.key?(name)
          _process_options(options)
          method_name = Renderers._render_with_renderer_method_name(name)
          return send(method_name, options.delete(name), options)
        end
      end
      nil
    end

    add :json do |json, options|
      json = json.to_json(options) unless json.kind_of?(String)

      if options[:callback].present?
        if media_type.nil? || media_type == Mime[:json]
          self.content_type = Mime[:js]
        end

        "/**/#{options[:callback]}(#{json})"
      else
        self.content_type = Mime[:json] if media_type.nil?
        json
      end
    end

    add :js do |js, options|
      self.content_type = Mime[:js] if media_type.nil?
      js.respond_to?(:to_js) ? js.to_js(options) : js
    end

    add :xml do |xml, options|
      self.content_type = Mime[:xml] if media_type.nil?
      xml.respond_to?(:to_xml) ? xml.to_xml(options) : xml
    end
  end
end
