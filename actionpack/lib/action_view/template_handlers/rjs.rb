module ActionView
  module TemplateHandlers
    class RJS < TemplateHandler
      include Compilable

      def compile(template)
        "controller.response.content_type ||= Mime::JS;" +
          "update_page do |page|;#{template.source}\nend"
      end
    end
  end
end
