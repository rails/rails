module ActionController
  module RenderOptions
    extend ActiveSupport::Concern

    included do
      extlib_inheritable_accessor :_renderers
      self._renderers = []
    end

    module ClassMethods
      def _write_render_options
        renderers = _renderers.map do |r|
          <<-RUBY_EVAL
            if options.key?(:#{r})
              _process_options(options)
              return render_#{r}(options[:#{r}], options)
            end
          RUBY_EVAL
        end

        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          def _handle_render_options(options)
            #{renderers.join}
          end
        RUBY_EVAL
      end

      def _add_render_option(name)
        _renderers << name
        _write_render_options
      end
    end

    def render_to_body(options)
      _handle_render_options(options) || super
    end
  end

  module RenderOption #:nodoc:
    def self.extended(base)
      base.extend ActiveSupport::Concern
      base.send :include, ::ActionController::RenderOptions

      def base.register_renderer(name)
        included { _add_render_option(name) }
      end
    end
  end

  module RenderOptions
    module Json
      extend RenderOption
      register_renderer :json

      def render_json(json, options)
        json = ActiveSupport::JSON.encode(json) unless json.respond_to?(:to_str)
        json = "#{options[:callback]}(#{json})" unless options[:callback].blank?
        self.content_type ||= Mime::JSON
        self.response_body = json
      end
    end

    module Js
      extend RenderOption
      register_renderer :js

      def render_js(js, options)
        self.content_type ||= Mime::JS
        self.response_body  = js.respond_to?(:to_js) ? js.to_js : js
      end
    end

    module Xml
      extend RenderOption
      register_renderer :xml

      def render_xml(xml, options)
        self.content_type ||= Mime::XML
        self.response_body  = xml.respond_to?(:to_xml) ? xml.to_xml : xml
      end
    end

    module RJS
      extend RenderOption
      register_renderer :update

      def render_update(proc, options)
        generator = ActionView::Helpers::PrototypeHelper::JavaScriptGenerator.new(view_context, &proc)
        self.content_type = Mime::JS
        self.response_body = generator.to_s
      end
    end

    module All
      extend ActiveSupport::Concern

      include ActionController::RenderOptions::Json
      include ActionController::RenderOptions::Js
      include ActionController::RenderOptions::Xml
      include ActionController::RenderOptions::RJS
    end
  end
end
