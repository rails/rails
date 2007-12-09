module ActionView
  module TemplateHandlers
    class RJS < TemplateHandler
      def compile(template)
        "controller.response.content_type ||= Mime::JS\n" +
        "update_page do |page|\n#{template}\nend"
      end
    end
  end
end
