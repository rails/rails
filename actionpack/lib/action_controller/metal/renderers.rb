require 'set'

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

  # See <tt>Renderers.add_serializer</tt>
  def self.add_serializer(key, &block)
    Renderers.add_serializer(key, &block)
  end

  # See <tt>Renderers.remove_serializer</tt>
  def self.remove_serializer(key)
    Renderers.remove_serializer(key)
  end

  # See <tt>Renderers::MissingRenderer</tt>
  class MissingSerializer < LoadError
    def initialize(format)
      super "No serializer defined for format: #{format}"
    end
  end

  module Renderers
    extend ActiveSupport::Concern

    # A Set containing renderer names that correspond to available renderer procs.
    # Default values are <tt>:json</tt>, <tt>:js</tt>, <tt>:xml</tt>.
    RENDERERS = Set.new

    # A Hash mapping serializer names to callables.
    # TODO: update text
    # Default serializers are <tt>:json</tt>, <tt>:js</tt>, <tt>:xml</tt>.
    SERIALIZERS = Hash.new.with_indifferent_access

    included do
      class_attribute :_renderers
      self._renderers = Set.new.freeze
      class_attribute :_serializers
      self._serializers = SERIALIZERS.dup
    end

    # Used in <tt>ActionController::Base</tt>
    # and <tt>ActionController::API</tt> to include all
    # renderers by default.
    module All
      extend ActiveSupport::Concern
      include Renderers

      included do
        self._renderers = RENDERERS
        self._serializers = SERIALIZERS
      end
    end

    # Adds a new renderer to call within controller actions.
    # A renderer is invoked by passing its name as an option to
    # <tt>AbstractController::Rendering#render</tt>. To create a renderer
    # pass it a name and a block. The block takes two arguments, the first
    # is the value paired with its key and the second is the remaining
    # hash of options passed to +render+.
    # A renderer must have an associated serializer.
    # See <tt>Renderers.add_serializer</tt>
    #
    # Create a csv renderer:
    #
    #   ActionController::Renderers.add_serializer :csv do |obj, options|
    #     obj.respond_to?(:to_csv) ? obj.to_csv : obj.to_s
    #   end
    #
    #   ActionController::Renderers.add :csv do |obj, options|
    #     filename = options[:filename] || 'data'
    #     str = _serialize_with_serializer_csv(obj, options)
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
    # To use renderers and their mime types in more concise ways, see
    # <tt>ActionController::MimeResponds::ClassMethods.respond_to</tt>
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
      remove_method(method_name) if method_defined?(method_name)
    end

    # TODO: update text
    # Serializers define a method called within a renderer specific to
    # transforming the object into a mime-compatible type.
    # See <tt>Renderers.add</tt>
    #
    # The separation of serialization from rendering allows
    # composing the Renderer behavior of two methods, e.g.
    # +_render_with_renderer_json+ and +_serialize_with_serializer_json+,
    # rather than requiring one to define a method +_render_with_renderer_json+
    # in a subclass and optionally call super on it.
    #
    # A principal benefit of this approach is that it promotes serialization of an object
    # to a clearly-defined public interface, rather than requiring one to understand that
    # calling, e.g. +render json: object+ calls +_render_to_body_with_renderer(options)+
    # which calls +_render_with_renderer_#{key}+ where key is +json+, which is the method
    # defined by calling +ActionController::Renderers.add :json+.
    #
    # Example usage:
    #
    # Prior to the introduction of SERIALIZERS, customizing JSON serialization would
    # have relied upon defining +_render_with_renderer_json+ (or +_render_option_json+,  pre-4.2 )
    # in the controller, and calling +super+ on
    # the serialized object. Now, one need only call +ActionController.remove_serializer :json+ and
    # define a new serializer with +ActionController.add_serializer json do |json, options| end+.
    # There's no longer a need to add controller methods to define custom serializers.
    #
    # Pretty-printing JSON can be implemented by replacing the JSON serializer:
    #
    #   ActionController::Renderers.remove_serializer :json
    #   ActionController::Renderers.add_serializer :json do |json, options|
    #     return json if json.is_a?(String)
    #
    #     json = json.as_json(options) if json.respond_to?(:as_json)
    #     json = JSON.pretty_generate(json, options)
    #   end
    #
    # See https://groups.google.com/forum/#!topic/rubyonrails-core/K8t4-DZ_DkQ/discussion for
    # more background information.
    def self.add_serializer(key, &block)
      SERIALIZERS[key.to_sym] = block
    end

    # This method is the opposite of add_serializer method.
    #
    # To remove a csv serializer:
    #
    #   ActionController.remove_serializer(:csv)
    def self.remove_serializer(key)
      SERIALIZERS.delete(key.to_sym)
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
      # avaialable in the controller. See <tt>Renderers::RENDERERS</tt> and <tt>Renderers.add</tt>.
      #
      # Since <tt>ActionController::Metal</tt> controllers cannot render, the controller
      # must include <tt>AbstractController::Rendering</tt>, <tt>ActionController::Rendering</tt>,
      # and <tt>ActionController::Renderers</tt>, and have at lest one renderer.
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

      # See <tt>Renderers.use_renderers</tt>
      def use_serializers(*args)
        serializers = _serializers + args
        self._serializers = serializers.freeze
      end
      alias use_serializer use_serializers
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
      _renderers.each do |renderer_name|
        next unless options.key?(renderer_name)
        _process_options(options)

        serializer_name = options.key?(:serializer_name) ? options.delete(:serializer_name) : renderer_name
        serializer = _serializers.fetch(serializer_name) do
          fail ActionController::MissingSerializer, "There is no '#{serializer_name}' serializer.\n" <<
                "Known serializers are #{_serializers.keys}"
        end

        renderer_target_method_name = Renderers._render_with_renderer_method_name(renderer_name)
        renderer_target_value = options.delete(renderer_name)
        serialized_value = serializer.call(renderer_target_value, options)
        return send(renderer_target_method_name, serialized_value, options)
      end
      nil
    end

    add_serializer :json do |json, options|
      json.kind_of?(String) ? json : json.to_json(options)
    end

    add :json do |json, options|
      if options[:callback].present?
        if content_type.nil? || content_type == Mime[:json]
          self.content_type = Mime[:js]
        end

        "/**/#{options[:callback]}(#{json})"
      else
        self.content_type ||= Mime[:json]
        json
      end
    end

    add_serializer :js do |js, options|
      js.respond_to?(:to_js) ? js.to_js(options) : js
    end

    add :js do |js, options|
      self.content_type ||= Mime[:js]
      js
    end

    add_serializer :xml do |xml, options|
      xml.respond_to?(:to_xml) ? xml.to_xml(options) : xml
    end

    add :xml do |xml, options|
      self.content_type ||= Mime[:xml]
      xml
    end
  end
end
