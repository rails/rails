require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/object/blank'

module ActionController
  def self.add_renderer(key, &block)
    Renderers.add(key, &block)
  end

  module Renderers
    extend ActiveSupport::Concern

    included do
      class_attribute :_renderers
      self._renderers = {}.freeze
    end

    module ClassMethods
      def use_renderers(*args)
        new = _renderers.dup
        args.each do |key|
          new[key] = RENDERERS[key]
        end
        self._renderers = new.freeze
      end
      alias use_renderer use_renderers
    end

    def render_to_body(options)
      _handle_render_options(options) || super
    end

    def _handle_render_options(options)
      _renderers.each do |name, value|
        if options.key?(name.to_sym)
          _process_options(options)
          return send("_render_option_#{name}", options.delete(name.to_sym), options)
        end
      end
      nil
    end

    RENDERERS = {}
    def self.add(key, &block)
      define_method("_render_option_#{key}", &block)
      RENDERERS[key] = block
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
      json = "#{options[:callback]}(#{json})" unless options[:callback].blank?
      self.content_type ||= Mime::JSON
      self.response_body  = json
    end

    add :js do |js, options|
      self.content_type ||= Mime::JS
      self.response_body  = js.respond_to?(:to_js) ? js.to_js(options) : js
    end

    add :xml do |xml, options|
      self.content_type ||= Mime::XML
      self.response_body  = xml.respond_to?(:to_xml) ? xml.to_xml(options) : xml
    end

    add :update do |proc, options|
      view_context = self.view_context
      generator = ActionView::Helpers::PrototypeHelper::JavaScriptGenerator.new(view_context, &proc)
      self.content_type  = Mime::JS
      self.response_body = generator.to_s
    end
  end
end
