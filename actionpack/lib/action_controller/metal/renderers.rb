require 'set'

module ActionController
  # See <tt>Renderers.add</tt>
  def self.add_renderer(key, &block)
    Renderers.add(key, &block)
  end

  module Renderers
    extend ActiveSupport::Concern

    included do
      class_attribute :_renderers
      self._renderers = Set.new.freeze
    end

    module ClassMethods
      def use_renderers(*args)
        renderers = _renderers + args
        self._renderers = renderers.freeze
      end
      alias use_renderer use_renderers
    end

    def render_to_body(options)
      _handle_render_options(options) || super
    end

    def _handle_render_options(options)
      _renderers.each do |name|
        if options.key?(name)
          _process_options(options)
          return send("_render_option_#{name}", options.delete(name), options)
        end
      end
      nil
    end

    # Hash of available renderers, mapping a renderer name to its proc.
    # Default keys are :json, :js, :xml.
    RENDERERS = Set.new

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
    #     send_data str, type: Mime::CSV,
    #       disposition: "attachment; filename=#{filename}.csv"
    #   end
    #
    # Note that we used Mime::CSV for the csv mime type as it comes with Rails.
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
    #     }
    #   end
    # To use renderers and their mime types in more concise ways, see
    # <tt>ActionController::MimeResponds::ClassMethods.respond_to</tt> and
    # <tt>ActionController::MimeResponds#respond_with</tt>
    def self.add(key, &block)
      define_method("_render_option_#{key}", &block)
      RENDERERS << key.to_sym
    end

    module All
      extend ActiveSupport::Concern
      include Renderers

      included do
        self._renderers = RENDERERS
      end
    end

    add :json do |json, options|
      json = json.to_json(options) unless json.kind_of?(String)

      if options[:callback].present?
        self.content_type ||= Mime::JS
        "#{options[:callback]}(#{json})"
      else
        self.content_type ||= Mime::JSON
        json
      end
    end

    add :js do |js, options|
      self.content_type ||= Mime::JS
      js.respond_to?(:to_js) ? js.to_js(options) : js
    end

    add :xml do |xml, options|
      self.content_type ||= Mime::XML
      xml.respond_to?(:to_xml) ? xml.to_xml(options) : xml
    end
  end
end
