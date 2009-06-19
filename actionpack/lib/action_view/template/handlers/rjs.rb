module ActionView
  module TemplateHandlers
    class RJS < TemplateHandler
      include Compilable

      self.default_format = Mime::JS

      def compile(template)
        "controller.response.content_type ||= Mime::JS;" +
          "update_page do |page|;#{template.source}\nend"
      end

      def default_format
        Mime::JS
      end
    end
  end
end
