module ActionView
  module TemplateHandlers
    class RJS < TemplateHandler
      include Compilable

      def compile(template)
        "@template_format = :html;" +
        "controller.response.content_type ||= Mime::JS;" +
          "update_page do |page|;#{template.source}\nend"
      end
    end
  end
end
